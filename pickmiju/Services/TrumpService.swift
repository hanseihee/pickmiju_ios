import Foundation
import Supabase

@Observable
@MainActor
final class TrumpService {
    var truths: [TrumpTruth] = []
    var latestTruth: TrumpTruth?
    var isLoading = false
    var isLoadingMore = false
    var hasMore = true

    private let pageSize = 20
    private let maxItems = 100

    func loadTruths() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            let records: [TrumpTruth] = try await supabase
                .from("trump_truths")
                .select()
                .order("created_at", ascending: false)
                .limit(pageSize)
                .execute()
                .value

            truths = records
            hasMore = records.count >= pageSize
        } catch {
            NSLog("[Trump] Fetch error: \(error)")
        }
        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore, truths.count < maxItems else { return }
        isLoadingMore = true

        let remaining = min(pageSize, maxItems - truths.count)

        do {
            let records: [TrumpTruth] = try await supabase
                .from("trump_truths")
                .select()
                .order("created_at", ascending: false)
                .range(from: truths.count, to: truths.count + remaining - 1)
                .execute()
                .value

            truths.append(contentsOf: records)
            hasMore = records.count >= remaining && truths.count < maxItems
        } catch {
            NSLog("[Trump] Load more error: \(error)")
        }
        isLoadingMore = false
    }

    func refresh() async {
        do {
            let records: [TrumpTruth] = try await supabase
                .from("trump_truths")
                .select()
                .order("created_at", ascending: false)
                .limit(pageSize)
                .execute()
                .value

            truths = records
            hasMore = records.count >= pageSize
        } catch {
            NSLog("[Trump] Refresh error: \(error)")
        }
    }

    func fetchLatest() async {
        do {
            // 웹버전 패턴: 최신 10개 중 번역된 첫 포스트 선택
            let records: [TrumpTruth] = try await supabase
                .from("trump_truths")
                .select()
                .order("created_at", ascending: false)
                .limit(10)
                .execute()
                .value

            latestTruth = records.first { record in
                if let ko = record.content_ko, !ko.isEmpty { return true }
                return false
            }
        } catch {
            NSLog("[Trump] Fetch latest error: \(error)")
        }
    }
}
