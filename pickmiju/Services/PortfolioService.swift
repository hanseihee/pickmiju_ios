import Foundation
import Supabase

@Observable
final class PortfolioService {
    var lots: [StockLot] = []
    var isLoaded = false

    private var userId: String?

    /// Unique symbols in portfolio — for WebSocket subscription
    var symbols: [String] {
        Array(Set(lots.map(\.symbol)))
    }

    // MARK: - Auth Integration

    func onUserSignIn(userId: String) {
        self.userId = userId
        Task { await fetchLots() }
    }

    func onUserSignOut() {
        userId = nil
        lots = []
        isLoaded = true
    }

    // MARK: - Fetch

    private func fetchLots() async {
        guard let userId else {
            isLoaded = true
            return
        }

        do {
            let response: [StockLot] = try await supabase
                .from("portfolio_lots")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            lots = response
        } catch {
            print("[Portfolio] Fetch error: \(error)")
        }
        isLoaded = true
    }

    // MARK: - Add Lot

    func addLot(symbol: String, date: String, shares: Double, costPerShare: Double, memo: String? = nil) async {
        guard let userId else { return }

        let insert = StockLotInsert(
            user_id: userId,
            symbol: symbol.uppercased(),
            purchase_date: date,
            shares: shares,
            cost_per_share: costPerShare,
            memo: memo
        )

        do {
            let inserted: StockLot = try await supabase
                .from("portfolio_lots")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value

            lots.insert(inserted, at: 0)
        } catch {
            print("[Portfolio] Add error: \(error)")
        }
    }

    // MARK: - Delete Lot

    func deleteLot(id: String) async {
        guard userId != nil else { return }

        do {
            try await supabase
                .from("portfolio_lots")
                .delete()
                .eq("id", value: id)
                .execute()

            lots.removeAll { $0.id == id }
        } catch {
            print("[Portfolio] Delete error: \(error)")
        }
    }

    // MARK: - Calculations

    func calculateSummary(prices: [String: StockPrice]) -> PortfolioSummaryData {
        guard !lots.isEmpty else { return .empty }

        // Group lots by symbol
        let grouped = Dictionary(grouping: lots, by: \.symbol)

        var holdings: [StockHolding] = []
        var totalInvested: Double = 0
        var totalValue: Double = 0
        var todayGain: Double = 0
        var previousTotalValue: Double = 0

        for (symbol, symbolLots) in grouped {
            let currentPrice = prices[symbol]?.price ?? 0
            let previousClose = prices[symbol]?.previousClose ?? 0
            let change = prices[symbol]?.change ?? 0

            let lotsWithGains = symbolLots.map { lot -> StockLotWithGains in
                let cost = lot.shares * lot.cost_per_share
                let value = lot.shares * currentPrice
                let gain = value - cost
                let percent = cost > 0 ? (gain / cost) * 100 : 0
                return StockLotWithGains(
                    lot: lot, totalCost: cost, marketValue: value,
                    gainAmount: gain, gainPercent: percent
                )
            }

            let shares = symbolLots.reduce(0.0) { $0 + $1.shares }
            let cost = lotsWithGains.reduce(0.0) { $0 + $1.totalCost }
            let value = shares * currentPrice
            let gain = value - cost
            let percent = cost > 0 ? (gain / cost) * 100 : 0
            let avgCost = shares > 0 ? cost / shares : 0

            holdings.append(StockHolding(
                symbol: symbol, lots: lotsWithGains, totalShares: shares,
                totalCost: cost, totalValue: value, totalGain: gain,
                totalGainPercent: percent, averageCost: avgCost
            ))

            totalInvested += cost
            totalValue += value
            todayGain += change * shares
            previousTotalValue += previousClose * shares
        }

        // Sort by total value descending
        holdings.sort { $0.totalValue > $1.totalValue }

        let totalGain = totalValue - totalInvested
        let totalGainPercent = totalInvested > 0 ? (totalGain / totalInvested) * 100 : 0
        let todayGainPercent = previousTotalValue > 0 ? (todayGain / previousTotalValue) * 100 : 0

        return PortfolioSummaryData(
            holdings: holdings,
            totalInvested: totalInvested,
            totalValue: totalValue,
            totalGain: totalGain,
            totalGainPercent: totalGainPercent,
            todayGain: todayGain,
            todayGainPercent: todayGainPercent
        )
    }
}
