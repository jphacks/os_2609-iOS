//
//  MonsterAnimationRequest.swift
//  ARApp
//

import Foundation

/// モンスターに流してほしいアニメーション。流すのは MonsterAnimator の play(_:)
/// 作るたびに id が変わるので、同じアニメーション（続けてのパンチなど）でも毎回流せる
struct MonsterAnimationRequest {
    /// 最後のアニメーションを流し終わったあと、どうするか
    enum Ending {
        /// くり返していたアニメーション（立っているなど）に戻る
        case backToLoop
        /// 最後のポーズのまま止まる（倒れたとき）
        case staysAtEnd
        /// 最後のアニメーションをくり返す（勝って喜び続けるとき）
        case repeats
    }

    let id = UUID()
    /// 順に 1 回ずつ流すアニメーション（必殺技の溜め → 攻撃など）
    let animations: [MonsterAnimation]
    /// 流し始めるまでの待ち時間（秒）。攻撃の動きが当たるタイミングに、のけぞりを合わせるときに使う
    var delay: Double = 0
    var ending = Ending.backToLoop
}
