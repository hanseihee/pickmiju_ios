import Foundation

// MARK: - Stock Lot (individual purchase record)

struct StockLot: Identifiable, Codable, Equatable {
    let id: String
    let symbol: String
    let purchase_date: String  // YYYY-MM-DD
    let shares: Double
    let cost_per_share: Double
    let memo: String?
    let user_id: String?
    let created_at: String?
}

struct StockLotInsert: Codable {
    let user_id: String
    let symbol: String
    let purchase_date: String
    let shares: Double
    let cost_per_share: Double
    let memo: String?
}

// MARK: - Lot with calculated gains

struct StockLotWithGains: Identifiable {
    let lot: StockLot
    let totalCost: Double
    let marketValue: Double
    let gainAmount: Double
    let gainPercent: Double

    var id: String { lot.id }
}

// MARK: - Holding (aggregated per symbol)

struct StockHolding: Identifiable {
    let symbol: String
    let lots: [StockLotWithGains]
    let totalShares: Double
    let totalCost: Double
    let totalValue: Double
    let totalGain: Double
    let totalGainPercent: Double
    let averageCost: Double

    var id: String { symbol }
}

// MARK: - Portfolio Summary

struct PortfolioSummaryData {
    let holdings: [StockHolding]
    let totalInvested: Double
    let totalValue: Double
    let totalGain: Double
    let totalGainPercent: Double
    let todayGain: Double
    let todayGainPercent: Double

    static let empty = PortfolioSummaryData(
        holdings: [], totalInvested: 0, totalValue: 0,
        totalGain: 0, totalGainPercent: 0, todayGain: 0, todayGainPercent: 0
    )
}
