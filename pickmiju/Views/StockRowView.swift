import SwiftUI

struct StockRowView: View {
    let stock: StockPrice
    let krwRate: Double
    let isKRW: Bool

    @State private var flashColor: Color? = nil

    private var isForex: Bool { stock.id == "KRW=X" }

    // 메인 행: 항상 정규장 가격 표시
    private var regularPrice: Double {
        let base = stock.regularMarketPrice != 0 ? stock.regularMarketPrice : stock.price
        return isKRW && !isForex && krwRate > 0 ? base * krwRate : base
    }

    private var extendedLabel: String {
        switch stock.marketHours {
        case 0: return "프리"
        case 2: return "애프터"
        default: return "시간외"
        }
    }

    private var showExtended: Bool {
        stock.isExtendedHours && stock.hasExtendedHoursData
    }

    var body: some View {
        HStack(spacing: 0) {
            // Column 0: Mini 1-day candle
            MiniCandleView(
                open: stock.openPrice,
                high: stock.dayHigh,
                low: stock.dayLow,
                close: stock.regularMarketPrice != 0 ? stock.regularMarketPrice : stock.price
            )
            .frame(width: 14, height: 32)
            .padding(.trailing, 8)

            // Column 1: Ticker & Name
            VStack(alignment: .leading, spacing: 3) {
                Text(stock.id)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                Text(stock.shortName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Column 2: Price (정규장 + 시간외)
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDisplayPrice(regularPrice))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                if showExtended {
                    Text(formatExtendedPrice(stock.extendedHoursPrice))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(changeTextColor(stock.extendedHoursChangePercent))
                }
            }
            .frame(width: 115, alignment: .trailing)

            // Column 3: Change badge (정규장 + 시간외)
            VStack(alignment: .trailing, spacing: 2) {
                HStack {
                    Spacer()
                    Text(formatChangePercent(stock.regularMarketChangePercent))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(changeBgColor(stock.regularMarketChangePercent))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }

                if showExtended {
                    HStack(spacing: 2) {
                        Text(extendedLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(extendedLabelColor)
                        Text(formatChangePercent(stock.extendedHoursChangePercent))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(changeTextColor(stock.extendedHoursChangePercent))
                    }
                }
            }
            .frame(width: 90)
        }
        .padding(.vertical, 6)
        .background(flashColor?.opacity(0.08) ?? Color.clear)
        .animation(.easeOut(duration: 0.3), value: flashColor)
        .onChange(of: stock.price) { oldValue, newValue in
            guard oldValue != 0, newValue != oldValue else { return }
            flashColor = newValue > oldValue ? .green : .red
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                flashColor = nil
            }
        }
    }

    // MARK: - Formatting

    private func formatDisplayPrice(_ price: Double) -> String {
        guard price != 0 else { return "-" }
        if isKRW && !isForex {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return "₩\(formatter.string(from: NSNumber(value: price)) ?? "0")"
        }
        let hint = stock.priceHint
        if price >= 1000 { return String(format: "%.\(min(hint, 2))f", price) }
        if price >= 1 { return String(format: "%.\(hint)f", price) }
        return String(format: "%.4f", price)
    }

    private func formatChangePercent(_ percent: Double) -> String {
        let prefix = percent >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.2f", percent))%"
    }

    private func changeBgColor(_ value: Double) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .gray
    }

    private func changeTextColor(_ value: Double) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }

    private var extendedLabelColor: Color {
        switch stock.marketHours {
        case 0: return .cyan
        case 2: return .purple
        default: return .secondary
        }
    }

    private func formatExtendedPrice(_ price: Double) -> String {
        guard price != 0 else { return "-" }
        if isKRW && !isForex && krwRate > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return "₩\(formatter.string(from: NSNumber(value: price * krwRate)) ?? "0")"
        }
        let hint = stock.priceHint
        if price >= 1000 { return String(format: "%.\(min(hint, 2))f", price) }
        if price >= 1 { return String(format: "%.\(hint)f", price) }
        return String(format: "%.4f", price)
    }
}
