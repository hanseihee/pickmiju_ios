import SwiftUI
import Auth

struct MainTabView: View {
    @State private var watchlist = WatchlistStore()
    @State private var authService = AuthService()
    @State private var chatService = ChatService()
    @State private var portfolioService = PortfolioService()
    @State private var settings = AppSettings()
    @State private var selectedTab = 0
    @Environment(\.scenePhase) private var scenePhase

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
                    watchlistOrder: watchlist.tickers,
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

            Tab("뉴스", systemImage: "newspaper", value: 3) {
                NewsListView()
            }

            Tab("설정", systemImage: "gearshape", value: 4) {
                SettingsView(authService: authService, settings: settings)
            }
        }
        .tint(.primary)
        .preferredColorScheme(settings.theme.colorScheme)
        .onAppear {
            if stockViewModel == nil {
                stockViewModel = StockListViewModel(watchlist: watchlist)
            }
        }
        .onChange(of: portfolioService.lots) {
            // 포트폴리오 심볼을 ViewModel에 동기화하고 전체 리로드
            viewModel.portfolioSymbols = portfolioService.symbols
            viewModel.reloadAllSymbols()
        }
        .onChange(of: authService.user) { oldUser, newUser in
            if let newUser {
                let uid = newUser.id.uuidString
                watchlist.onUserSignIn(userId: uid)
                portfolioService.onUserSignIn(userId: uid)
            } else if oldUser != nil {
                watchlist.onUserSignOut()
                portfolioService.onUserSignOut()
                viewModel.portfolioSymbols = []
            }
        }
        .onChange(of: watchlist.tickers) { oldTickers, newTickers in
            // 관심종목 변경 시 전체 리로드 (포트폴리오 심볼 포함)
            if Set(oldTickers) != Set(newTickers) {
                viewModel.reloadAllSymbols()
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 2 {
                chatService.clearUnread()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                chatService.onEnterForeground()
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

                    Picker("테마", selection: $settings.theme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.label).tag(theme)
                        }
                    }
                }

                Section("앱 정보") {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("빌드")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
