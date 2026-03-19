import SwiftUI

/// 1일 OHLC 데이터로 캔들 하나를 그리는 미니 뷰
struct MiniCandleView: View {
    let open: Double
    let high: Double
    let low: Double
    let close: Double

    private var isUp: Bool { close >= open }
    private var candleColor: Color { isUp ? .green : .red }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let range = high - low

            if range > 0 && high > 0 {
                let bodyTop = isUp ? close : open
                let bodyBottom = isUp ? open : close
                let bodyRange = max(bodyTop - bodyBottom, range * 0.02) // 최소 몸통 높이

                // 좌표 변환: 가격 → y (위가 high, 아래가 low)
                let wickTopY = 0.0
                let wickBottomY = h
                let bodyTopY = (high - bodyTop) / range * h
                let bodyBottomY = (high - (bodyTop - bodyRange)) / range * h

                // 꼬리 (심지)
                Path { path in
                    path.move(to: CGPoint(x: w / 2, y: wickTopY))
                    path.addLine(to: CGPoint(x: w / 2, y: wickBottomY))
                }
                .stroke(candleColor, lineWidth: 1)

                // 몸통
                let bodyH = max(bodyBottomY - bodyTopY, 1)
                RoundedRectangle(cornerRadius: 1)
                    .fill(candleColor)
                    .frame(width: max(w * 0.6, 4), height: bodyH)
                    .position(x: w / 2, y: bodyTopY + bodyH / 2)
            } else {
                // 데이터 없음: 가로선
                Path { path in
                    path.move(to: CGPoint(x: 2, y: h / 2))
                    path.addLine(to: CGPoint(x: w - 2, y: h / 2))
                }
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            }
        }
    }
}
