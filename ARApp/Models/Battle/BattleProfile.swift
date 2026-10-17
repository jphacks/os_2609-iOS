//
//  BattleProfile.swift
//  ARApp
//

import Foundation

/// モンスターごとのバトルでの強さと癖
/// 対戦では、自分のモンスターのプロフィールで自分の HP とゲージが決まる
/// HP が多いモンスターほどゲージが難しい（速い・狭い・エリアが少ない）ようにして釣り合いを取る
struct BattleProfile {
    /// 画面に出す癖の説明
    var trait = "ふつう"
    var maxHP = 600
    /// カーソルが左端から右端まで進む時間（秒）。短いほど速い
    var traverseDuration: TimeInterval = 2.0
    /// 1 ターンに並ぶ判定エリアの数。多いほど 1 ターンに与えられるダメージが増える
    var zoneCount = 3
    /// GOOD エリアの幅（ゲージ全体を 1 としたとき）
    /// zoneWidth × zoneCount は 0.86 以下にする。超えるとエリアが TimingGauge の区間に収まらず、ゲージを作るときにクラッシュする
    var zoneWidth = 0.2
}

extension BattleProfile {
    /// モンスターに合ったプロフィール。個性を付けていないモンスターはふつう
    static func of(_ monster: Monster) -> BattleProfile {
        switch monster.modelName {
        case "animal-bee":
            BattleProfile(trait: "すばやくて連撃が多い", maxHP: 500, traverseDuration: 1.4, zoneCount: 4, zoneWidth: 0.18)
        case "animal-caterpillar":
            BattleProfile(trait: "のんびりだが打たれ弱い", maxHP: 450, traverseDuration: 2.8, zoneWidth: 0.22)
        case "animal-elephant":
            BattleProfile(trait: "タフだが的が小さい", maxHP: 800, traverseDuration: 2.2, zoneWidth: 0.14)
        case "animal-crab":
            BattleProfile(trait: "かたいが連撃は少ない", maxHP: 800, zoneCount: 2)
        case "animal-lion":
            BattleProfile(trait: "連撃が多いが打たれ弱い", maxHP: 550, traverseDuration: 1.8, zoneCount: 4, zoneWidth: 0.17)
        case "animal-tiger":
            BattleProfile(trait: "すばやくて手強い", maxHP: 650, traverseDuration: 1.5, zoneCount: 4, zoneWidth: 0.17)
        case "animal-fish":
            BattleProfile(trait: "的が大きいが打たれ弱い", maxHP: 400, zoneWidth: 0.26)
        default:
            BattleProfile()
        }
    }
}
