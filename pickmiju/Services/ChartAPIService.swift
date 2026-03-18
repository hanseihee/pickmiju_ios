import Foundation

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let time: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
}

enum ChartRange: String, CaseIterable {
    case oneDay = "1d"
    case fiveDay = "5d"
    case oneMonth = "1mo"
    case threeMonth = "3mo"
    case sixMonth = "6mo"
    case oneYear = "1y"
    case fiveYear = "5y"
    case max = "max"

    var label: String {
        switch self {
        case .oneDay: return "1일"
        case .fiveDay: return "5일"
        case .oneMonth: return "1개월"
        case .threeMonth: return "3개월"
        case .sixMonth: return "6개월"
        case .oneYear: return "1년"
        case .fiveYear: return "5년"
        case .max: return "전체"
        }
    }

    var interval: String {
        switch self {
        case .oneDay: return "5m"
        case .fiveDay: return "15m"
        case .oneMonth: return "1h"
        case .threeMonth, .sixMonth, .oneYear: return "1d"
        case .fiveYear: return "1wk"
        case .max: return "1mo"
        }
    }
}

extension StockAPIService {
    func fetchChart(symbol: String, range: ChartRange) async throws -> [ChartDataPoint] {
        let auth = try await YahooAuthManager.shared.getAuth()

        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol)"
        var urlComponents = URLComponents(string: urlString)!
        urlComponents.queryItems = [
            URLQueryItem(name: "range", value: range.rawValue),
            URLQueryItem(name: "interval", value: range.interval),
            URLQueryItem(name: "crumb", value: auth.crumb),
            URLQueryItem(name: "includePrePost", value: "true"),
        ]

        var request = URLRequest(url: urlComponents.url!)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(auth.cookies, forHTTPHeaderField: "Cookie")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            await YahooAuthManager.shared.invalidate()
            throw StockAPIError.unauthorized
        }

        let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)

        guard let result = decoded.chart?.result?.first,
              let timestamps = result.timestamp,
              let quote = result.indicators?.quote?.first else {
            return []
        }

        var points: [ChartDataPoint] = []
        for i in 0..<timestamps.count {
            guard let open = quote.open?[safe: i] ?? nil,
                  let high = quote.high?[safe: i] ?? nil,
                  let low = quote.low?[safe: i] ?? nil,
                  let close = quote.close?[safe: i] ?? nil else {
                continue
            }

            points.append(ChartDataPoint(
                time: Date(timeIntervalSince1970: TimeInterval(timestamps[i])),
                open: open,
                high: high,
                low: low,
                close: close,
                volume: quote.volume?[safe: i].flatMap { $0 } ?? 0
            ))
        }

        return points
    }
}

// MARK: - Safe Array Access

extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Yahoo Chart Response Types

private nonisolated struct YahooChartResponse: Codable {
    let chart: ChartBody?
}

private nonisolated struct ChartBody: Codable {
    let result: [ChartResult]?
}

private nonisolated struct ChartResult: Codable {
    let timestamp: [Int]?
    let indicators: ChartIndicators?
}

private nonisolated struct ChartIndicators: Codable {
    let quote: [ChartQuote]?
}

private nonisolated struct ChartQuote: Codable {
    let open: [Double?]?
    let high: [Double?]?
    let low: [Double?]?
    let close: [Double?]?
    let volume: [Int?]?
}
