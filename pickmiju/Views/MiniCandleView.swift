import SwiftUI

/// 1일 OHLC 데이터로 캔들 하나를 그리는 미니 뷰
struct MiniCandleView: View {
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let previousClose: Double

    // 전일 종가 대비 색상 (변동% 배지와 동일 기준)
    private var isUp: Bool { close >= previousClose }
    private var candleColor: Color { isUp ? .green : .red }

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let range = high - low

            guard range > 0, high > 0 else {
                // 데이터 없음: 가로선
                var line = Path()
                line.move(to: CGPoint(x: 2, y: h / 2))
                line.addLine(to: CGPoint(x: w - 2, y: h / 2))
                context.stroke(line, with: .color(.secondary.opacity(0.3)), lineWidth: 1)
                return
            }

            let bodyTop = max(open, close)
            let bodyBottom = min(open, close)
            let bodyRange = max(bodyTop - bodyBottom, range * 0.02)

            let bodyTopY = (high - bodyTop) / range * h
            let bodyBottomY = bodyTopY + bodyRange / range * h
            let bodyH = max(bodyBottomY - bodyTopY, 1)

            let centerX = w / 2
            let candleW = max(w * 0.5, 4)

            // 꼬리 (심지): high ~ low
            var wick = Path()
            wick.move(to: CGPoint(x: centerX, y: 0))
            wick.addLine(to: CGPoint(x: centerX, y: h))
            context.stroke(wick, with: .color(candleColor), lineWidth: 1)

            // 몸통: open ~ close
            let bodyRect = CGRect(
                x: centerX - candleW / 2,
                y: bodyTopY,
                width: candleW,
                height: bodyH
            )
            context.fill(
                Path(roundedRect: bodyRect, cornerRadius: 1),
                with: .color(candleColor)
            )
        }
    }
}
