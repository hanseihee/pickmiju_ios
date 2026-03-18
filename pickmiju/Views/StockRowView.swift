import SwiftUI

struct StockRowView: View {
    let stock: StockPrice
    let krwRate: Double
    let isKRW: Bool

    @State private var flashColor: Color? = nil

    private var isForex: Bool { stock.id == "KRW=X" }

    // Display price in selected currency
    private var displayPrice: Double {
        isKRW && !isForex && krwRate > 0 ? stock.price * krwRate : stock.price
    }

    private var displayChange: Double {
        isKRW && !isForex && krwRate > 0 ? stock.change * krwRate : stock.change
    }

    var body: some View {
        HStack(spacing: 0) {
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

            // Column 2: Price
            Text(formatDisplayPrice(displayPrice))
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .frame(width: 115, alignment: .trailing)

            // Column 3: Change badge
            HStack {
                Spacer()
                Text(formatChangePercent(stock.changePercent))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(changeBgColor(stock.changePercent))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
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
}
