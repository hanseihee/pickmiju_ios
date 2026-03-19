import FirebaseAnalytics

enum AnalyticsService {
    // MARK: - Screen Views

    static func logScreenView(_ screenName: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
        ])
    }

    // MARK: - Stock Events

    static func logStockView(symbol: String) {
        Analytics.logEvent("stock_view", parameters: [
            "symbol": symbol,
        ])
    }

    static func logStockSearch(query: String) {
        Analytics.logEvent(AnalyticsEventSearch, parameters: [
            AnalyticsParameterSearchTerm: query,
        ])
    }

    // MARK: - Watchlist Events

    static func logWatchlistAdd(symbol: String) {
        Analytics.logEvent("watchlist_add", parameters: [
            "symbol": symbol,
        ])
    }

    static func logWatchlistRemove(symbol: String) {
        Analytics.logEvent("watchlist_remove", parameters: [
            "symbol": symbol,
        ])
    }

    // MARK: - Portfolio Events

    static func logPortfolioAddLot(symbol: String) {
        Analytics.logEvent("portfolio_add_lot", parameters: [
            "symbol": symbol,
        ])
    }

    // MARK: - News Events

    static func logNewsClick(title: String) {
        Analytics.logEvent("news_click", parameters: [
            "title": String(title.prefix(100)),
        ])
    }

    // MARK: - Chat Events

    static func logChatSend() {
        Analytics.logEvent("chat_send", parameters: nil)
    }
}
