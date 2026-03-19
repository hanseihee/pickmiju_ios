import SwiftUI

struct NewsDetailView: View {
    let news: NewsRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text(news.displayTitle)
                    .font(.system(size: 22, weight: .bold))

                // Meta
                HStack(spacing: 6) {
                    if !news.creator.isEmpty {
                        Text(news.creator)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.tertiary)
                    }

                    Text(news.relativeTime)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    if !news.category.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(news.category)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                // Tickers
                if !news.tickers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(news.tickers, id: \.self) { ticker in
                                Text(ticker)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.cyan)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.cyan.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                Divider()

                // Content
                Text(news.displaySummary)
                    .font(.system(size: 15))
                    .lineSpacing(6)

                // Original article link
                if let url = URL(string: news.link) {
                    Divider()

                    Link(destination: url) {
                        HStack {
                            Image(systemName: "link")
                            Text("원문 보기")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.blue)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationTitle("뉴스")
        .navigationBarTitleDisplayMode(.inline)
    }
}
