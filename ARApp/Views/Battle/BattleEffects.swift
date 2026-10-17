//
//  BattleEffects.swift
//  ARApp
//

import SwiftUI

/// バトル画面の演出（揺れ、踏み込み、タップの波紋、画面の光）と、演出のタイミング
/// ダメージの数字は AR の中に出す（BattleARSceneController）

extension BattleViewModel.Hit {
    /// 必殺技を撃つ前の溜めの動き
    static let specialCharge = MonsterAnimation.jump
    /// 攻撃の動きを流し始めてから、相手に当たるまでの時間（秒）
    static let attackImpactTime = 0.25

    /// 攻撃を始めてから相手に当たるまでの時間（秒）。のけぞり、ダメージの数字、画面の光をこの分だけ遅らせる
    /// 必殺技は溜めの動きの分だけ遅くなる。溜めの動きは、終わる少し前（混ぜて切り替える時間）から攻撃の動きに切り替わる
    var impactDelay: Double {
        let chargeTime = isSpecial ? Self.specialCharge.duration - MonsterAnimation.transitionDuration : 0
        return chargeTime + Self.attackImpactTime
    }
}

extension View {
    /// trigger が変わるたびに左右に揺れる（攻撃を受けた演出）
    func shake(trigger: UUID?) -> some View {
        phaseAnimator([0, -12, 12, -6, 0], trigger: trigger) { content, x in
            content.offset(x: x)
        } animation: { _ in
            .linear(duration: 0.05)
        }
    }

    /// trigger が変わるたびに offset の方向へ踏み込んで戻る（攻撃する演出）
    func lunge(_ offset: CGSize, trigger: UUID?) -> some View {
        phaseAnimator([CGSize.zero, offset, .zero], trigger: trigger) { content, value in
            content.offset(value)
        } animation: { _ in
            .easeOut(duration: 0.08)
        }
    }
}

/// タップした位置に広がって消える円
struct TapRippleComponent: View {
    @State private var isExpanded = false

    var body: some View {
        Circle()
            .stroke(.secondary, lineWidth: 2)
            .frame(width: 60, height: 60)
            .scaleEffect(isExpanded ? 1 : 0.2)
            .opacity(isExpanded ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) { isExpanded = true }
            }
    }
}

/// 画面全体が一瞬光って消える（必殺技の演出）
/// delay 秒待ってから光る。必殺技の溜めの動きが終わって、攻撃が当たるタイミングに合わせる
struct FlashComponent: View {
    var delay: Double = 0
    @State private var isLit = false

    var body: some View {
        Color.yellow
            // isLit が変わったら、すぐに明るくなってから、ゆっくり消える
            .phaseAnimator([0, 0.6], trigger: isLit) { content, opacity in
                content.opacity(opacity)
            } animation: { opacity in
                opacity > 0 ? .linear(duration: 0.05) : .easeOut(duration: 0.5)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .task {
                try? await Task.sleep(for: .seconds(delay))
                isLit = true
            }
    }
}
