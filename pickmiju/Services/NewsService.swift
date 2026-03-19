import Foundation
import Supabase

@Observable
final class NewsService {
    var news: [NewsRecord] = []
    var isLoading = false
    var isLoadingMore = false
    var hasMore = true

    private let pageSize = 20
    private let maxItems = 100

    func loadNews() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            let records: [NewsRecord] = try await supabase
                .from("news")
                .select()
                .order("pub_date", ascending: false)
                .limit(pageSize)
                .execute()
                .value

            news = records
            hasMore = records.count >= pageSize
        } catch {
            print("[News] Fetch error: \(error)")
        }
        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore && hasMore && news.count < maxItems else { return }
        isLoadingMore = true

        let remaining = min(pageSize, maxItems - news.count)

        do {
            let records: [NewsRecord] = try await supabase
                .from("news")
                .select()
                .order("pub_date", ascending: false)
                .range(from: news.count, to: news.count + remaining - 1)
                .execute()
                .value

            news.append(contentsOf: records)
            hasMore = records.count >= remaining && news.count < maxItems
        } catch {
            print("[News] Load more error: \(error)")
        }
        isLoadingMore = false
    }

    func refresh() async {
        do {
            let records: [NewsRecord] = try await supabase
                .from("news")
                .select()
                .order("pub_date", ascending: false)
                .limit(pageSize)
                .execute()
                .value

            news = records
            hasMore = records.count >= pageSize
        } catch {
            print("[News] Refresh error: \(error)")
        }
    }
}
