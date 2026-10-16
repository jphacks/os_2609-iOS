//
//  BattleProfile.swift
//  ARApp
//

import Foundation

/// モンスターごとのバトルでの強さと癖
struct BattleProfile {
    /// 画面に出す癖の説明
    var trait = "ふつう"
    var maxHP = 600
    /// カーソルが左端から右端まで進む時間（秒）。短いほど速い
    var traverseDuration: TimeInterval = 2.0
    /// 1 ターンに並ぶ判定エリアの数
    var zoneCount = 3
    /// GOOD エリアの幅（ゲージ全体を 1 としたとき）
    var zoneWidth = 0.2
    /// 反撃の強さ。MISS で終わったターンにプレイヤーが受けるダメージ
    var attackPower = 30
    /// このターン数のうちに決着しないと逃げられる
    var turnLimit = 6
}

extension BattleProfile {
    /// モンスターに合ったプロフィール。個性を付けていないモンスターはふつう
    static func of(_ monster: Monster) -> BattleProfile {
        switch monster.modelName {
        case "animal-bee":
            BattleProfile(trait: "すばやい", maxHP: 400, traverseDuration: 1.3, attackPower: 20)
        case "animal-caterpillar":
            BattleProfile(trait: "のんびり", maxHP: 400, traverseDuration: 2.8, attackPower: 15)
        case "animal-elephant":
            BattleProfile(trait: "タフだが的が小さい", maxHP: 900, traverseDuration: 2.6, zoneWidth: 0.14, attackPower: 45)
        case "animal-crab":
            BattleProfile(trait: "かたいが連撃は少ない", maxHP: 800, zoneCount: 2, attackPower: 35)
        case "animal-lion":
            BattleProfile(trait: "連撃が多い", maxHP: 700, traverseDuration: 1.8, zoneCount: 4, zoneWidth: 0.17, attackPower: 40)
        case "animal-tiger":
            BattleProfile(trait: "すばやくて手強い", maxHP: 800, traverseDuration: 1.5, zoneCount: 4, zoneWidth: 0.17, attackPower: 45, turnLimit: 7)
        case "animal-fish":
            BattleProfile(trait: "すぐ逃げる", maxHP: 400, turnLimit: 3)
        default:
            BattleProfile()
        }
    }
}
