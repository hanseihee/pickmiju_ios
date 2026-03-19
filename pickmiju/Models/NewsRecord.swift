import Foundation

struct NewsRecord: Identifiable, Codable, Hashable {
    let id: String
    let guid: String
    let slug: String?
    let title: String
    let description: String
    let link: String
    let pub_date: String
    let creator: String
    let category: String
    let tickers: [String]
    let title_ko: String?
    let description_ko: String?
    let summary_ko: String?
    let translated_at: String?
    let created_at: String?

    var displayTitle: String {
        if let ko = title_ko, !ko.isEmpty { return ko }
        return title
    }

    var displaySummary: String {
        if let ko = summary_ko, !ko.isEmpty { return ko }
        if let ko = description_ko, !ko.isEmpty { return ko }
        return description
    }

    var relativeTime: String {
        guard let date = Self.parseDate(pub_date) else { return "" }

        let seconds = Date().timeIntervalSince(date)
        let minutes = Int(seconds / 60)
        let hours = Int(seconds / 3600)
        let days = Int(seconds / 86400)

        if minutes < 1 { return "방금 전" }
        if minutes < 60 { return "\(minutes)분 전" }
        if hours < 24 { return "\(hours)시간 전" }
        if days < 7 { return "\(days)일 전" }

        let df = DateFormatter()
        df.dateFormat = "M월 d일"
        df.locale = Locale(identifier: "ko_KR")
        return df.string(from: date)
    }

    private static func parseDate(_ str: String) -> Date? {
        // ISO 8601 with fractional seconds
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: str) { return d }

        // ISO 8601 without fractional seconds
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: str) { return d }

        // RFC 2822 (RSS pubDate format)
        let rfc = DateFormatter()
        rfc.locale = Locale(identifier: "en_US_POSIX")
        rfc.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        if let d = rfc.date(from: str) { return d }

        rfc.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return rfc.date(from: str)
    }
}
