//
//  BattleEffects.swift
//  ARApp
//

import SwiftUI

/// バトル画面の演出（揺れ、タップの波紋、画面の光、続けて当てた回数）と、演出のタイミング
/// 踏み込みとダメージの数字は AR の中で見せる（BattleARSceneController）

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

/// 続けて当てた回数（「5 HIT!」）。2 回目から出し、回数が増えるほど文字が大きく、10 回からは赤くなる
/// 回数が増えるたびに、一瞬大きくなって弾む
struct ComboComponent: View {
    let count: Int

    var body: some View {
        if count >= 2 {
            Text("\(count) HIT!")
                .font(.system(size: 28 + CGFloat(min(count, 20)), weight: .heavy, design: .rounded))
                .foregroundStyle(count >= 10 ? .red : .orange)
                .shadow(radius: 2)
                // 画面の右端に置くので、右端を基準に大きくする（真ん中を基準にすると、はみ出す）
                .phaseAnimator([1, 1.3], trigger: count) { content, scale in
                    content.scaleEffect(scale, anchor: .trailing)
                } animation: { _ in
                    .spring(duration: 0.15)
                }
                .allowsHitTesting(false)
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
