//
//  Monster.swift
//  ARApp
//

import Foundation

/// AR 空間に出現するモンスターのデータ
struct Monster: Identifiable {
    let id = UUID()
    let name: String
    /// 見た目に使う 3D モデルのファイル名（拡張子 .usdz は付けない）
    let modelName: String
    /// 体の大きさ（メートル）。モデルの一番長い辺がこの長さになる
    /// ARKit / RealityKit の 1.0 は現実の 1m
    let size: Float
}

extension Monster {
    /// 出現するモンスターの一覧。モデルは Resources/Models にある
    static let all = [
        Monster(name: "ビーバー", modelName: "animal-beaver", size: 0.2),
        Monster(name: "ハチ", modelName: "animal-bee", size: 0.2),
        Monster(name: "ウサギ", modelName: "animal-bunny", size: 0.2),
        Monster(name: "ネコ", modelName: "animal-cat", size: 0.2),
        Monster(name: "イモムシ", modelName: "animal-caterpillar", size: 0.2),
        Monster(name: "ヒヨコ", modelName: "animal-chick", size: 0.2),
        Monster(name: "ウシ", modelName: "animal-cow", size: 0.2),
        Monster(name: "カニ", modelName: "animal-crab", size: 0.2),
        Monster(name: "シカ", modelName: "animal-deer", size: 0.2),
        Monster(name: "イヌ", modelName: "animal-dog", size: 0.2),
        Monster(name: "ゾウ", modelName: "animal-elephant", size: 0.2),
        Monster(name: "サカナ", modelName: "animal-fish", size: 0.2),
        Monster(name: "キツネ", modelName: "animal-fox", size: 0.2),
        Monster(name: "キリン", modelName: "animal-giraffe", size: 0.2),
        Monster(name: "イノシシ", modelName: "animal-hog", size: 0.2),
        Monster(name: "コアラ", modelName: "animal-koala", size: 0.2),
        Monster(name: "ライオン", modelName: "animal-lion", size: 0.2),
        Monster(name: "サル", modelName: "animal-monkey", size: 0.2),
        Monster(name: "パンダ", modelName: "animal-panda", size: 0.2),
        Monster(name: "オウム", modelName: "animal-parrot", size: 0.2),
        Monster(name: "ペンギン", modelName: "animal-penguin", size: 0.2),
        Monster(name: "ブタ", modelName: "animal-pig", size: 0.2),
        Monster(name: "シロクマ", modelName: "animal-polar", size: 0.2),
        Monster(name: "トラ", modelName: "animal-tiger", size: 0.2),
    ]
}
