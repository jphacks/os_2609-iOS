//
//  VictoryComponent.swift
//  ARApp
//

import SwiftUI

/// 勝ちが確定したときに、大きく「VICTORY!」を出す。後ろで金色の光の筋が回る
/// 少し見せたあと、BattleFightComponent がリザルト（BattleResultComponent）に切り替える
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
                    Capsule()
                        .fill(LinearGradient(colors: [.yellow.opacity(0.7), .clear], startPoint: .bottom, endPoint: .top))
                        .frame(width: 24, height: 260)
                        .offset(y: -130)
                        .rotationEffect(.degrees(Double(index) / Double(Self.rayCount) * 360))
                }
            }
            .rotationEffect(.degrees(rotation))
            .opacity(isShown ? 1 : 0)

            Text("VICTORY!")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .italic()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(
                    LinearGradient(colors: [.white, .yellow, .orange], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .orange, radius: 16)
                .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
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
