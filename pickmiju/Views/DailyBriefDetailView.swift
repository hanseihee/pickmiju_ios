import SwiftUI

struct DailyBriefDetailView: View {
    let brief: DailyBrief

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 28) {
                    headlineSection

                    if !brief.top_issues.isEmpty {
                        issuesSection
                    }

                    if !brief.top_tickers.isEmpty {
                        tickersSection
                    }

                    if !brief.risks.isEmpty {
                        risksSection
                    }

                    if let upcoming = brief.upcoming, !upcoming.isEmpty {
                        upcomingSection(upcoming)
                    }

                    footerSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                // 폭을 명시적으로 화면 폭으로 제한 → 어떤 자식도 가로로 넘치지 않음
                .frame(width: geo.size.width, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
        .background(Color(.systemBackground))
        .navigationTitle("오늘의 브리핑")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var headlineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(brief.formattedDateLong)
                Text("·")
                Text("뉴스 \(brief.news_count)건 종합")
            }
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)

            Text(brief.headline)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !brief.market_summary.isEmpty {
                Text(brief.market_summary)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.cyan.opacity(0.10), Color.blue.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.cyan.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(emoji: "🔥", title: "오늘의 핵심 이슈")
            VStack(spacing: 10) {
                ForEach(Array(brief.top_issues.enumerated()), id: \.offset) { idx, issue in
                    BriefIssueCard(issue: issue, index: idx + 1)
                }
            }
        }
    }

    private var tickersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(emoji: "📈", title: "주목할 종목")
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(brief.top_tickers, id: \.ticker) { ticker in
                    BriefTickerCard(item: ticker)
                }
            }
        }
    }

    private var risksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(emoji: "⚠️", title: "시장 위험 요인")
            VStack(spacing: 8) {
                ForEach(Array(brief.risks.enumerated()), id: \.offset) { _, risk in
                    BriefRiskRow(risk: risk)
                }
            }
        }
    }

    private func upcomingSection(_ events: [BriefUpcomingEvent]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(emoji: "📅", title: "다음 주요 일정")
            VStack(spacing: 8) {
                ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                    BriefUpcomingRow(event: event)
                }
            }
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
                .padding(.bottom, 8)
            Text("AI 종합 브리핑은 참고용입니다. 투자 결정은 본인의 책임이며, 정확한 정보는 원본 뉴스나 공식 자료를 확인하세요.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineSpacing(3)
            if let model = brief.ai_model {
                Text("생성 모델: \(model)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func sectionHeader(emoji: String, title: String) -> some View {
        HStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 16))
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Sub Components

private struct BriefIssueCard: View {
    let issue: BriefTopIssue
    let index: Int

    var body: some View {
        let level = issue.importanceLevel
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(String(format: "%02d", index))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(issue.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text(level.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(level.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(level.accentColor.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(level.accentColor.opacity(0.4), lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Text(issue.summary)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if !issue.relatedTickers.isEmpty {
                WrappingHStack(hSpacing: 5, vSpacing: 5) {
                    ForEach(issue.relatedTickers, id: \.self) { ticker in
                        Text(ticker)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.cyan.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .overlay(
            HStack(spacing: 0) {
                Rectangle()
                    .fill(level.accentColor)
                    .frame(width: 3)
                Spacer()
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct BriefTickerCard: View {
    let item: BriefTopTicker

    var body: some View {
        let level = item.sentimentLevel
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.ticker)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                Spacer()
                Text("\(level.arrow) \(level.label)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(level.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(level.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            Text(item.reason)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct BriefRiskRow: View {
    let risk: BriefRisk

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("⚠")
                .foregroundStyle(.orange)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(risk.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(risk.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct BriefUpcomingRow: View {
    let event: BriefUpcomingEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(DailyBrief.formatEventDate(event.date))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                if let time = event.time, !time.isEmpty {
                    Text(time)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
            }
            .frame(minWidth: 64, alignment: .center)

            Text(event.title)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Wrapping HStack (chip 가로 흐름이 컨테이너를 넘으면 다음 줄로 wrap)

private struct WrappingHStack: Layout {
    var hSpacing: CGFloat = 8
    var vSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // proposal.width가 nil/infinity면 부모에게 자기 폭을 요구하지 말고 0 반환
        // (부모에서 frame(maxWidth: .infinity)로 채워주면 placeSubviews에서 실제 폭 받음)
        guard let maxWidth = proposal.width, maxWidth.isFinite, maxWidth > 0 else {
            // ideal-size pass — 단일 행 가정한 자연 크기 반환
            let totalWidth = subviews.reduce(0.0) { acc, sv in
                acc + sv.sizeThatFits(.unspecified).width + hSpacing
            }
            let maxHeight = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            return CGSize(width: max(0, totalWidth - hSpacing), height: maxHeight)
        }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + vSpacing
                lineHeight = 0
            }
            x += size.width + hSpacing
            lineHeight = max(lineHeight, size.height)
        }
        // 폭은 항상 maxWidth (부모가 준 폭) 사용 — 절대 부모 폭을 넘지 않음
        return CGSize(width: maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + vSpacing
                lineHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + hSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
