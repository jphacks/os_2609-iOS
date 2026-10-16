//
//  TimingGaugeView.swift
//  ARApp
//

import SwiftUI

/// 横一直線のゲージ、判定エリア、カーソル。位置はすべて 0 が左端、1 が右端
struct TimingGaugeView: View {
    let position: Double
    let zones: [TimingZone]
    /// エリアごとの判定。当てたエリアは結果の色になる
    let results: [TimingJudgement?]

    private let cursorWidth: CGFloat = 20

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let x = { (value: Double) in xPosition(of: value, totalWidth: geometry.size.width) }

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.gray.opacity(0.5))
                    .frame(height: 8)
                    .padding(.horizontal, cursorWidth / 2)

                ForEach(zones.indices, id: \.self) { index in
                    let zone = zones[index]
                    let result = index < results.count ? results[index] : nil
                    let color = result?.color ?? .green

                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.15))
                        .strokeBorder(color, lineWidth: 3)
                        .frame(width: x(zone.goodRange.upperBound) - x(zone.goodRange.lowerBound), height: height)
                        .offset(x: x(zone.goodRange.lowerBound))

                    Rectangle()
                        .fill(color.opacity(0.4))
                        .frame(width: x(zone.perfectRange.upperBound) - x(zone.perfectRange.lowerBound), height: height - 6)
                        .offset(x: x(zone.perfectRange.lowerBound))
                }

                RoundedRectangle(cornerRadius: 6)
                    .fill(.blue)
                    .frame(width: cursorWidth, height: height * 0.75)
                    .offset(x: x(position) - cursorWidth / 2)
            }
            .frame(maxHeight: .infinity)
        }
    }

    /// ゲージ上の位置（0〜1）を、左端からの x 座標に変換する
    /// カーソルの中心が線の端から端まで動くように、カーソルの幅ぶん内側に寄せる
    private func xPosition(of value: Double, totalWidth: CGFloat) -> CGFloat {
        cursorWidth / 2 + (totalWidth - cursorWidth) * value
    }
}

#Preview {
    TimingGaugeView(
        position: 0.4,
        zones: [TimingZone(center: 0.3, width: 0.2), TimingZone(center: 0.7, width: 0.2)],
        results: [.perfect, nil]
    )
    .frame(height: 70)
    .padding()
}
