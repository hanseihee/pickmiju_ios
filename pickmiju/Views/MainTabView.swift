import SwiftUI
import Auth

struct MainTabView: View {
    @State private var watchlist = WatchlistStore()
    @State private var authService = AuthService()
    @State private var chatService = ChatService()
    @State private var portfolioService = PortfolioService()
    @State private var settings = AppSettings()
    @State private var selectedTab = 0

    // Single shared ViewModel — created once, shared across tabs
    @State private var stockViewModel: StockListViewModel?

    private var viewModel: StockListViewModel {
        if let existing = stockViewModel { return existing }
        let vm = StockListViewModel(watchlist: watchlist)
        return vm
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("주식", systemImage: "chart.line.uptrend.xyaxis", value: 0) {
                StockListView(viewModel: viewModel, settings: settings)
            }

            Tab("포트폴리오", systemImage: "chart.pie", value: 1) {
                PortfolioView(
                    portfolioService: portfolioService,
                    authService: authService,
                    prices: viewModel.quotes,
                    krwRate: viewModel.krwRate,
                    settings: settings
                )
            }

            Tab(value: 2) {
                ChatView(chatService: chatService)
            } label: {
                Label {
                    Text("채팅")
                } icon: {
                    Image(systemName: "bubble.left.and.bubble.right")
                }
                .badge(chatService.unreadCount)
            }

            Tab("설정", systemImage: "gearshape", value: 3) {
                SettingsView(authService: authService, settings: settings)
            }
        }
        .tint(.primary)
        .onAppear {
            if stockViewModel == nil {
                stockViewModel = StockListViewModel(watchlist: watchlist)
            }
        }
        .onChange(of: portfolioService.lots) {
            // Subscribe portfolio symbols to WebSocket for real-time prices
            let symbols = portfolioService.symbols
            if !symbols.isEmpty {
                viewModel.webSocket.subscribe(symbols)
                // Fetch initial prices for portfolio symbols not in watchlist
                Task {
                    let missing = symbols.filter { viewModel.quotes[$0] == nil }
                    if !missing.isEmpty {
                        let api = StockAPIService.shared
                        if let prices = try? await api.fetchQuotes(symbols: missing) {
                            let map = Dictionary(uniqueKeysWithValues: prices.map { ($0.id, $0) })
                            viewModel.webSocket.setInitialPrices(map)
                            viewModel.quotes.merge(viewModel.webSocket.prices) { _, new in new }
                        }
                    }
                }
            }
        }
        .onChange(of: authService.user) { oldUser, newUser in
            if let newUser {
                let uid = newUser.id.uuidString
                watchlist.onUserSignIn(userId: uid)
                portfolioService.onUserSignIn(userId: uid)
            } else if oldUser != nil {
                watchlist.onUserSignOut()
                portfolioService.onUserSignOut()
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 2 {
                chatService.clearUnread()
            }
        }
        .onOpenURL { url in
            Task { await authService.handleURL(url) }
        }
    }
}

// MARK: - Settings View

private struct SettingsView: View {
    let authService: AuthService
    @Bindable var settings: AppSettings

    var body: some View {
        NavigationStack {
            List {
                ProfileView(authService: authService)

                Section("표시 설정") {
                    Picker("통화", selection: $settings.currency) {
                        ForEach(CurrencyDisplay.allCases, id: \.self) { currency in
                            Text(currency == .usd ? "달러 ($)" : "원화 (₩)").tag(currency)
                        }
                    }
                }

                Section("앱 정보") {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
