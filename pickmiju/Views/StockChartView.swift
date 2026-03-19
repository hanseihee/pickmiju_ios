import SwiftUI
import Charts

struct StockChartView: View {
    let symbol: String
    let currentPrice: Double
    let previousClose: Double

    @State private var chartData: [ChartDataPoint] = []
    @State private var selectedRange: ChartRange = .oneMonth
    @State private var isLoading = false
    @State private var selectedPoint: ChartDataPoint?
    @State private var isDragging = false

    private let api = StockAPIService.shared

    private var priceChange: Double {
        guard let first = chartData.first else { return 0 }
        return currentPrice - first.close
    }

    private var isPositive: Bool {
        priceChange >= 0
    }

    private var lineColor: Color {
        isPositive ? .green : .red
    }

    // Pre-compute min/max to prevent recalculation during scroll
    private var yMin: Double {
        chartData.map(\.close).min() ?? 0
    }

    private var yMax: Double {
        chartData.map(\.close).max() ?? 0
    }

    private var yPadding: Double {
        let range = yMax - yMin
        return range > 0 ? range * 0.05 : 1
    }

    var body: some View {
        VStack(spacing: 12) {
            // Selected point info or placeholder
            selectedPointInfo
                .frame(height: 20)

            // Chart
            chartContent
                .frame(height: 200)
                .padding(.horizontal, 4)

            // Range selector
            rangeSelector
        }
        .task {
            await loadChart()
        }
        .onChange(of: selectedRange) {
            Task { await loadChart() }
        }
    }

    // MARK: - Selected Point Info

    private var selectedPointInfo: some View {
        Group {
            if let selected = selectedPoint {
                HStack(spacing: 8) {
                    Text(formatChartPrice(selected.close))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(lineColor)
                    Text(selected.time, style: .date)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    // MARK: - Chart Content

    @ViewBuilder
    private var chartContent: some View {
        if isLoading && chartData.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if chartData.isEmpty {
            ContentUnavailableView("차트 데이터 없음", systemImage: "chart.line.downtrend.xyaxis")
        } else {
            Chart {
                ForEach(chartData) { point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Price", point.close)
                    )
                    .foregroundStyle(lineColor)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", point.time),
                        yStart: .value("Min", yMin - yPadding),
                        yEnd: .value("Price", point.close)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [lineColor.opacity(0.2), lineColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                if let selected = selectedPoint {
                    RuleMark(x: .value("Selected", selected.time))
                        .foregroundStyle(.secondary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))

                    PointMark(
                        x: .value("Time", selected.time),
                        y: .value("Price", selected.close)
                    )
                    .symbolSize(40)
                    .foregroundStyle(lineColor)
                }
            }
            // Fixed Y domain — prevents rescaling during scroll
            .chartYScale(domain: (yMin - yPadding)...(yMax + yPadding))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisValueLabel(format: xAxisFormat)
                        .font(.system(size: 9))
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) {
                    AxisValueLabel()
                        .font(.system(size: 9))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let x = value.location.x
                                    if let date: Date = proxy.value(atX: x) {
                                        selectedPoint = chartData.min(by: {
                                            abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date))
                                        })
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    selectedPoint = nil
                                }
                        )
                }
            }
        }
    }

    // MARK: - Range Selector

    private var rangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ChartRange.allCases, id: \.self) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.label)
                        .font(.system(size: 12, weight: selectedRange == range ? .bold : .regular))
                        .foregroundStyle(selectedRange == range ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(selectedRange == range ? lineColor : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private var xAxisFormat: Date.FormatStyle {
        switch selectedRange {
        case .oneDay, .fiveDay:
            return .dateTime.hour().minute()
        case .oneMonth, .threeMonth:
            return .dateTime.month(.abbreviated).day()
        default:
            return .dateTime.year().month(.abbreviated)
        }
    }

    private func formatChartPrice(_ price: Double) -> String {
        price >= 1000
            ? String(format: "%.0f", price)
            : String(format: "%.2f", price)
    }

    private func loadChart() async {
        isLoading = true
        do {
            let data = try await api.fetchChart(symbol: symbol, range: selectedRange)
            chartData = data
        } catch {
            // Keep existing data on error
        }
        isLoading = false
    }
}
