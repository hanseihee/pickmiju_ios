import Foundation
import SwiftUI

@Observable
final class StockListViewModel {
    var quotes: [String: StockPrice] = [:]
    var isLoading = false
    var errorMessage: String?
    var isEditMode = false

    /// 포트폴리오 전용 심볼 — MainTabView에서 설정
    var portfolioSymbols: [String] = []

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

    /// 관심종목 + 포트폴리오 + 필수 지수를 모두 합친 전체 심볼 목록
    private var allSymbols: [String] {
        var symbols = watchlist.allTickers
        for s in portfolioSymbols where !symbols.contains(s) {
            symbols.append(s)
        }
        return symbols
    }

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

        let symbols = allSymbols

        do {
            let stockPrices = try await api.fetchQuotes(symbols: symbols)
            let priceMap = Dictionary(uniqueKeysWithValues: stockPrices.map { ($0.id, $0) })

            webSocket.setInitialPrices(priceMap)
            quotes = webSocket.prices
            webSocket.subscribe(symbols)
            isSubscribed = true
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false

            if case StockAPIError.unauthorized = error {
                await retryAfterAuth(symbols: symbols)
            }
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        errorMessage = nil

        let symbols = allSymbols

        do {
            let stockPrices = try await api.fetchQuotes(symbols: symbols)
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

        addTickerTask?.cancel()
        addTickerTask = Task {
            do {
                let stockPrices = try await api.fetchQuotes(symbols: [symbol.uppercased()])
                guard !Task.isCancelled else { return }
                let priceMap = Dictionary(uniqueKeysWithValues: stockPrices.map { ($0.id, $0) })
                webSocket.setInitialPrices(priceMap)
                quotes = webSocket.prices
            } catch {}
        }
    }

    func removeTicker(_ symbol: String) {
        watchlist.removeTicker(symbol)
        webSocket.unsubscribe([symbol.uppercased()])
    }

    func moveTickers(from source: IndexSet, to destination: Int) {
        watchlist.reorderTickers(from: source, to: destination)
    }

    // MARK: - Reload

    /// 관심종목 또는 포트폴리오 변경 시 전체 심볼 다시 로드
    func reloadAllSymbols() {
        let symbols = allSymbols
        webSocket.subscribe(symbols)
        Task {
            do {
                let stockPrices = try await api.fetchQuotes(symbols: symbols)
                let priceMap = Dictionary(uniqueKeysWithValues: stockPrices.map { ($0.id, $0) })
                webSocket.setInitialPrices(priceMap)
                quotes = webSocket.prices
            } catch {}
        }
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
