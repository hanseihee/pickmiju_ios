import Foundation

enum NicknameGenerator {
    private static let adjectives = [
        "용감한", "신중한", "현명한", "대담한", "침착한", "열정적인", "냉철한", "슬기로운", "지혜로운", "담대한",
        "겸손한", "인내하는", "끈기있는", "통찰력있는", "분석적인", "직관적인", "논리적인", "창의적인", "혁신적인", "도전적인",
        "행운의", "럭키한", "축복받은", "운좋은", "황금손",
        "빠른", "느긋한", "꾸준한", "안정적인", "역동적인", "민첩한", "신속한", "여유로운", "차분한", "활발한",
        "푸른", "붉은", "황금빛", "은빛", "빛나는", "반짝이는", "영롱한", "찬란한", "눈부신", "화려한",
    ]

    private static let animals = [
        "고래", "개미", "여우", "사자", "호랑이", "독수리", "상어", "늑대", "곰", "황소",
        "팬더", "코끼리", "치타", "매", "올빼미", "돌고래", "펭귄", "다람쥐", "토끼", "용",
    ]

    private static let stockTerms = [
        "투자자", "트레이더", "분석가", "홀더", "스윙러", "스캘퍼", "롱텀러", "가치투자자", "모멘텀러", "퀀트",
        "배당러", "성장투자자", "역발상러", "차트러", "펀더멘털러",
    ]

    private static let generalNouns = [
        "여행자", "탐험가", "몽상가", "철학자", "선구자", "개척자", "수호자", "관찰자", "예언자", "전략가",
        "마에스트로", "아티스트", "챔피언", "레전드", "마스터",
    ]

    private static let famousPeople = [
        "워렌 버핏", "찰리 멍거", "조지 소로스", "피터 린치", "레이 달리오",
        "짐 로저스", "칼 아이칸", "벤저민 그레이엄", "제시 리버모어", "존 보글",
        "일론 머스크", "제프 베조스", "빌 게이츠", "마크 저커버그", "팀 쿡",
        "젠슨 황", "샘 알트만", "도널드 트럼프", "재닛 옐런", "제롬 파월",
    ]

    private static let allNouns = animals + stockTerms + generalNouns

    private static let tagChars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")

    private static func generateTag() -> String {
        String((0..<4).map { _ in tagChars.randomElement()! })
    }

    static func generate() -> String {
        let tag = generateTag()

        if Double.random(in: 0..<1) < 0.6 {
            let adj = adjectives.randomElement()!
            let noun = allNouns.randomElement()!
            return "\(adj) \(noun)#\(tag)"
        } else {
            let person = famousPeople.randomElement()!
            return "\(person)#\(tag)"
        }
    }

    // MARK: - Persistence

    private static let storageKey = "chat-nickname"

    static var savedNickname: String? {
        UserDefaults.standard.string(forKey: storageKey)
    }

    static func save(_ nickname: String) {
        UserDefaults.standard.set(nickname, forKey: storageKey)
    }
}
