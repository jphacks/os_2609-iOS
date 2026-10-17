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
}

extension Monster {
    /// 出現するモンスターの一覧。モデルは Resources/Models にある
    static let all = [
        Monster(name: "エイリアン", modelName: "monster-alien", size: 0.5),
        Monster(name: "バード", modelName: "monster-birb", size: 0.35),
        Monster(name: "ブルーデーモン", modelName: "monster-blue-demon", size: 0.7),
        Monster(name: "バニー", modelName: "monster-bunny", size: 0.35),
        Monster(name: "カクトロ", modelName: "monster-cactoro", size: 0.5),
        Monster(name: "デーモン", modelName: "monster-demon", size: 0.8),
        Monster(name: "ディノ", modelName: "monster-dino", size: 0.6),
        Monster(name: "フィッシュ", modelName: "monster-fish", size: 0.4),
        Monster(name: "フロッグ", modelName: "monster-frog", size: 0.3),
        Monster(name: "モンクルース", modelName: "monster-monkroose", size: 0.45),
        Monster(name: "キノコキング", modelName: "monster-mushroom-king", size: 0.7),
        Monster(name: "ニンジャ", modelName: "monster-ninja", size: 0.5),
        Monster(name: "オーク", modelName: "monster-orc", size: 0.65),
        Monster(name: "スカルオーク", modelName: "monster-orc-skull", size: 0.7),
        Monster(name: "トライバル", modelName: "monster-tribal", size: 0.55),
        Monster(name: "イエティ", modelName: "monster-yeti", size: 0.9),
    ]
}

extension Monster {
    /// モデル名からモンスターを探す。対戦相手のモンスターはモデル名で送られてくる
    static func named(_ modelName: String) -> Monster? {
        all.first { $0.modelName == modelName }
    }
}
