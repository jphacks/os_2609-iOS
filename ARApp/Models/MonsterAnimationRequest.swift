//
//  MonsterAnimationRequest.swift
//  ARApp
//

import Foundation

/// モンスターに流してほしいアニメーション。流すのは MonsterAnimator の play(_:)
/// 作るたびに id が変わるので、同じアニメーション（続けてのパンチなど）でも毎回流せる
struct MonsterAnimationRequest {
    let id = UUID()
    let animation: MonsterAnimation
    /// 流し始めるまでの待ち時間（秒）。攻撃の動きが当たるタイミングに、のけぞりを合わせるときに使う
    var delay: Double = 0
    /// true なら流し終わったあと、最後のポーズのまま止める（倒れたとき）
    var staysAtEnd = false
}
