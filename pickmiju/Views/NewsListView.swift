import SwiftUI

struct NewsListView: View {
    @State private var newsService = NewsService()

    var body: some View {
        NavigationStack {
            Group {
                if newsService.isLoading && newsService.news.isEmpty {
                    loadingView
                } else if newsService.news.isEmpty {
                    emptyView
                } else {
                    newsList
                }
            }
            .navigationTitle("뉴스")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: NewsRecord.self) { record in
                NewsDetailView(news: record)
            }
            .refreshable {
                await newsService.refresh()
            }
            .task {
                if newsService.news.isEmpty {
                    await newsService.loadNews()
                }
            }
        }
    }

    // MARK: - News List

    private var newsList: some View {
        List {
            ForEach(newsService.news) { record in
                NavigationLink(value: record) {
                    NewsRowView(news: record)
                }
            }

            if newsService.hasMore {
                Button {
                    Task { await newsService.loadMore() }
                } label: {
                    Group {
                        if newsService.isLoadingMore {
                            ProgressView()
                        } else {
                            Text("더 보기")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .disabled(newsService.isLoadingMore)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Loading & Empty

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("뉴스 불러오는 중...")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("아직 뉴스가 없습니다")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - News Row View

private struct NewsRowView: View {
    let news: NewsRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(news.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Text(news.relativeTime)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize()
            }

            if !news.displaySummary.isEmpty {
                Text(news.displaySummary)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if !news.tickers.isEmpty {
                tickerBadges
            }
        }
        .padding(.vertical, 4)
    }

    private var tickerBadges: some View {
        let displayed = Array(news.tickers.prefix(5))
        let remaining = news.tickers.count - displayed.count

        return HStack(spacing: 4) {
            ForEach(displayed, id: \.self) { ticker in
                Text(ticker)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.cyan.opacity(0.15))
                    .clipShape(Capsule())
            }

            if remaining > 0 {
                Text("+\(remaining)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
