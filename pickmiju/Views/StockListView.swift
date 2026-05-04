import SwiftUI
import Combine

struct StockListView: View {
    @State var viewModel: StockListViewModel
    let settings: AppSettings
    @State private var showSearch = false
    @State private var marketInfo = MarketInfo.current()
    @Environment(\.scenePhase) private var scenePhase
    @State private var timerSubscription: Cancellable?
    private let marketTimer = Timer.publish(every: 1, on: .main, in: .common)

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
                    HStack(spacing: 4) {
                        Circle()
                            .fill(marketInfo.color)
                            .frame(width: 7, height: 7)
                        Text(marketInfo.label)
                            .font(.system(size: 11))
                            .foregroundStyle(marketInfo.color)
                            .fixedSize()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            let wasEditing = viewModel.isEditMode
                            withAnimation { viewModel.isEditMode.toggle() }
                            if wasEditing {
                                viewModel.watchlist.commitChanges()
                            }
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
                timerSubscription = marketTimer.connect()
            }
            .onDisappear {
                timerSubscription?.cancel()
                timerSubscription = nil
            }
            .onReceive(marketTimer) { _ in
                marketInfo = MarketInfo.current()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    viewModel.onEnterForeground()
                    if timerSubscription == nil {
                        timerSubscription = marketTimer.connect()
                    }
                case .background:
                    viewModel.onEnterBackground()
                    timerSubscription?.cancel()
                    timerSubscription = nil
                default:
                    break
                }
            }
        }
    }

    // MARK: - Stock List Content

    private var stockListContent: some View {
        List {
            // Market status + indices
            Section {
                indicesCarousel
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }

            // Trump SNS Banner
            Section {
                TrumpBannerView()
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
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

    /// 정규장: 현물 지수(^GSPC, ^IXIC, ^DJI) / 비정규장: 선물(ES=F, NQ=F, YM=F)
    private var indicesCarousel: some View {
        // API 데이터 우선, 없으면 로컬 시간 기반 fallback
        let isRegular: Bool = {
            if let gspc = viewModel.quotes["^GSPC"] {
                return gspc.marketHours == 1
            }
            return marketInfo.isRegularMarket
        }()

        let marketTickers = isRegular
            ? WatchlistStore.indexTickers
            : WatchlistStore.futuresTickers
        var displayStocks: [StockPrice] = []
        if let krw = viewModel.quotes["KRW=X"] {
            displayStocks.append(krw)
        }
        displayStocks += marketTickers.compactMap { viewModel.quotes[$0] }

        return VStack(alignment: .leading, spacing: 4) {
            // 배지 + 카운트다운 한 줄
            HStack {
                Text(isRegular ? "지수" : "선물")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isRegular ? Color.green : Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()

                Text("\(marketInfo.nextEventLabel)까지")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(marketInfo.countdown)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(displayStocks) { stock in
                        NavigationLink(value: stock) {
                            IndexCardView(stock: stock)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
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
        case "ES=F": return "S&P 500"
        case "NQ=F": return "NASDAQ"
        case "YM=F": return "DOW"
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
