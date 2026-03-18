import SwiftUI

struct StockListView: View {
    @State var viewModel: StockListViewModel
    let settings: AppSettings
    @State private var showSearch = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.quotes.isEmpty {
                    loadingView
                } else if let error = viewModel.errorMessage, viewModel.quotes.isEmpty {
                    errorView(error)
                } else {
                    stockListContent
                }
            }
            .navigationTitle("주식")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    wsStatusIndicator
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation { viewModel.isEditMode.toggle() }
                        } label: {
                            Text(viewModel.isEditMode ? "완료" : "편집")
                                .font(.system(size: 14))
                        }

                        Button {
                            showSearch = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                StockSearchView(
                    onAdd: { symbol in
                        viewModel.addTicker(symbol)
                    },
                    hasTicker: { symbol in
                        viewModel.watchlist.hasTicker(symbol)
                    }
                )
            }
            .navigationDestination(for: StockPrice.self) { stock in
                StockDetailView(
                    symbol: stock.id,
                    initialStock: stock,
                    krwRate: viewModel.krwRate,
                    isKRW: settings.isKRW
                )
            }
            .refreshable {
                await viewModel.refresh()
            }
            .onAppear {
                viewModel.onAppear()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    viewModel.onEnterForeground()
                case .background:
                    viewModel.onEnterBackground()
                default:
                    break
                }
            }
        }
    }

    // MARK: - Stock List Content

    private var stockListContent: some View {
        List {
            // Market indices — horizontal swipeable cards (pinned in list)
            Section {
                indicesCarousel
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }

            // Watchlist
            Section {
                ForEach(viewModel.stockList) { stock in
                    NavigationLink(value: stock) {
                        StockRowView(stock: stock, krwRate: viewModel.krwRate, isKRW: settings.isKRW)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let ticker = viewModel.stockList[index].id
                        viewModel.removeTicker(ticker)
                    }
                }
                .onMove { source, destination in
                    viewModel.moveTickers(from: source, to: destination)
                }
            } header: {
                HStack(spacing: 0) {
                    Text("종목")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(settings.isKRW ? "현재가(₩)" : "현재가($)")
                        .frame(width: 115, alignment: .trailing)
                    Text("변동")
                        .frame(width: 95, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(viewModel.isEditMode ? .active : .inactive))
    }

    // MARK: - Indices Carousel

    private var indicesCarousel: some View {
        let indices = WatchlistStore.requiredTickers.compactMap { viewModel.quotes[$0] }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(indices) { stock in
                    IndexCardView(stock: stock)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - WebSocket Status Indicator

    private var wsStatusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(wsStatusColor)
                .frame(width: 7, height: 7)
            Text(wsStatusText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
    }

    private var wsStatusColor: Color {
        switch viewModel.webSocket.status {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .gray
        case .error: return .red
        }
    }

    private var wsStatusText: String {
        switch viewModel.webSocket.status {
        case .connected: return "실시간"
        case .connecting: return "연결중"
        case .disconnected: return "연결끊김"
        case .error: return "오류"
        }
    }

    // MARK: - Loading & Error Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("시세 불러오는 중...")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("다시 시도") {
                Task { await viewModel.loadData() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Index Card View

private struct IndexCardView: View {
    let stock: StockPrice

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(formatPrice(stock.price))
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            HStack(spacing: 3) {
                Image(systemName: stock.changePercent >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                Text(formatChangePercent(stock.changePercent))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(changeColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 110)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(changeColor.opacity(0.25), lineWidth: 1)
        )
    }

    private var displayName: String {
        switch stock.id {
        case "^GSPC": return "S&P 500"
        case "^IXIC": return "NASDAQ"
        case "^DJI": return "DOW"
        case "KRW=X": return "USD/KRW"
        default: return stock.shortName
        }
    }

    private var changeColor: Color {
        if stock.changePercent > 0 { return .green }
        if stock.changePercent < 0 { return .red }
        return .secondary
    }

    private func formatPrice(_ price: Double) -> String {
        guard price != 0 else { return "-" }
        if stock.id == "KRW=X" {
            return String(format: "%.1f", price)
        }
        return price >= 10000
            ? String(format: "%.0f", price)
            : String(format: "%.2f", price)
    }

    private func formatChangePercent(_ percent: Double) -> String {
        let prefix = percent >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.2f", percent))%"
    }
}
