import Foundation

@Observable
final class StockSearchViewModel {
    var query = ""
    var results: [SearchResult] = []
    var isSearching = false

    private let api = StockAPIService.shared
    private var searchTask: Task<Void, Never>?

    func search() {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task {
            // Debounce: 500ms
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            do {
                let searchResults = try await api.searchStocks(query: trimmed)
                guard !Task.isCancelled else { return }
                results = searchResults
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                isSearching = false
            }
        }
    }

    func clear() {
        searchTask?.cancel()
        query = ""
        results = []
        isSearching = false
    }
}
