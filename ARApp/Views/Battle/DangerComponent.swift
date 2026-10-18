//
//  DangerComponent.swift
//  ARApp
//

import SwiftUI

/// 相手の必殺技の予告。画面の縁を赤く点滅させ、斜めの赤い帯に「DANGER!」を出す
/// 予告している間だけ置く（BattleViewModel の incomingDanger があるとき）
struct DangerComponent: View {
    /// スワイプしたが、休憩中やスタミナが足りなくてよけられなかったか
    let isDodgeFailed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    var body: some View {
        ZStack {
            EdgeGlowComponent(color: BattleStyle.red, pulses: !reduceMotion, pulseDuration: 0.12)

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(BattleStyle.yellow)
                    Text("DANGER!")
                        .font(BattleStyle.display(64))
                        .foregroundStyle(.white)
                }
                Text(isDodgeFailed ? "スタミナが足りなくて、よけられない！" : "左右にスワイプでよけろ！")
                    .font(BattleStyle.display(20))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                    .background(BattleStyle.yellow)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(BattleStyle.red)
            .overlay(alignment: .top) { Rectangle().fill(BattleStyle.yellow).frame(height: 4) }
            .overlay(alignment: .bottom) { Rectangle().fill(BattleStyle.yellow).frame(height: 4) }
            .rotationEffect(.degrees(-6))
            .hardShadow(offset: 6)
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
    VStack(spacing: 40) {
        DangerComponent(isDodgeFailed: false)
        DangerComponent(isDodgeFailed: true)
    }
    .background(.black)
}
