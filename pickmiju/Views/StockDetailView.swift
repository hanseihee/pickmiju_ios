import SwiftUI

struct StockDetailView: View {
    let symbol: String
    let initialStock: StockPrice?
    let krwRate: Double
    let isKRW: Bool

    @State private var stock: StockPrice?
    @State private var isLoading = false

    private let api = StockAPIService.shared
    private let webSocket = YahooWebSocketService()

    private var data: StockPrice {
        stock ?? initialStock ?? .empty(id: symbol)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header — Price & Info
                headerSection

                // Chart
                StockChartView(
                    symbol: symbol,
                    currentPrice: data.price,
                    previousClose: data.previousClose
                )
                .padding(.horizontal)

                // Key Stats
                keyStatsSection
                    .padding(.horizontal)

                // Trading Data
                tradingDataSection
                    .padding(.horizontal)

                // 52 Week
                weekRangeSection
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemBackground))
        .navigationTitle(symbol)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
            startWebSocket()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            // Company Name & Type
            HStack(spacing: 8) {
                Text(data.shortName)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                quoteTypeBadge
                Spacer()
            }
            .padding(.horizontal)

            // Price — 항상 정규장 가격 표시
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(displayPrice(data.regularMarketPrice != 0 ? data.regularMarketPrice : data.price))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .contentTransition(.numericText())

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(displayChangeAmount(data.regularMarketChange))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    Text(formatChangePercent(data.regularMarketChangePercent))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(changeColor(data.regularMarketChangePercent))
            }
            .padding(.horizontal)

            // Extended hours
            if data.hasExtendedHoursData && data.isExtendedHours {
                HStack(spacing: 8) {
                    Text(marketStateLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(marketStateColor)
                        .clipShape(Capsule())

                    Text(formatPrice(data.extendedHoursPrice))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))

                    Text(formatChangePercent(data.extendedHoursChangePercent))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(changeColor(data.extendedHoursChangePercent))

                    Spacer()
                }
                .padding(.horizontal)
            }

            // Summary stats row
            HStack(spacing: 0) {
                statItem(label: "전일 종가", value: formatPrice(data.previousClose))
                Divider().frame(height: 30)
                statItem(label: "일중 범위", value: "\(formatShort(data.dayLow))-\(formatShort(data.dayHigh))")
                Divider().frame(height: 30)
                statItem(label: "거래량", value: formatVolume(data.dayVolume))
                if data.marketCap > 0 {
                    Divider().frame(height: 30)
                    statItem(label: "시가총액", value: formatLargeNumber(data.marketCap))
                }
            }
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        }
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Key Stats Section

    private var keyStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("주요 지표")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 8) {
                if data.previousClose != 0 {
                    keyStatRow(label: "시가", value: formatPrice(data.openPrice))
                }
                if data.bid != 0 {
                    keyStatRow(label: "매수호가", value: formatPrice(data.bid))
                }
                if data.ask != 0 {
                    keyStatRow(label: "매도호가", value: formatPrice(data.ask))
                }
                if data.dividendYield != 0 {
                    keyStatRow(label: "배당수익률", value: String(format: "%.2f%%", data.dividendYield))
                }
            }
        }
    }

    private func keyStatRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Trading Data Section

    private var tradingDataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("거래 정보")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                dataRow(label: "시가", value: formatPrice(data.openPrice))
                Divider()
                dataRow(label: "고가", value: formatPrice(data.dayHigh), color: .green)
                Divider()
                dataRow(label: "저가", value: formatPrice(data.dayLow), color: .red)
                Divider()
                dataRow(label: "전일 종가", value: formatPrice(data.previousClose))
                Divider()
                dataRow(label: "거래량", value: formatVolume(data.dayVolume))
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - 52 Week Range Section

    private var weekRangeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("52주 범위")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            if data.fiftyTwoWeekLow > 0 && data.fiftyTwoWeekHigh > 0 {
                VStack(spacing: 12) {
                    // Range bar
                    let range = data.fiftyTwoWeekHigh - data.fiftyTwoWeekLow
                    let position = range > 0 ? (data.price - data.fiftyTwoWeekLow) / range : 0.5
                    let clamped = max(0, min(1, position))

                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(.systemGray4))
                                    .frame(height: 6)

                                Circle()
                                    .fill(changeColor(data.changePercent))
                                    .frame(width: 12, height: 12)
                                    .offset(x: geo.size.width * clamped - 6)
                            }
                        }
                        .frame(height: 12)

                        HStack {
                            Text(formatPrice(data.fiftyTwoWeekLow))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.red)
                            Spacer()
                            Text(formatPrice(data.fiftyTwoWeekHigh))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Data Row Helper

    private func dataRow(label: String, value: String, color: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(color ?? .primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Quote Type Badge

    private var quoteTypeBadge: some View {
        let text: String = {
            switch data.quoteType {
            case 0: return "주식"
            case 1: return "ETF"
            case 2: return "지수"
            case 3: return "암호화폐"
            case 4: return "통화"
            case 5: return "선물"
            default: return "기타"
            }
        }()

        return Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15))
            .clipShape(Capsule())
    }

    // MARK: - Market State

    private var marketStateLabel: String {
        switch data.marketHours {
        case 0: return "프리마켓"
        case 2: return "애프터마켓"
        default: return "시간외"
        }
    }

    private var marketStateColor: Color {
        switch data.marketHours {
        case 0: return .cyan
        case 2: return .purple
        default: return .gray
        }
    }

    // MARK: - Formatting

    private func formatPrice(_ price: Double) -> String {
        guard price != 0 else { return "-" }
        if price >= 1000 { return String(format: "%.2f", price) }
        if price >= 1 { return String(format: "%.2f", price) }
        return String(format: "%.4f", price)
    }

    private func formatShort(_ price: Double) -> String {
        guard price != 0 else { return "-" }
        return price >= 1000 ? String(format: "%.0f", price) : String(format: "%.2f", price)
    }

    private func formatChange(_ change: Double) -> String {
        let prefix = change >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.2f", change))"
    }

    private func formatChangePercent(_ percent: Double) -> String {
        let prefix = percent >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.2f", percent))%"
    }

    private func formatKRW(_ krw: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "₩\(formatter.string(from: NSNumber(value: krw)) ?? "\(Int(krw))")"
    }

    private func displayPrice(_ price: Double) -> String {
        if isKRW && krwRate > 0 { return formatKRW(price * krwRate) }
        return formatPrice(price)
    }

    private func displayChangeAmount(_ change: Double) -> String {
        if isKRW && krwRate > 0 {
            let krw = change * krwRate
            let prefix = krw >= 0 ? "+" : ""
            return "\(prefix)\(formatKRW(abs(krw)))"
        }
        return formatChange(change)
    }

    private func formatVolume(_ volume: Int) -> String {
        if volume >= 1_000_000_000 { return String(format: "%.1fB", Double(volume) / 1_000_000_000) }
        if volume >= 1_000_000 { return String(format: "%.1fM", Double(volume) / 1_000_000) }
        if volume >= 1_000 { return String(format: "%.1fK", Double(volume) / 1_000) }
        return "\(volume)"
    }

    private func formatLargeNumber(_ value: Double) -> String {
        if value >= 1_000_000_000_000 { return String(format: "$%.2fT", value / 1_000_000_000_000) }
        if value >= 1_000_000_000 { return String(format: "$%.1fB", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "$%.1fM", value / 1_000_000) }
        return String(format: "$%.0f", value)
    }

    private func changeColor(_ value: Double) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }

    // MARK: - Data Loading

    private func loadDetail() async {
        isLoading = true
        do {
            let prices = try await api.fetchQuotes(symbols: [symbol])
            if let price = prices.first {
                stock = price
            }
        } catch {
            // Use initialStock as fallback
        }
        isLoading = false
    }

    private func startWebSocket() {
        webSocket.onPriceUpdate { [symbol] prices in
            if let updated = prices[symbol] {
                stock = updated
            }
        }
        webSocket.subscribe([symbol])
        if let initial = stock ?? initialStock {
            webSocket.setInitialPrices([symbol: initial])
        }
    }
}
