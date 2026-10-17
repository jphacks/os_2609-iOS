//
//  DangerComponent.swift
//  ARApp
//

import SwiftUI

/// 相手の必殺技の予告。画面の縁を赤く点滅させ、「DANGER!」を出す
/// 予告している間だけ置く（BattleViewModel の incomingDanger があるとき）
struct DangerComponent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    var body: some View {
        ZStack {
            EdgeGlowComponent(color: .red, pulses: !reduceMotion, pulseDuration: 0.12)

            VStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                Text("DANGER!")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .italic()
                Text("左右にスワイプでよけろ！")
                    .font(.headline)
            }
            .foregroundStyle(.red)
            .shadow(color: .white.opacity(0.8), radius: 1)
            .shadow(color: .black.opacity(0.6), radius: 4)
            // 横から勢いよく入ってくる
            .offset(x: isShown || reduceMotion ? 0 : -400)
            .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.25, bounce: 0.3)) { isShown = true }
        }
    }
}

#Preview {
    DangerComponent()
        .background(.black)
}
