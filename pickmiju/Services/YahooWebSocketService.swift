import Foundation

// MARK: - WebSocket Connection Status

enum WebSocketStatus: String {
    case connecting
    case connected
    case disconnected
    case error
}

// MARK: - Yahoo Finance WebSocket Service

@Observable
final class YahooWebSocketService {
    private(set) var status: WebSocketStatus = .disconnected
    private(set) var prices: [String: StockPrice] = [:]

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var subscribers: Set<String> = []
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var reconnectTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?

    private let wsURL = URL(string: "wss://streamer.finance.yahoo.com/?version=2")!

    deinit {
        disconnect()
    }

    // MARK: - Public API

    func connect() {
        guard webSocketTask == nil || status == .disconnected || status == .error else { return }

        status = .connecting

        // Reuse or create URLSession
        if urlSession == nil {
            urlSession = URLSession(configuration: .default)
        }

        var request = URLRequest(url: wsURL)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)",
            forHTTPHeaderField: "User-Agent"
        )
        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()

        reconnectAttempts = 0

        // Resubscribe existing tickers
        if !subscribers.isEmpty {
            sendSubscribe(Array(subscribers))
        }

        // Start receiving — first successful receive confirms connection
        startReceiving()
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        status = .disconnected
    }

    func subscribe(_ tickers: [String]) {
        let newTickers = tickers.filter { !subscribers.contains($0) }
        newTickers.forEach { subscribers.insert($0) }

        if let task = webSocketTask, task.state == .running, !newTickers.isEmpty {
            sendSubscribe(newTickers)
        } else if webSocketTask == nil || status == .disconnected {
            connect()
        }
    }

    func unsubscribe(_ tickers: [String]) {
        tickers.forEach { subscribers.remove($0) }

        if let task = webSocketTask, task.state == .running {
            sendUnsubscribe(tickers)
        }
    }

    /// Set initial prices from REST API (merges with existing WebSocket data)
    func setInitialPrices(_ initialPrices: [String: StockPrice]) {
        var hasNewData = false

        for (ticker, apiData) in initialPrices {
            if let existing = prices[ticker] {
                // Merge: API data is authoritative for day-specific fields
                // (they reset daily, so stale cache from yesterday must be overwritten).
                // WebSocket-only fields (metadata) are filled from cache when API is empty.
                var merged = existing
                // Day-specific fields — always use API data (resets each trading day)
                merged.price = apiData.price != 0 ? apiData.price : existing.price
                merged.previousClose = apiData.previousClose != 0 ? apiData.previousClose : existing.previousClose
                merged.dayHigh = apiData.dayHigh != 0 ? apiData.dayHigh : existing.dayHigh
                merged.dayLow = apiData.dayLow != 0 ? apiData.dayLow : existing.dayLow
                merged.dayVolume = apiData.dayVolume != 0 ? apiData.dayVolume : existing.dayVolume
                merged.openPrice = apiData.openPrice != 0 ? apiData.openPrice : existing.openPrice
                merged.change = apiData.change != 0 ? apiData.change : existing.change
                merged.changePercent = apiData.changePercent != 0 ? apiData.changePercent : existing.changePercent
                merged.marketHours = apiData.marketHours
                merged.time = apiData.time != 0 ? apiData.time : existing.time
                // Metadata — fill from API only if cache is empty
                if merged.shortName.isEmpty || merged.shortName == ticker { merged.shortName = apiData.shortName }
                if merged.currency.isEmpty { merged.currency = apiData.currency }
                if merged.exchange.isEmpty { merged.exchange = apiData.exchange }
                if merged.priceHint == 0 { merged.priceHint = apiData.priceHint != 0 ? apiData.priceHint : 2 }
                // Regular market data — always use API (more complete than WebSocket)
                merged.regularMarketPrice = apiData.regularMarketPrice != 0 ? apiData.regularMarketPrice : existing.regularMarketPrice
                merged.regularMarketChange = apiData.regularMarketChange != 0 ? apiData.regularMarketChange : existing.regularMarketChange
                merged.regularMarketChangePercent = apiData.regularMarketChangePercent != 0 ? apiData.regularMarketChangePercent : existing.regularMarketChangePercent
                // Extended hours - only include if NOT in regular market hours
                if apiData.marketHours != 1 {
                    merged.extendedHoursPrice = apiData.extendedHoursPrice != 0 ? apiData.extendedHoursPrice : existing.extendedHoursPrice
                    merged.extendedHoursChange = apiData.extendedHoursChange != 0 ? apiData.extendedHoursChange : existing.extendedHoursChange
                    merged.extendedHoursChangePercent = apiData.extendedHoursChangePercent != 0 ? apiData.extendedHoursChangePercent : existing.extendedHoursChangePercent
                } else {
                    merged.extendedHoursPrice = 0
                    merged.extendedHoursChange = 0
                    merged.extendedHoursChangePercent = 0
                }
                // REST API only fields - always use API data
                merged.fiftyTwoWeekHigh = apiData.fiftyTwoWeekHigh != 0 ? apiData.fiftyTwoWeekHigh : existing.fiftyTwoWeekHigh
                merged.fiftyTwoWeekLow = apiData.fiftyTwoWeekLow != 0 ? apiData.fiftyTwoWeekLow : existing.fiftyTwoWeekLow
                merged.dividendYield = apiData.dividendYield != 0 ? apiData.dividendYield : existing.dividendYield
                merged.earningsTimestamp = apiData.earningsTimestamp ?? existing.earningsTimestamp
                prices[ticker] = merged
                hasNewData = true
            } else {
                // Clear extended hours data if in regular market
                var data = apiData
                if data.marketHours == 1 {
                    data.extendedHoursPrice = 0
                    data.extendedHoursChange = 0
                    data.extendedHoursChangePercent = 0
                }
                prices[ticker] = data
                hasNewData = true
            }
        }

        if hasNewData {
            notifyUpdate()
        }
    }

    // MARK: - Private Methods

    private var priceUpdateHandler: (([String: StockPrice]) -> Void)?

    func onPriceUpdate(_ handler: @escaping ([String: StockPrice]) -> Void) {
        priceUpdateHandler = handler
    }

    private func notifyUpdate() {
        priceUpdateHandler?(prices)
    }

    private func sendSubscribe(_ tickers: [String]) {
        let message: [String: Any] = ["subscribe": tickers]
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let string = String(data: data, encoding: .utf8) else { return }

        webSocketTask?.send(.string(string)) { error in
            if let error {
                print("[WebSocket] Subscribe send error: \(error)")
            }
        }
    }

    private func sendUnsubscribe(_ tickers: [String]) {
        let message: [String: Any] = ["unsubscribe": tickers]
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let string = String(data: data, encoding: .utf8) else { return }

        webSocketTask?.send(.string(string)) { _ in }
    }

    private func startReceiving() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            var isFirstMessage = true
            while !Task.isCancelled {
                guard let self, let task = self.webSocketTask else { break }

                do {
                    let message = try await task.receive()

                    // First successful receive confirms the connection
                    if isFirstMessage {
                        isFirstMessage = false
                        self.status = .connected
                    }

                    switch message {
                    case .string(let text):
                        self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    self.status = .disconnected
                    self.attemptReconnect()
                    break
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String,
              type == "pricing",
              let messageBase64 = json["message"] as? String,
              let protoData = Data(base64Encoded: messageBase64) else {
            return
        }

        guard let pricingData = PricingData.decode(from: protoData),
              let tickerId = pricingData.id else {
            return
        }

        // Get or create existing price data
        let existing = prices[tickerId] ?? StockPrice.empty(id: tickerId)

        // Merge WebSocket data with existing
        let currentPrice = Double(pricingData.price ?? Float(existing.price))
        let currentChange = Double(pricingData.change ?? Float(existing.change))
        let currentChangePercent = Double(pricingData.changePercent ?? Float(existing.changePercent))
        let currentMarketHours = pricingData.marketHours.map { Int($0) } ?? existing.marketHours

        // Determine regular vs extended hours data
        var regularPrice = existing.regularMarketPrice
        var regularChange = existing.regularMarketChange
        var regularChangePercent = existing.regularMarketChangePercent
        var extPrice = existing.extendedHoursPrice
        var extChange = existing.extendedHoursChange
        var extChangePercent = existing.extendedHoursChangePercent

        if currentMarketHours == 1 {
            regularPrice = currentPrice
            regularChange = currentChange
            regularChangePercent = currentChangePercent
            extPrice = 0
            extChange = 0
            extChangePercent = 0
        } else {
            extPrice = currentPrice
            if currentChange != 0 { extChange = currentChange }
            if currentChangePercent != 0 { extChangePercent = currentChangePercent }
            let prevClose = pricingData.previousClose.map { Double($0) } ?? existing.previousClose
            if regularPrice == 0 && prevClose != 0 {
                regularPrice = prevClose
            }
        }

        let updated = StockPrice(
            id: tickerId,
            price: currentPrice,
            time: pricingData.time.map { Int($0) } ?? existing.time,
            currency: pricingData.currency ?? existing.currency,
            exchange: pricingData.exchange ?? existing.exchange,
            quoteType: pricingData.quoteType.map { Int($0) } ?? existing.quoteType,
            marketHours: currentMarketHours,
            changePercent: currentChangePercent,
            dayVolume: pricingData.dayVolume.map { Int($0) } ?? existing.dayVolume,
            dayHigh: max(Double(pricingData.dayHigh ?? Float(existing.dayHigh)), currentPrice),
            dayLow: existing.dayLow > 0
                ? min(Double(pricingData.dayLow ?? Float(existing.dayLow)), currentPrice)
                : (Double(pricingData.dayLow ?? 0) != 0 ? Double(pricingData.dayLow!) : currentPrice),
            change: currentChange,
            shortName: pricingData.shortName ?? existing.shortName,
            previousClose: pricingData.previousClose.map { Double($0) } ?? existing.previousClose,
            priceHint: pricingData.priceHint.map { Int($0) } ?? existing.priceHint,
            openPrice: pricingData.openPrice.map { Double($0) } ?? existing.openPrice,
            bid: pricingData.bid.map { Double($0) } ?? existing.bid,
            bidSize: pricingData.bidSize.map { Int($0) } ?? existing.bidSize,
            ask: pricingData.ask.map { Double($0) } ?? existing.ask,
            askSize: pricingData.askSize.map { Int($0) } ?? existing.askSize,
            lastSize: pricingData.lastSize.map { Int($0) } ?? existing.lastSize,
            vol24hr: pricingData.vol24hr.map { Int($0) } ?? existing.vol24hr,
            marketCap: pricingData.marketCap ?? existing.marketCap,
            circulatingSupply: pricingData.circulatingSupply ?? existing.circulatingSupply,
            regularMarketPrice: regularPrice,
            regularMarketChange: regularChange,
            regularMarketChangePercent: regularChangePercent,
            extendedHoursPrice: extPrice,
            extendedHoursChange: extChange,
            extendedHoursChangePercent: extChangePercent,
            fiftyTwoWeekHigh: existing.fiftyTwoWeekHigh,
            fiftyTwoWeekLow: existing.fiftyTwoWeekLow,
            dividendYield: existing.dividendYield,
            earningsTimestamp: existing.earningsTimestamp
        )

        prices[tickerId] = updated
        notifyUpdate()
    }

    private func attemptReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("[WebSocket] Max reconnect attempts reached")
            return
        }

        reconnectTask?.cancel()

        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)
        reconnectAttempts += 1

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            if !self.subscribers.isEmpty {
                self.webSocketTask = nil
                self.connect()
            }
        }
    }
}
