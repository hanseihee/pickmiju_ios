import Foundation

// MARK: - Yahoo Finance Authentication

actor YahooAuthManager {
    static let shared = YahooAuthManager()

    private var crumb: String?
    private var cookies: String?
    private var lastAuthTime: Date?
    private let authTTL: TimeInterval = 3600 // 1 hour

    private init() {}

    func getAuth() async throws -> (crumb: String, cookies: String) {
        // Return cached auth if still valid
        if let crumb, let cookies, let lastAuthTime,
           Date().timeIntervalSince(lastAuthTime) < authTTL {
            return (crumb, cookies)
        }

        return try await refreshAuth()
    }

    func invalidate() {
        crumb = nil
        cookies = nil
        lastAuthTime = nil
    }

    private let session = URLSession(configuration: .ephemeral)

    private func refreshAuth() async throws -> (crumb: String, cookies: String) {
        // Step 1: Get consent cookies
        let consentURL = URL(string: "https://fc.yahoo.com")!
        var consentRequest = URLRequest(url: consentURL)
        consentRequest.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let (_, consentResponse) = try await session.data(for: consentRequest)

        guard let httpResponse = consentResponse as? HTTPURLResponse else {
            throw StockAPIError.authFailed
        }

        // Extract cookies from response headers
        let responseCookies = HTTPCookie.cookies(
            withResponseHeaderFields: httpResponse.allHeaderFields as? [String: String] ?? [:],
            for: consentURL
        )

        var cookieString = responseCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")

        // Step 2: Get crumb
        let crumbURL = URL(string: "https://query2.finance.yahoo.com/v1/test/getcrumb")!
        var crumbRequest = URLRequest(url: crumbURL)
        crumbRequest.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        crumbRequest.setValue(cookieString, forHTTPHeaderField: "Cookie")

        let (crumbData, crumbResponse) = try await session.data(for: crumbRequest)

        // Also collect cookies from crumb response
        if let crumbHttp = crumbResponse as? HTTPURLResponse {
            let crumbCookies = HTTPCookie.cookies(
                withResponseHeaderFields: crumbHttp.allHeaderFields as? [String: String] ?? [:],
                for: crumbURL
            )
            if !crumbCookies.isEmpty {
                let additional = crumbCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                cookieString = cookieString.isEmpty ? additional : "\(cookieString); \(additional)"
            }
        }

        guard let crumbValue = String(data: crumbData, encoding: .utf8),
              !crumbValue.isEmpty else {
            throw StockAPIError.authFailed
        }

        self.crumb = crumbValue
        self.cookies = cookieString
        self.lastAuthTime = Date()

        return (crumbValue, cookieString)
    }
}

// MARK: - Stock API Service

actor StockAPIService {
    static let shared = StockAPIService()

    private init() {}

    // MARK: - Fetch Quotes

    func fetchQuotes(symbols: [String]) async throws -> [StockPrice] {
        guard !symbols.isEmpty else { return [] }

        let auth = try await YahooAuthManager.shared.getAuth()
        let symbolsStr = symbols.joined(separator: ",")

        let fields = [
            "symbol", "shortName", "longName", "quoteType", "currency",
            "exchange", "marketState",
            "regularMarketPrice", "regularMarketChange", "regularMarketChangePercent",
            "regularMarketTime", "regularMarketOpen", "regularMarketDayHigh",
            "regularMarketDayLow", "regularMarketVolume", "regularMarketPreviousClose",
            "preMarketPrice", "preMarketChange", "preMarketChangePercent", "preMarketTime",
            "postMarketPrice", "postMarketChange", "postMarketChangePercent", "postMarketTime",
            "extendedMarketPrice", "extendedMarketChange", "extendedMarketChangePercent",
            "overnightMarketPrice", "overnightMarketChange", "overnightMarketChangePercent",
            "bid", "bidSize", "ask", "askSize", "priceHint",
            "fiftyTwoWeekHigh", "fiftyTwoWeekLow",
            "marketCap", "dividendYield",
            "earningsTimestamp", "earningsTimestampStart",
            "hasPrePostMarketData",
        ].joined(separator: ",")

        var urlComponents = URLComponents(string: "https://query1.finance.yahoo.com/v7/finance/quote")!
        urlComponents.queryItems = [
            URLQueryItem(name: "symbols", value: symbolsStr),
            URLQueryItem(name: "fields", value: fields),
            URLQueryItem(name: "crumb", value: auth.crumb),
            URLQueryItem(name: "formatted", value: "false"),
            URLQueryItem(name: "region", value: "US"),
            URLQueryItem(name: "lang", value: "en-US"),
        ]

        var request = URLRequest(url: urlComponents.url!)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(auth.cookies, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            await YahooAuthManager.shared.invalidate()
            throw StockAPIError.unauthorized
        }

        let decoded = try JSONDecoder().decode(YahooQuoteResponse.self, from: data)

        guard let results = decoded.quoteResponse?.result else {
            throw StockAPIError.noData
        }

        return results.map { mapToStockPrice($0) }
    }

    // MARK: - Search Stocks

    func searchStocks(query: String) async throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        var urlComponents = URLComponents(string: "https://query1.finance.yahoo.com/v1/finance/search")!
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "lang", value: "en-US"),
            URLQueryItem(name: "region", value: "US"),
            URLQueryItem(name: "quotesCount", value: "10"),
            URLQueryItem(name: "newsCount", value: "0"),
            URLQueryItem(name: "listsCount", value: "0"),
            URLQueryItem(name: "enableFuzzyQuery", value: "false"),
            URLQueryItem(name: "enableEnhancedTrivialQuery", value: "true"),
        ]

        var request = URLRequest(url: urlComponents.url!)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(YahooSearchResponse.self, from: data)

        let validTypes: Set<String> = ["EQUITY", "ETF", "INDEX", "CRYPTOCURRENCY"]

        return (decoded.quotes ?? [])
            .filter { validTypes.contains($0.quoteType ?? "") }
            .map { SearchResult(
                symbol: $0.symbol,
                name: $0.shortname ?? $0.longname ?? $0.symbol,
                exchange: $0.exchange,
                type: $0.quoteType
            )}
    }

    // MARK: - Mapping

    private func mapMarketState(_ state: String?) -> Int {
        switch state?.uppercased() {
        case "PRE": return 0
        case "REGULAR": return 1
        case "POST", "POSTPOST": return 2
        default: return 3
        }
    }

    private func mapQuoteType(_ type: String?) -> Int {
        switch type?.uppercased() {
        case "EQUITY": return 0
        case "ETF": return 1
        case "INDEX": return 2
        case "CRYPTOCURRENCY": return 3
        case "CURRENCY": return 4
        case "FUTURE": return 5
        default: return 0
        }
    }

    private func mapToStockPrice(_ quote: YahooQuote) -> StockPrice {
        let marketHours = mapMarketState(quote.marketState)
        let regularPrice = quote.regularMarketPrice ?? 0
        let regularChange = quote.regularMarketChange ?? 0
        let regularChangePercent = quote.regularMarketChangePercent ?? 0

        // Extended hours price calculation (same logic as web)
        var extPrice: Double = 0
        var extChange: Double = 0
        var extChangePercent: Double = 0

        if let overnight = quote.overnightMarketPrice, overnight != 0 {
            extPrice = overnight
            extChange = quote.overnightMarketChange ?? 0
            extChangePercent = quote.overnightMarketChangePercent ?? 0
        } else if let extended = quote.extendedMarketPrice, extended != 0 {
            extPrice = extended
            extChange = quote.extendedMarketChange ?? 0
            extChangePercent = quote.extendedMarketChangePercent ?? 0
        } else {
            let preTime = quote.preMarketTime ?? 0
            let postTime = quote.postMarketTime ?? 0
            if let prePrice = quote.preMarketPrice, prePrice != 0, preTime >= postTime {
                extPrice = prePrice
                extChange = quote.preMarketChange ?? 0
                extChangePercent = quote.preMarketChangePercent ?? 0
            } else if let postPrice = quote.postMarketPrice, postPrice != 0 {
                extPrice = postPrice
                extChange = quote.postMarketChange ?? 0
                extChangePercent = quote.postMarketChangePercent ?? 0
            }
        }

        let isRegular = marketHours == 1
        let price = isRegular ? regularPrice : (extPrice != 0 ? extPrice : regularPrice)
        let change = isRegular ? regularChange : (extPrice != 0 ? extChange : regularChange)
        let changePercent = isRegular ? regularChangePercent : (extPrice != 0 ? extChangePercent : regularChangePercent)

        return StockPrice(
            id: quote.symbol,
            price: price,
            time: (quote.regularMarketTime ?? 0) * 1000,
            currency: quote.currency ?? "USD",
            exchange: quote.exchange ?? "",
            quoteType: mapQuoteType(quote.quoteType),
            marketHours: marketHours,
            changePercent: changePercent,
            dayVolume: quote.regularMarketVolume ?? 0,
            dayHigh: quote.regularMarketDayHigh ?? 0,
            dayLow: quote.regularMarketDayLow ?? 0,
            change: change,
            shortName: quote.shortName ?? quote.symbol,
            previousClose: quote.regularMarketPreviousClose ?? 0,
            priceHint: quote.priceHint ?? 2,
            openPrice: quote.regularMarketOpen ?? 0,
            bid: quote.bid ?? 0,
            bidSize: quote.bidSize ?? 0,
            ask: quote.ask ?? 0,
            askSize: quote.askSize ?? 0,
            lastSize: 0,
            vol24hr: 0,
            marketCap: quote.marketCap ?? 0,
            circulatingSupply: 0,
            regularMarketPrice: regularPrice,
            regularMarketChange: regularChange,
            regularMarketChangePercent: regularChangePercent,
            extendedHoursPrice: extPrice,
            extendedHoursChange: extChange,
            extendedHoursChangePercent: extChangePercent,
            fiftyTwoWeekHigh: quote.fiftyTwoWeekHigh ?? 0,
            fiftyTwoWeekLow: quote.fiftyTwoWeekLow ?? 0,
            dividendYield: quote.dividendYield ?? 0,
            earningsTimestamp: quote.earningsTimestamp ?? quote.earningsTimestampStart
        )
    }
}

// MARK: - Yahoo Finance API Response Types (nonisolated for actor compatibility)

private nonisolated struct YahooQuoteResponse: Codable {
    let quoteResponse: QuoteResponseBody?
}

private nonisolated struct QuoteResponseBody: Codable {
    let result: [YahooQuote]?
    let error: QuoteError?
}

private nonisolated struct QuoteError: Codable {
    let code: String?
    let description: String?
}

private nonisolated struct YahooQuote: Codable, Sendable {
    let symbol: String
    let shortName: String?
    let longName: String?
    let quoteType: String?
    let currency: String?
    let exchange: String?
    let marketState: String?
    let regularMarketPrice: Double?
    let regularMarketChange: Double?
    let regularMarketChangePercent: Double?
    let regularMarketTime: Int?
    let regularMarketOpen: Double?
    let regularMarketDayHigh: Double?
    let regularMarketDayLow: Double?
    let regularMarketVolume: Int?
    let regularMarketPreviousClose: Double?
    let preMarketPrice: Double?
    let preMarketChange: Double?
    let preMarketChangePercent: Double?
    let preMarketTime: Int?
    let postMarketPrice: Double?
    let postMarketChange: Double?
    let postMarketChangePercent: Double?
    let postMarketTime: Int?
    let extendedMarketPrice: Double?
    let extendedMarketChange: Double?
    let extendedMarketChangePercent: Double?
    let overnightMarketPrice: Double?
    let overnightMarketChange: Double?
    let overnightMarketChangePercent: Double?
    let bid: Double?
    let bidSize: Int?
    let ask: Double?
    let askSize: Int?
    let priceHint: Int?
    let fiftyTwoWeekHigh: Double?
    let fiftyTwoWeekLow: Double?
    let marketCap: Double?
    let dividendYield: Double?
    let earningsTimestamp: Int?
    let earningsTimestampStart: Int?
}

private nonisolated struct YahooSearchResponse: Codable {
    let quotes: [YahooSearchQuote]?
}

private nonisolated struct YahooSearchQuote: Codable {
    let symbol: String
    let shortname: String?
    let longname: String?
    let exchange: String?
    let quoteType: String?
}

// MARK: - Errors

enum StockAPIError: LocalizedError {
    case authFailed
    case unauthorized
    case noData
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .authFailed: return "Yahoo Finance 인증 실패"
        case .unauthorized: return "인증이 만료되었습니다"
        case .noData: return "데이터를 받지 못했습니다"
        case .networkError(let error): return error.localizedDescription
        }
    }
}
