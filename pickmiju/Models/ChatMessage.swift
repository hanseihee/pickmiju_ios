import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    let nickname: String
    let message: String
    let created_at: String
    let user_hash: String?

    var date: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: created_at)
    }

    var timeString: String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    var isFromSameUser: Bool {
        guard let hash = user_hash else { return false }
        return hash == DeviceIdentity.deviceId
    }
}

// MARK: - Device Identity

enum DeviceIdentity {
    private static let storageKey = "chat-device-id"

    static var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: storageKey) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: storageKey)
        return newId
    }
}
