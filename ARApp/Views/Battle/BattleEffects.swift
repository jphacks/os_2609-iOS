//
//  BattleEffects.swift
//  ARApp
//

import SwiftUI

/// バトル画面の演出（揺れ、タップの波紋、画面の光、画面の縁の光、続けて当てた回数）と、演出のタイミング
/// フィーバー・相手の必殺技の予告・勝利の演出は、それぞれ FeverComponent、DangerComponent、VictoryComponent にある
/// 踏み込み、モンスターが光る演出、火花、ダメージの数字は AR の中で見せる（BattleARSceneController）
/// 当たったときの音は BattleSoundPlayer が鳴らす

extension BattleViewModel.Hit {
    /// 必殺技を撃ってから、相手が受けたかよけたかが決まるまでの溜めの動き。跳んで、空中で待つ
    static let specialCharge = MonsterAnimationRequest(animations: [.jump, .jumpIdle], ending: .repeats)
    /// 通常攻撃で、タップしてから相手に当たるまでの時間（秒）
    /// タップしてすぐに当たったと感じられるよう、攻撃の動きを待たずに、踏み込みが届くころに当てる
    static let normalImpactTime = 0.1
    /// 必殺技で、攻撃の動きを流し始めてから相手に当たるまでの時間（秒）
    static let specialImpactTime = 0.25
    /// とどめが当たった瞬間に、2 体とも動きを止める時間（秒）（ヒットストップ）
    static let hitStopDuration = 0.2
    /// とどめを刺されて倒れる動きの速さ（スローモーション）
    static let finishingDeathSpeed = 0.5

    /// 攻撃を始めてから相手に当たるまでの時間（秒）。のけぞり、ダメージの数字、光、音、振動をこの分だけ遅らせる
    /// 必殺技の溜めは結果が決まる前に流し終えているので、ここには含めない
    var impactDelay: Double {
        isSpecial ? Self.specialImpactTime : Self.normalImpactTime
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

/// 画面全体が一瞬光って消える（必殺技ととどめの演出）
/// delay 秒待ってから光る。必殺技の溜めの動きが終わって、攻撃が当たるタイミングに合わせる
/// 視差効果を減らす設定のときは、弱く光る
struct FlashComponent: View {
    var color = Color.yellow
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLit = false

    var body: some View {
        color
            // isLit が変わったら、すぐに明るくなってから、ゆっくり消える
            .phaseAnimator([0, reduceMotion ? 0.25 : 0.6], trigger: isLit) { content, opacity in
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

/// 画面の縁が光る（フィーバー中は金色、相手の必殺技の予告では赤）
/// pulses が true なら、明るくなったり暗くなったりをくり返す。視差効果を減らす設定のときは false にする
struct EdgeGlowComponent: View {
    let color: Color
    let pulses: Bool
    /// 1 回明るくなるのにかける時間（秒）
    var pulseDuration = 0.5
    @State private var isBright = false

    var body: some View {
        ZStack {
            Rectangle()
                .strokeBorder(color, lineWidth: 28)
                .blur(radius: 24)
            Rectangle()
                .strokeBorder(color.opacity(0.8), lineWidth: 4)
                .blur(radius: 2)
        }
        .opacity(pulses ? (isBright ? 1 : 0.35) : 0.8)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            guard pulses else { return }
            withAnimation(.easeInOut(duration: pulseDuration).repeatForever()) { isBright = true }
        }
    }
}
