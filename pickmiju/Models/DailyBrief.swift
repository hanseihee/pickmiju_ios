import Foundation
import SwiftUI

// MARK: - Enums

enum BriefImportance: String, Hashable, Sendable {
    case high, medium, low

    var label: String {
        switch self {
        case .high: return "중요"
        case .medium: return "주의"
        case .low: return "참고"
        }
    }

    var accentColor: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .secondary
        }
    }
}

enum BriefSentiment: String, Hashable, Sendable {
    case positive, negative, neutral

    var label: String {
        switch self {
        case .positive: return "긍정"
        case .negative: return "부정"
        case .neutral: return "중립"
        }
    }

    var arrow: String {
        switch self {
        case .positive: return "▲"
        case .negative: return "▼"
        case .neutral: return "▬"
        }
    }

    var accentColor: Color {
        switch self {
        case .positive: return .green
        case .negative: return .red
        case .neutral: return .cyan
        }
    }
}

// MARK: - Nested JSONB types

struct BriefTopIssue: Codable, Hashable, Sendable {
    let title: String
    let summary: String
    let importance: String
    let relatedTickers: [String]

    var importanceLevel: BriefImportance {
        BriefImportance(rawValue: importance) ?? .medium
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        summary = try c.decode(String.self, forKey: .summary)
        importance = (try? c.decode(String.self, forKey: .importance)) ?? "medium"
        relatedTickers = (try? c.decode([String].self, forKey: .relatedTickers)) ?? []
    }
}

struct BriefTopTicker: Codable, Hashable, Sendable {
    let ticker: String
    let reason: String
    let sentiment: String

    var sentimentLevel: BriefSentiment {
        BriefSentiment(rawValue: sentiment) ?? .neutral
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ticker = try c.decode(String.self, forKey: .ticker)
        reason = (try? c.decode(String.self, forKey: .reason)) ?? ""
        sentiment = (try? c.decode(String.self, forKey: .sentiment)) ?? "neutral"
    }
}

struct BriefRisk: Codable, Hashable, Sendable {
    let title: String
    let description: String
}

struct BriefUpcomingEvent: Codable, Hashable, Sendable {
    let title: String
    let date: String
    let time: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        date = try c.decode(String.self, forKey: .date)
        time = try? c.decode(String.self, forKey: .time)
    }
}

// MARK: - Top-level record

struct DailyBrief: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let brief_date: String
    let headline: String
    let market_summary: String
    let top_issues: [BriefTopIssue]
    let top_tickers: [BriefTopTicker]
    let risks: [BriefRisk]
    let upcoming: [BriefUpcomingEvent]?
    let news_count: Int
    let news_ids: [String]?
    let ai_model: String?
    let created_at: String?

    enum CodingKeys: String, CodingKey {
        case id, brief_date, headline, market_summary
        case top_issues, top_tickers, risks, upcoming
        case news_count, news_ids, ai_model, created_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        brief_date = try c.decode(String.self, forKey: .brief_date)
        headline = try c.decode(String.self, forKey: .headline)
        market_summary = (try? c.decode(String.self, forKey: .market_summary)) ?? ""
        top_issues = (try? c.decode([BriefTopIssue].self, forKey: .top_issues)) ?? []
        top_tickers = (try? c.decode([BriefTopTicker].self, forKey: .top_tickers)) ?? []
        risks = (try? c.decode([BriefRisk].self, forKey: .risks)) ?? []
        upcoming = try? c.decode([BriefUpcomingEvent].self, forKey: .upcoming)
        news_count = (try? c.decode(Int.self, forKey: .news_count)) ?? 0
        news_ids = try? c.decode([String].self, forKey: .news_ids)
        ai_model = try? c.decode(String.self, forKey: .ai_model)
        created_at = try? c.decode(String.self, forKey: .created_at)
    }

    // MARK: - Computed display properties

    var formattedDateShort: String {
        guard let d = Self.dateInputFormatter.date(from: brief_date) else { return brief_date }
        return Self.dateShortFormatter.string(from: d)
    }

    var formattedDateLong: String {
        guard let d = Self.dateInputFormatter.date(from: brief_date) else { return brief_date }
        return Self.dateLongFormatter.string(from: d)
    }

    static func formatEventDate(_ str: String) -> String {
        guard let d = dateInputFormatter.date(from: str) else { return str }
        return eventDateFormatter.string(from: d)
    }

    private static let dateInputFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "Asia/Seoul")
        return df
    }()

    private static let dateShortFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "M월 d일 (E)"
        df.locale = Locale(identifier: "ko_KR")
        df.timeZone = TimeZone(identifier: "Asia/Seoul")
        return df
    }()

    private static let dateLongFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy년 M월 d일 EEEE"
        df.locale = Locale(identifier: "ko_KR")
        df.timeZone = TimeZone(identifier: "Asia/Seoul")
        return df
    }()

    private static let eventDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "M월 d일 (E)"
        df.locale = Locale(identifier: "ko_KR")
        df.timeZone = TimeZone(identifier: "Asia/Seoul")
        return df
    }()
}
