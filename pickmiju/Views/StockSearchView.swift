import SwiftUI

struct StockSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = StockSearchViewModel()

    let onAdd: (String) -> Void
    let hasTicker: (String) -> Bool

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                } else if viewModel.results.isEmpty && !viewModel.query.isEmpty {
                    ContentUnavailableView(
                        "검색 결과 없음",
                        systemImage: "magnifyingglass",
                        description: Text("'\(viewModel.query)'에 대한 결과가 없습니다")
                    )
                } else {
                    ForEach(viewModel.results) { result in
                        searchResultRow(result)
                    }
                }
            }
            .searchable(
                text: $viewModel.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "티커 또는 종목명 검색"
            )
            .onChange(of: viewModel.query) {
                viewModel.search()
            }
            .navigationTitle("종목 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func searchResultRow(_ result: SearchResult) -> some View {
        let alreadyAdded = hasTicker(result.symbol)

        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(result.symbol)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    if let type = result.type {
                        Text(type)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(result.name)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let exchange = result.exchange {
                    Text(exchange)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if alreadyAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Button {
                    onAdd(result.symbol)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}
