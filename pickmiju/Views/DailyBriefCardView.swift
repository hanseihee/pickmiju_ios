import SwiftUI

struct DailyBriefCardView: View {
    let brief: DailyBrief

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("📰")
                .font(.system(size: 28))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("오늘의 시장 브리핑")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("NEW")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.yellow.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                Text(brief.headline)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Text(brief.formattedDateShort)
                    Text("·")
                    Text("뉴스 \(brief.news_count)건 종합")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.cyan)
                .padding(.top, 8)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.14),
                    Color.blue.opacity(0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.cyan.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
