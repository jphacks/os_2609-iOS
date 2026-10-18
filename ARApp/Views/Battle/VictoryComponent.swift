//
//  VictoryComponent.swift
//  ARApp
//

import SwiftUI

/// 勝ちが確定したときに、大きく「VICTORY!」を出す。後ろで黄色とピンクの光の筋が回る
/// 少し見せたあと、BattleFightComponent がリザルト（BattleResultComponent）に切り替える（野生のモンスターとのバトルでは、捕獲画面に戻して詳細画面を出す）
struct VictoryComponent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false
    @State private var rotation = 0.0

    /// 光の筋の本数
    private static let rayCount = 12

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // 光の筋
            ZStack {
                ForEach(0..<Self.rayCount, id: \.self) { index in
                    Rectangle()
                        .fill(index.isMultiple(of: 2) ? BattleStyle.yellow : BattleStyle.pink)
                        .opacity(0.7)
                        .frame(width: 24, height: 260)
                        .offset(y: -130)
                        .rotationEffect(.degrees(Double(index) / Double(Self.rayCount) * 360))
                }
            }
            .rotationEffect(.degrees(rotation))
            .opacity(isShown ? 1 : 0)

            Text("VICTORY!")
                .font(BattleStyle.display(88))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(BattleStyle.yellow)
                .onBand(BattleStyle.pink, slant: 24)
                .padding(.horizontal)
                .scaleEffect(isShown || reduceMotion ? 1 : 0.2)
                .opacity(isShown ? 1 : 0)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.5)) { isShown = true }
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) { rotation = 360 }
        }
    }
}

#Preview {
    VictoryComponent()
        .background(.gray)
}
