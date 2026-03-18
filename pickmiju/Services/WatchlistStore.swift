import Foundation
import Supabase

@Observable
final class WatchlistStore {
    private(set) var tickers: [String] = []
    private(set) var isLoaded = false

    private let storageKey = "stock-watchlist"
    private var currentUserId: String?

    private static let defaultTickers = [
        "SPY", "QQQ", "DIA", "IWM",
        "AAPL", "MSFT", "GOOGL", "AMZN", "META", "NVDA", "TSLA",
        "AMD", "INTC", "AVGO", "QCOM",
        "JPM", "BAC", "GS", "V", "MA",
        "XOM", "CVX",
        "BTC-USD", "ETH-USD",
    ]

    // Required tickers always included for market data
    static let requiredTickers = [
        "KRW=X",
        "^GSPC", "^IXIC", "^DJI",
    ]

    /// All tickers = user tickers + required tickers (deduped)
    var allTickers: [String] {
        var combined = tickers
        for ticker in Self.requiredTickers where !combined.contains(ticker) {
            combined.append(ticker)
        }
        return combined
    }

    init() {
        loadLocal()
    }

    // MARK: - Auth Integration

    /// Call when user signs in — loads watchlist from Supabase
    func onUserSignIn(userId: String) {
        currentUserId = userId
        isLoaded = false
        Task {
            await loadFromCloud(userId: userId)
        }
    }

    /// Call when user signs out — revert to local storage
    func onUserSignOut() {
        currentUserId = nil
        loadLocal()
    }

    // MARK: - CRUD Operations

    func addTicker(_ symbol: String) {
        let upper = symbol.uppercased()
        guard !tickers.contains(upper) else { return }
        tickers.append(upper)
        save()
    }

    func removeTicker(_ symbol: String) {
        let upper = symbol.uppercased()
        tickers.removeAll { $0 == upper }
        save()
    }

    func hasTicker(_ symbol: String) -> Bool {
        tickers.contains(symbol.uppercased())
    }

    func reorderTickers(from source: IndexSet, to destination: Int) {
        var items = tickers
        let movedItems = source.sorted().map { items[$0] }
        for index in source.sorted(by: >) {
            items.remove(at: index)
        }
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        items.insert(contentsOf: movedItems, at: min(adjustedDestination, items.count))
        tickers = items
        save()
    }

    func resetToDefaults() {
        tickers = Self.defaultTickers
        save()
    }

    // MARK: - Local Persistence

    private func loadLocal() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([String].self, from: data),
           !saved.isEmpty {
            tickers = saved
        } else {
            tickers = Self.defaultTickers
        }
        isLoaded = true
    }

    private func saveLocal() {
        if let data = try? JSONEncoder().encode(tickers) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: - Cloud Persistence (Supabase)

    private func loadFromCloud(userId: String) async {
        do {
            let response: WatchlistRow = try await supabase
                .from("user_watchlist")
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value

            if !response.tickers.isEmpty {
                tickers = response.tickers
            } else {
                // No cloud data — upload local watchlist
                let localTickers = tickers.isEmpty ? Self.defaultTickers : tickers
                tickers = localTickers
                await saveToCloud(userId: userId, tickerList: localTickers)
            }
        } catch {
            // No row found (PGRST116) — upload local data
            let localTickers = tickers.isEmpty ? Self.defaultTickers : tickers
            tickers = localTickers
            await saveToCloud(userId: userId, tickerList: localTickers)
        }
        isLoaded = true
    }

    private func saveToCloud(userId: String, tickerList: [String]) async {
        let row = WatchlistUpsert(
            user_id: userId,
            tickers: tickerList,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        do {
            try await supabase
                .from("user_watchlist")
                .upsert(row)
                .execute()
        } catch {
            print("[Watchlist] Cloud save error: \(error)")
        }
    }

    private func save() {
        // Always save locally
        saveLocal()

        // Also save to cloud if logged in
        if let userId = currentUserId {
            Task {
                await saveToCloud(userId: userId, tickerList: tickers)
            }
        }
    }
}

// MARK: - Supabase Row Types

private struct WatchlistRow: Codable {
    let user_id: String
    let tickers: [String]
    let updated_at: String?
}

private struct WatchlistUpsert: Codable {
    let user_id: String
    let tickers: [String]
    let updated_at: String
}
