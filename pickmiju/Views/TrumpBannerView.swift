import SwiftUI

struct TrumpBannerView: View {
    @State private var trumpService = TrumpService()
    @State private var animating = false
    @State private var isPresented = false

    var body: some View {
        ZStack {
            if let truth = trumpService.latestTruth {
                Button {
                    isPresented = true
                } label: {
                    bannerContent(truth)
                }
                .buttonStyle(.plain)
                .navigationDestination(isPresented: $isPresented) {
                    TrumpListView()
                }
            } else {
                // 초기 로딩 중에도 뷰가 렌더링되도록 placeholder 유지
                Color.clear.frame(height: 1)
            }
        }
        .task {
            await trumpService.fetchLatest()
        }
    }

    private func bannerContent(_ truth: TrumpTruth) -> some View {
        HStack(spacing: 10) {
            // 라이브 인디케이터 + 아이콘
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .fill(.red.opacity(0.4))
                            .frame(width: 12, height: 12)
                            .scaleEffect(animating ? 1.5 : 1.0)
                            .opacity(animating ? 0 : 0.6)
                    )

                Image("TrumpAvatar")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())

                Text("트럼프")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.orange)
            }

            // 내용
            VStack(alignment: .leading, spacing: 2) {
                Text(truth.displayContent)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(truth.relativeTime)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.yellow.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.yellow.opacity(0.15), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animating = true
            }
        }
    }

}
