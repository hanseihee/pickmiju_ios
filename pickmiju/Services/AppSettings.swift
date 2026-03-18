import Foundation

enum CurrencyDisplay: String, CaseIterable, Codable {
    case usd = "USD"
    case krw = "KRW"
}

@Observable
final class AppSettings {
    var currency: CurrencyDisplay {
        didSet { save() }
    }

    private let storageKey = "app-currency"

    init() {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let saved = CurrencyDisplay(rawValue: raw) {
            currency = saved
        } else {
            currency = .usd
        }
    }

    private func save() {
        UserDefaults.standard.set(currency.rawValue, forKey: storageKey)
    }

    var isKRW: Bool { currency == .krw }
}
