//
//  MonsterAnimation.swift
//  ARApp
//

import Foundation

/// モンスターのモデルに入っているアニメーション（全モンスター共通の 14 種類）
/// USDZ にはアニメーションが 1 本の流れとして並んで入っているので、それぞれの区間を持っておき、切り出して流す
/// 区間は scripts/convert_monster_models.py が書き出したもの（単位は秒）
/// 流すのは MonsterAnimator（Views/Monster）が担当する
enum MonsterAnimation {
    /// 倒れる
    case death
    /// しゃがむ
    case duck
    /// 攻撃を受けてのけぞる
    case hitReact
    /// 立ったまま体を揺らす
    case idle
    /// 跳ぶ
    case jump
    /// 空中にいる
    case jumpIdle
    /// 着地する
    case jumpLand
    /// 首を横に振る
    case no
    /// パンチする
    case punch
    /// 走る
    case run
    /// 歩く
    case walk
    /// 手を振る
    case wave
    /// 武器を振る
    case weapon
    /// うなずく
    case yes

    var timeRange: ClosedRange<Double> {
        switch self {
        case .death: 0.0000...0.7917
        case .duck: 0.8333...2.5000
        case .hitReact: 2.5417...3.1667
        case .idle: 3.2083...4.2083
        case .jump: 4.2500...4.6250
        case .jumpIdle: 4.6667...5.1667
        case .jumpLand: 5.2083...5.5833
        case .no: 5.6250...7.2917
        case .punch: 7.3333...8.2083
        case .run: 8.2500...8.8333
        case .walk: 8.8750...9.8750
        case .wave: 9.9167...11.5833
        case .weapon: 11.6250...12.5000
        case .yes: 12.5417...14.2083
        }
    }

    /// 1 回流すのにかかる時間（秒）
    var duration: Double { timeRange.upperBound - timeRange.lowerBound }
}
