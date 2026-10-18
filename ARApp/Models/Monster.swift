//
//  Monster.swift
//  ARApp
//

import Foundation

/// AR 空間に出現するモンスターのデータ
struct Monster {
    let name: String
    /// 見た目に使う 3D モデルのファイル名（拡張子 .usdz は付けない）
    let modelName: String
    /// 体の大きさ（メートル）。モデルの高さがこの長さになる。モンスターごとに変えて、大小の違いを出す
    /// ARKit / RealityKit の 1.0 は現実の 1m
    let size: Float
    /// 通常攻撃のときに流すアニメーション
    let normalAttack: MonsterAnimation
    /// 必殺技のときに流すアニメーション
    let specialAttack: MonsterAnimation
}

extension Monster {
    /// 出現するモンスターの一覧。モデルは Resources/Models にある
    /// 攻撃のアニメーションは、何かを持っているモンスター（バニー、デーモン、キノコキング、オーク、スカルオーク）は
    /// 通常攻撃で武器を振って必殺技で跳びかかる。ほかはパンチして、必殺技で武器を振る動きをする
    static let all = [
        Monster(name: "エイリアン", modelName: "monster-alien", size: 1.25, normalAttack: .punch, specialAttack: .weapon),
        Monster(name: "バード", modelName: "monster-birb", size: 1.05, normalAttack: .punch, specialAttack: .weapon),
        Monster(name: "ブルーデーモン", modelName: "monster-blue-demon", size: 1.55, normalAttack: .punch, specialAttack: .weapon),
        Monster(name: "バニー", modelName: "monster-bunny", size: 1.05, normalAttack: .weapon, specialAttack: .jump),
        Monster(name: "カクトロ", modelName: "monster-cactoro", size: 1.25, normalAttack: .punch, specialAttack: .weapon),
        Monster(name: "デーモン", modelName: "monster-demon", size: 1.65, normalAttack: .weapon, specialAttack: .jump),
        Monster(name: "ディノ", modelName: "monster-dino", size: 1.4, normalAttack: .punch, specialAttack: .weapon),
        Monster(name: "フィッシュ", modelName: "monster-fish", size: 1.15, normalAttack: .punch, specialAttack: .weapon),
        Monster(name: "フロッグ", modelName: "monster-frog", size: 1.0, normalAttack: .punch, specialAttack: .weapon),
        Monster(name: "モンクルース", modelName: "monster-monkroose", size: 1.2, normalAttack: .punch, specialAttack: .weapon),
        Monster(name: "キノコキング", modelName: "monster-mushroom-king", size: 1.55, normalAttack: .weapon, specialAttack: .jump),
        Monster(name: "ニンジャ", modelName: "monster-ninja", size: 1.25, normalAttack: .punch, specialAttack: .weapon),
        Monster(name: "オーク", modelName: "monster-orc", size: 1.45, normalAttack: .weapon, specialAttack: .jump),
        Monster(name: "スカルオーク", modelName: "monster-orc-skull", size: 1.55, normalAttack: .weapon, specialAttack: .jump),
        Monster(name: "トライバル", modelName: "monster-tribal", size: 1.35, normalAttack: .punch, specialAttack: .weapon),
        Monster(name: "イエティ", modelName: "monster-yeti", size: 1.8, normalAttack: .punch, specialAttack: .weapon),
    ]
}

extension Monster {
    /// モデル名からモンスターを探す。対戦相手のモンスターはモデル名で送られてくる
    static func named(_ modelName: String) -> Monster? {
        all.first { $0.modelName == modelName }
    }
}
