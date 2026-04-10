import Foundation

struct TrumpTruth: Identifiable, Codable, Hashable {
    let id: String
    let created_at: String
    let content: String
    let content_ko: String?
    let url: String
    let media: [String]
    let replies_count: Int
    let reblogs_count: Int
    let favourites_count: Int
    let translated_at: String?
    let fetched_at: String?

    // MARK: - Custom Decoding (media null 안전 처리)

    enum CodingKeys: String, CodingKey {
        case id, created_at, content, content_ko, url, media
        case replies_count, reblogs_count, favourites_count
        case translated_at, fetched_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        created_at = try container.decode(String.self, forKey: .created_at)
        content = try container.decode(String.self, forKey: .content)
        content_ko = try container.decodeIfPresent(String.self, forKey: .content_ko)
        url = try container.decode(String.self, forKey: .url)
        media = ((try? container.decodeIfPresent([String].self, forKey: .media)) ?? [])
            .filter { !$0.isEmpty }
        replies_count = try container.decode(Int.self, forKey: .replies_count)
        reblogs_count = try container.decode(Int.self, forKey: .reblogs_count)
        favourites_count = try container.decode(Int.self, forKey: .favourites_count)
        translated_at = try container.decodeIfPresent(String.self, forKey: .translated_at)
        fetched_at = try container.decodeIfPresent(String.self, forKey: .fetched_at)
    }

    // MARK: - Computed Properties

    var displayContent: String {
        let raw = (content_ko.flatMap { $0.isEmpty ? nil : $0 }) ?? content
        return Self.stripHTML(raw)
    }

    var isRetruth: Bool {
        content.hasPrefix("RT @") || content.hasPrefix("RT: ")
    }

    var hasText: Bool {
        !content.isEmpty && !content.hasPrefix("RT: https://")
    }

    var hasMedia: Bool {
        !media.isEmpty
    }

    var relativeTime: String {
        guard let date = Self.parseDate(created_at) else { return "" }

        let seconds = Date().timeIntervalSince(date)
        guard seconds >= 0 else { return "방금 전" }

        let minutes = Int(seconds / 60)
        let hours = Int(seconds / 3600)
        let days = Int(seconds / 86400)

        if minutes < 1 { return "방금 전" }
        if minutes < 60 { return "\(minutes)분 전" }
        if hours < 24 { return "\(hours)시간 전" }
        if days < 7 { return "\(days)일 전" }

        return Self.dateFormatter.string(from: date)
    }

    // MARK: - Static Formatters (성능 최적화)

    private static let isoFormatterFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "M월 d일"
        df.locale = Locale(identifier: "ko_KR")
        return df
    }()

    private static func parseDate(_ str: String) -> Date? {
        if let d = isoFormatterFrac.date(from: str) { return d }
        if let d = isoFormatter.date(from: str) { return d }
        return nil
    }

    private static func stripHTML(_ str: String) -> String {
        str.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
