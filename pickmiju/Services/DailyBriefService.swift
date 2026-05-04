import Foundation
import Supabase

@Observable
@MainActor
final class DailyBriefService {
    var brief: DailyBrief?
    var isLoading = false

    private var lastFetchedAt: Date?
    private let cacheTTL: TimeInterval = 3600 // 1시간

    func loadLatest(force: Bool = false) async {
        if !force,
           let last = lastFetchedAt,
           Date().timeIntervalSince(last) < cacheTTL,
           brief != nil {
            return
        }

        guard !isLoading else { return }
        isLoading = true

        do {
            let records: [DailyBrief] = try await supabase
                .from("daily_briefs")
                .select()
                .order("brief_date", ascending: false)
                .limit(1)
                .execute()
                .value

            brief = records.first
            lastFetchedAt = Date()
        } catch {
            NSLog("[DailyBrief] Fetch error: \(error)")
        }
        isLoading = false
    }

    func refresh() async {
        await loadLatest(force: true)
    }
}
