import Foundation
import Supabase

@Observable
@MainActor
final class WatchlistStore {
    private(set) var tickers: [String] = []
    private(set) var isLoaded = false

    private let storageKey = "stock-watchlist"
    private var currentUserId: String?
    private var saveTask: Task<Void, Never>?
    private let saveDebounceNanos: UInt64 = 100_000_000 // 0.1s — coalesce rapid taps

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
        "ES=F", "NQ=F", "YM=F",
    ]

    // Index vs Futures symbol groups for carousel switching
    static let indexTickers = ["^GSPC", "^IXIC", "^DJI"]
    static let futuresTickers = ["ES=F", "NQ=F", "YM=F"]

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

    /// 추가는 즉시 저장 (검색에서 바로 호출, 편집 모드 외부)
    func addTicker(_ symbol: String) {
        let upper = symbol.uppercased()
        guard !tickers.contains(upper) else { return }
        tickers.append(upper)
        saveLocal()
        scheduleCloudSave()
    }

    /// 삭제는 로컬만 — 완료 시 commitChanges()로 cloud 저장
    func removeTicker(_ symbol: String) {
        let upper = symbol.uppercased()
        tickers.removeAll { $0 == upper }
        saveLocal()
    }

    func hasTicker(_ symbol: String) -> Bool {
        tickers.contains(symbol.uppercased())
    }

    /// 이동은 로컬만 — 완료 시 commitChanges()로 cloud 저장
    func reorderTickers(from source: IndexSet, to destination: Int) {
        var items = tickers
        let movedItems = source.sorted().map { items[$0] }
        for index in source.sorted(by: >) {
            items.remove(at: index)
        }
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        items.insert(contentsOf: movedItems, at: min(adjustedDestination, items.count))
        tickers = items
        saveLocal()
    }

    func resetToDefaults() {
        tickers = Self.defaultTickers
        saveLocal()
        scheduleCloudSave()
    }

    /// 편집 모드 종료(완료 버튼) 시 호출 — pending 변경사항을 cloud에 commit
    func commitChanges() {
        scheduleCloudSave()
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
                saveLocal()
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
                .upsert(row, onConflict: "user_id")
                .execute()
        } catch {
            NSLog("[Watchlist] Cloud save error: \(error)")
        }
    }

    private func scheduleCloudSave() {
        guard let userId = currentUserId else { return }
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: self?.saveDebounceNanos ?? 100_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.saveToCloud(userId: userId, tickerList: self.tickers)
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
