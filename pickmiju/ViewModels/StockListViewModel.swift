import Foundation
import SwiftUI

@Observable
final class StockListViewModel {
    var quotes: [String: StockPrice] = [:]
    var isLoading = false
    var errorMessage: String?
    var isEditMode = false

    let watchlist: WatchlistStore
    let webSocket = YahooWebSocketService()
    private let api = StockAPIService.shared
    private var isSubscribed = false
    private var addTickerTask: Task<Void, Never>?

    init(watchlist: WatchlistStore) {
        self.watchlist = watchlist

        webSocket.onPriceUpdate { [weak self] prices in
            guard let self else { return }
            self.quotes = prices
        }
    }

    // MARK: - Computed Properties

    /// Ordered stock list based on watchlist order
    var stockList: [StockPrice] {
        watchlist.tickers.compactMap { quotes[$0] }
    }

    /// KRW exchange rate
    var krwRate: Double {
        quotes["KRW=X"]?.price ?? 0
    }

    // MARK: - Data Loading

    func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        let allSymbols = watchlist.allTickers

        do {
            let stockPrices = try await api.fetchQuotes(symbols: allSymbols)
            let priceMap = Dictionary(uniqueKeysWithValues: stockPrices.map { ($0.id, $0) })

            webSocket.setInitialPrices(priceMap)
            quotes = webSocket.prices
            webSocket.subscribe(allSymbols)
            isSubscribed = true
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false

            if case StockAPIError.unauthorized = error {
                await retryAfterAuth(symbols: allSymbols)
            }
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        errorMessage = nil

        let allSymbols = watchlist.allTickers

        do {
            let stockPrices = try await api.fetchQuotes(symbols: allSymbols)
            let priceMap = Dictionary(uniqueKeysWithValues: stockPrices.map { ($0.id, $0) })

            webSocket.setInitialPrices(priceMap)
            quotes = webSocket.prices
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func retryAfterAuth(symbols: [String]) async {
        do {
            let stockPrices = try await api.fetchQuotes(symbols: symbols)
            let priceMap = Dictionary(uniqueKeysWithValues: stockPrices.map { ($0.id, $0) })

            webSocket.setInitialPrices(priceMap)
            quotes = webSocket.prices
            errorMessage = nil
        } catch {
            errorMessage = "데이터를 불러올 수 없습니다"
        }
    }

    // MARK: - Ticker Management

    func addTicker(_ symbol: String) {
        watchlist.addTicker(symbol)
        webSocket.subscribe([symbol.uppercased()])

        // Cancel previous add-ticker fetch if still in-flight
        addTickerTask?.cancel()
        addTickerTask = Task {
            do {
                let stockPrices = try await api.fetchQuotes(symbols: [symbol.uppercased()])
                guard !Task.isCancelled else { return }
                let priceMap = Dictionary(uniqueKeysWithValues: stockPrices.map { ($0.id, $0) })
                webSocket.setInitialPrices(priceMap)
                quotes = webSocket.prices
            } catch {
                // WebSocket will pick up data eventually
            }
        }
    }

    func removeTicker(_ symbol: String) {
        watchlist.removeTicker(symbol)
        webSocket.unsubscribe([symbol.uppercased()])
    }

    func moveTickers(from source: IndexSet, to destination: Int) {
        watchlist.reorderTickers(from: source, to: destination)
    }

    // MARK: - Lifecycle

    func onAppear() {
        if !isSubscribed {
            Task { await loadData() }
        } else {
            webSocket.connect()
        }
    }

    func onEnterForeground() {
        webSocket.connect()
        Task { await refresh() }
    }

    func onEnterBackground() {
        webSocket.disconnect()
    }
}
