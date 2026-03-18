import Foundation

// MARK: - StockPrice Model

struct StockPrice: Identifiable, Codable, Equatable, Hashable {
    var id: String  // Ticker symbol
    var price: Double
    var time: Int
    var currency: String
    var exchange: String
    var quoteType: Int
    var marketHours: Int // 0=pre, 1=regular, 2=post, 3=extended
    var changePercent: Double
    var dayVolume: Int
    var dayHigh: Double
    var dayLow: Double
    var change: Double
    var shortName: String
    var previousClose: Double
    var priceHint: Int
    var openPrice: Double
    var bid: Double
    var bidSize: Int
    var ask: Double
    var askSize: Int
    var lastSize: Int
    var vol24hr: Int
    var marketCap: Double
    var circulatingSupply: Double

    // Regular market data
    var regularMarketPrice: Double
    var regularMarketChange: Double
    var regularMarketChangePercent: Double

    // Extended hours data
    var extendedHoursPrice: Double
    var extendedHoursChange: Double
    var extendedHoursChangePercent: Double

    // 52 Week
    var fiftyTwoWeekHigh: Double
    var fiftyTwoWeekLow: Double

    // Dividend
    var dividendYield: Double

    // Earnings
    var earningsTimestamp: Int?

    static func empty(id: String) -> StockPrice {
        StockPrice(
            id: id, price: 0, time: 0, currency: "USD", exchange: "",
            quoteType: 0, marketHours: 1, changePercent: 0, dayVolume: 0,
            dayHigh: 0, dayLow: 0, change: 0, shortName: id, previousClose: 0,
            priceHint: 2, openPrice: 0, bid: 0, bidSize: 0, ask: 0, askSize: 0,
            lastSize: 0, vol24hr: 0, marketCap: 0, circulatingSupply: 0,
            regularMarketPrice: 0, regularMarketChange: 0, regularMarketChangePercent: 0,
            extendedHoursPrice: 0, extendedHoursChange: 0, extendedHoursChangePercent: 0,
            fiftyTwoWeekHigh: 0, fiftyTwoWeekLow: 0, dividendYield: 0, earningsTimestamp: nil
        )
    }

    var isExtendedHours: Bool {
        marketHours != 1
    }

    var hasExtendedHoursData: Bool {
        extendedHoursPrice != 0
    }
}

// MARK: - Search Result

struct SearchResult: Identifiable, Codable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let exchange: String?
    let type: String?
}
