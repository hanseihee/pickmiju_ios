import Foundation
import SwiftUI

enum CurrencyDisplay: String, CaseIterable, Codable {
    case usd = "USD"
    case krw = "KRW"
}

enum AppTheme: String, CaseIterable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var label: String {
        switch self {
        case .system: return "시스템"
        case .light: return "라이트"
        case .dark: return "다크"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Observable
final class AppSettings {
    var currency: CurrencyDisplay {
        didSet { saveCurrency() }
    }

    var theme: AppTheme {
        didSet { saveTheme() }
    }

    private let currencyKey = "app-currency"
    private let themeKey = "app-theme"

    init() {
        if let raw = UserDefaults.standard.string(forKey: currencyKey),
           let saved = CurrencyDisplay(rawValue: raw) {
            currency = saved
        } else {
            currency = .usd
        }

        if let raw = UserDefaults.standard.string(forKey: themeKey),
           let saved = AppTheme(rawValue: raw) {
            theme = saved
        } else {
            theme = .system
        }
    }

    private func saveCurrency() {
        UserDefaults.standard.set(currency.rawValue, forKey: currencyKey)
    }

    private func saveTheme() {
        UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
    }

    var isKRW: Bool { currency == .krw }
}
