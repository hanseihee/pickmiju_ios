import SwiftUI

/// US Market status and countdown logic (ET timezone)
struct MarketInfo {
    let label: String
    let color: Color
    let nextEventLabel: String
    let countdown: String

    /// 정규장 여부 (API 데이터 없을 때 로컬 시간 기반 fallback)
    var isRegularMarket: Bool {
        label == "정규장"
    }

    // US Market Hours (Eastern Time)
    // 프리마켓: 04:00-09:30 ET
    // 정규장:   09:30-16:00 ET
    // 애프터:   16:00-20:00 ET
    private static let preMarketStart: Double = 4.0
    private static let regularStart: Double = 9.5
    private static let regularEnd: Double = 16.0
    private static let afterHoursEnd: Double = 20.0

    // US Market Holidays 2025-2026
    private static let usHolidays: Set<String> = [
        "2025-01-01", "2025-01-20", "2025-02-17", "2025-04-18", "2025-05-26",
        "2025-06-19", "2025-07-04", "2025-09-01", "2025-11-27", "2025-12-25",
        "2026-01-01", "2026-01-19", "2026-02-16", "2026-04-03", "2026-05-25",
        "2026-06-19", "2026-07-03", "2026-09-07", "2026-11-26", "2026-12-25",
    ]

    private static var etCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }

    static func current() -> MarketInfo {
        let now = Date()
        let cal = etCalendar
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: now)

        let hours = Double(comps.hour!) + Double(comps.minute!) / 60.0
        let weekday = comps.weekday! // 1=Sun, 7=Sat
        let isWeekend = weekday == 1 || weekday == 7
        let dateStr = String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
        let isHoliday = usHolidays.contains(dateStr)

        // Weekend or holiday
        if isWeekend || isHoliday {
            let target = nextTradingDayPreMarket(after: now)
            return MarketInfo(label: "휴장", color: .secondary, nextEventLabel: "프리장",
                              countdown: formatCountdown(from: now, to: target))
        }

        // Pre-market: 4:00 AM - 9:30 AM ET
        if hours >= preMarketStart && hours < regularStart {
            let target = cal.date(bySettingHour: 9, minute: 30, second: 0, of: now)!
            return MarketInfo(label: "프리마켓", color: .cyan, nextEventLabel: "정규장",
                              countdown: formatCountdown(from: now, to: target))
        }

        // Regular: 9:30 AM - 4:00 PM ET
        if hours >= regularStart && hours < regularEnd {
            let target = cal.date(bySettingHour: 16, minute: 0, second: 0, of: now)!
            return MarketInfo(label: "정규장", color: .green, nextEventLabel: "장 마감",
                              countdown: formatCountdown(from: now, to: target))
        }

        // After-hours: 4:00 PM - 8:00 PM ET
        if hours >= regularEnd && hours < afterHoursEnd {
            let target = cal.date(bySettingHour: 20, minute: 0, second: 0, of: now)!
            return MarketInfo(label: "애프터", color: .purple, nextEventLabel: "애프터 마감",
                              countdown: formatCountdown(from: now, to: target))
        }

        // After 8:00 PM ET — next trading day
        if hours >= afterHoursEnd {
            let target = nextTradingDayPreMarket(after: now)
            return MarketInfo(label: "장마감", color: .secondary, nextEventLabel: "프리장",
                              countdown: formatCountdown(from: now, to: target))
        }

        // Before 4:00 AM ET on a trading day
        let target = cal.date(bySettingHour: 4, minute: 0, second: 0, of: now)!
        return MarketInfo(label: "장마감", color: .secondary, nextEventLabel: "프리장",
                          countdown: formatCountdown(from: now, to: target))
    }

    private static func nextTradingDayPreMarket(after date: Date) -> Date {
        let cal = etCalendar
        var next = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: date))!

        while true {
            let weekday = cal.component(.weekday, from: next)
            let comps = cal.dateComponents([.year, .month, .day], from: next)
            let dateStr = String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)

            if weekday != 1 && weekday != 7 && !usHolidays.contains(dateStr) {
                break
            }
            next = cal.date(byAdding: .day, value: 1, to: next)!
        }

        return cal.date(bySettingHour: 4, minute: 0, second: 0, of: next)!
    }

    private static func formatCountdown(from: Date, to: Date) -> String {
        let diff = to.timeIntervalSince(from)
        guard diff > 0 else { return "00:00:00" }

        let total = Int(diff)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if days > 0 {
            return String(format: "%d일 %02d:%02d:%02d", days, hours, minutes, seconds)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
