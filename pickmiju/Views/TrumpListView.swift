import SwiftUI

struct TrumpListView: View {
    @State private var trumpService = TrumpService()

    var body: some View {
        Group {
            if trumpService.isLoading && trumpService.truths.isEmpty {
                loadingView
            } else if trumpService.truths.isEmpty {
                emptyView
            } else {
                truthList
            }
        }
        .navigationTitle("트럼프 SNS")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await trumpService.refresh()
        }
        .task {
            if trumpService.truths.isEmpty {
                await trumpService.loadTruths()
            }
        }
    }

    // MARK: - Truth List

    private var truthList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(trumpService.truths) { truth in
                    TrumpCardView(truth: truth)
                }

                if trumpService.hasMore {
                    Button {
                        Task { await trumpService.loadMore() }
                    } label: {
                        Group {
                            if trumpService.isLoadingMore {
                                ProgressView()
                            } else {
                                Text("더 보기")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .disabled(trumpService.isLoadingMore)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Loading & Empty

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("게시물 불러오는 중...")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("아직 게시물이 없습니다")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }
}
