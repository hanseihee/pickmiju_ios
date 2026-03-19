import SwiftUI

struct PortfolioView: View {
    let portfolioService: PortfolioService
    let authService: AuthService
    let prices: [String: StockPrice]
    let krwRate: Double
    let watchlistOrder: [String]

    let settings: AppSettings

    @State private var showAddLot = false
    @State private var expandedSymbol: String?
    @State private var lotToDelete: StockLotWithGains?

    private var summary: PortfolioSummaryData {
        portfolioService.calculateSummary(prices: prices, watchlistOrder: watchlistOrder)
    }

    var body: some View {
        NavigationStack {
            Group {
                if !authService.isLoggedIn {
                    notLoggedInView
                } else if summary.holdings.isEmpty {
                    emptyPortfolioView
                } else {
                    portfolioContent
                }
            }
            .navigationTitle("포트폴리오")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if authService.isLoggedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddLot = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddLot) {
                AddLotSheet(portfolioService: portfolioService)
            }
            .alert("매수 기록 삭제", isPresented: Binding(
                get: { lotToDelete != nil },
                set: { if !$0 { lotToDelete = nil } }
            )) {
                Button("삭제", role: .destructive) {
                    if let lot = lotToDelete {
                        Task { await portfolioService.deleteLot(id: lot.lot.id) }
                        lotToDelete = nil
                    }
                }
                Button("취소", role: .cancel) {
                    lotToDelete = nil
                }
            } message: {
                if let lot = lotToDelete {
                    Text("\(lot.lot.symbol) \(formatShares(lot.lot.shares))주 (\(lot.lot.purchase_date))\n이 기록을 삭제하시겠습니까?")
                }
            }
        }
    }

    // MARK: - Portfolio Content

    private var portfolioContent: some View {
        List {
            // Summary card
            Section {
                summaryCard
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            // Allocation chart
            if summary.holdings.count >= 2 {
                Section {
                    allocationChart
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } header: {
                    Text("자산 비중")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            // Holdings
            Section {
                ForEach(summary.holdings) { holding in
                    holdingRow(holding)
                        .listRowSeparator(.hidden)
                }
            } header: {
                HStack {
                    Text("보유 종목")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(summary.holdings.count)개")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 12) {
            // Total value
            VStack(spacing: 4) {
                Text("총 평가금")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(displayAmount(summary.totalValue))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .contentTransition(.numericText())
            }

            // Gains row
            HStack(spacing: 0) {
                gainBox(label: "오늘", amount: summary.todayGain, percent: summary.todayGainPercent)
                Divider().frame(height: 36)
                gainBox(label: "총 손익", amount: summary.totalGain, percent: summary.totalGainPercent)
                Divider().frame(height: 36)
                gainBox(label: "투자금", amount: summary.totalInvested, percent: nil)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func gainBox(label: String, amount: Double, percent: Double?) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            if let percent {
                Text(displayChange(amount))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(changeColor(amount))
                Text(formatPercent(percent))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(changeColor(amount))
            } else {
                Text(displayAmount(amount))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // Currency-aware display
    private func displayAmount(_ usd: Double) -> String {
        settings.isKRW ? formatKRW(usd * krwRate) : formatUSD(usd)
    }

    private func displayChange(_ usd: Double) -> String {
        if settings.isKRW {
            let krw = usd * krwRate
            let prefix = krw >= 0 ? "+" : ""
            return "\(prefix)\(formatKRW(abs(krw)))"
        }
        return formatChange(usd)
    }

    // MARK: - Allocation Chart

    private static let chartColors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint, .cyan, .yellow
    ]

    private var allocationChart: some View {
        let total = summary.totalValue
        let items = Array(summary.holdings.prefix(8))

        return HStack(spacing: 0) {
            Spacer()
            HStack(alignment: .center, spacing: 40) {
            // Left: Donut chart
            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, holding in
                    let start = items.prefix(index).reduce(0.0) { $0 + $1.totalValue } / max(total, 1)
                    let end = start + holding.totalValue / max(total, 1)
                    Circle()
                        .trim(from: start, to: end)
                        .stroke(
                            Self.chartColors[index % Self.chartColors.count],
                            style: StrokeStyle(lineWidth: 14, lineCap: .butt)
                        )
                        .rotationEffect(.degrees(-90))
                }

                VStack(spacing: 1) {
                    Text("\(items.count)")
                        .font(.system(size: 16, weight: .bold))
                    Text("종목")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 90, height: 90)

            // Right: Legend
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, holding in
                    let pct = total > 0 ? (holding.totalValue / total) * 100 : 0
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Self.chartColors[index % Self.chartColors.count])
                            .frame(width: 8, height: 8)
                        Text(holding.symbol)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(width: 55, alignment: .leading)
                        Text(String(format: "%.1f%%", pct))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                }
            }
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Holding Row

    private func holdingRow(_ holding: StockHolding) -> some View {
        let isExpanded = expandedSymbol == holding.symbol

        return VStack(spacing: 0) {
            // Main row
            HStack(spacing: 0) {
                // Symbol & shares
                VStack(alignment: .leading, spacing: 3) {
                    Text(holding.symbol)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text("\(formatShares(holding.totalShares))주 · 평균 \(formatUSD(holding.averageCost))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Value, gain amount & percent badge
                VStack(alignment: .trailing, spacing: 3) {
                    Text(displayAmount(holding.totalValue))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)

                    Text(displayChange(holding.totalGain))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(changeColor(holding.totalGain))

                    Text(formatPercent(holding.totalGainPercent))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(changeBgColor(holding.totalGain))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }

                // 펼침/접힘 표시
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 8)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                // List의 암시적 셀 애니메이션 차단
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    expandedSymbol = isExpanded ? nil : holding.symbol
                }
            }

            // Expanded: lot details
            if isExpanded {
                lotDetails(holding)
            }
        }
    }

    // MARK: - Lot Details (Expanded)

    private func lotDetails(_ holding: StockHolding) -> some View {
        VStack(spacing: 0) {
            Divider().padding(.vertical, 4)

            ForEach(holding.lots) { lotGain in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lotGain.lot.purchase_date)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("\(formatShares(lotGain.lot.shares))주 × $\(String(format: "%.2f", lotGain.lot.cost_per_share))")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatChange(lotGain.gainAmount))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(changeColor(lotGain.gainAmount))
                        Text(formatPercent(lotGain.gainPercent))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(changeColor(lotGain.gainPercent))
                    }

                    // Delete button
                    Button {
                        lotToDelete = lotGain
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                }
                .padding(.vertical, 4)

                if lotGain.id != holding.lots.last?.id {
                    Divider()
                }
            }
        }
        .padding(.leading, 4)
    }

    // MARK: - Empty States

    private var notLoggedInView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("로그인하면 포트폴리오를\n관리할 수 있습니다")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Google로 로그인") {
                Task { try? await authService.signInWithGoogle() }
            }
            .buttonStyle(.bordered)
        }
    }

    private var emptyPortfolioView: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("보유 종목이 없습니다")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Text("+ 버튼을 눌러 매수 기록을 추가하세요")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Formatting

    private func formatUSD(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "$\(formatter.string(from: NSNumber(value: value)) ?? "0.00")"
    }

    private func formatKRW(_ krw: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "₩\(formatter.string(from: NSNumber(value: krw)) ?? "0")"
    }

    private func formatChange(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "\(prefix)$\(formatter.string(from: NSNumber(value: abs(value))) ?? "0.00")"
    }

    private func formatPercent(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.2f", value))%"
    }

    private func formatShares(_ shares: Double) -> String {
        shares == Double(Int(shares)) ? "\(Int(shares))" : String(format: "%.4f", shares)
    }

    private func changeBgColor(_ value: Double) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .gray
    }

    private func changeColor(_ value: Double) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }
}

// MARK: - Add Lot Sheet

private struct AddLotSheet: View {
    let portfolioService: PortfolioService
    @Environment(\.dismiss) private var dismiss
    @State private var symbol = ""
    @State private var shares = ""
    @State private var costPerShare = ""
    @State private var searchVM = StockSearchViewModel()
    @State private var selectedResult: SearchResult?
    @FocusState private var isSymbolFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("종목") {
                    TextField("티커 (예: AAPL)", text: $symbol)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .focused($isSymbolFocused)
                        .onChange(of: symbol) {
                            searchVM.query = symbol
                            searchVM.search()
                            // 직접 입력으로 변경 시 선택 해제
                            if selectedResult?.symbol != symbol.uppercased() {
                                selectedResult = nil
                            }
                        }

                    // 검색 결과 미리보기
                    if isSymbolFocused && !searchVM.results.isEmpty {
                        ForEach(searchVM.results.prefix(5)) { result in
                            Button {
                                symbol = result.symbol
                                selectedResult = result
                                isSymbolFocused = false
                            } label: {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.symbol)
                                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.primary)
                                        Text(result.name)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if let exchange = result.exchange {
                                        Text(exchange)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if searchVM.isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                            Spacer()
                        }
                    }

                    // 선택된 종목 표시
                    if let selected = selectedResult {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 14))
                            Text(selected.name)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Section("매수 정보") {
                    TextField("수량", text: $shares)
                        .keyboardType(.decimalPad)
                    TextField("매수가 (USD)", text: $costPerShare)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("매수 기록 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var isValid: Bool {
        !symbol.trimmingCharacters(in: .whitespaces).isEmpty
        && (Double(shares) ?? 0) > 0
        && (Double(costPerShare) ?? 0) > 0
    }

    private func save() {
        guard let sharesVal = Double(shares),
              let costVal = Double(costPerShare) else { return }

        let ticker = symbol.trimmingCharacters(in: .whitespaces).uppercased()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        Task {
            await portfolioService.addLot(
                symbol: ticker,
                date: today,
                shares: sharesVal,
                costPerShare: costVal
            )
            dismiss()
        }
    }
}
