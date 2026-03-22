import SwiftUI
import FirebaseCore
import GoogleMobileAds

@main
struct pickmijuApp: App {
    init() {
        FirebaseApp.configure()
        MobileAds.shared.start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
