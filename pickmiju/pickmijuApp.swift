import SwiftUI
import FirebaseCore

@main
struct pickmijuApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
