//
//  MonsterLineupEntity.swift
//  ARApp
//
//  ⚠️⚠️⚠️ 開発用のコード ⚠️⚠️⚠️
//  全モンスターを床に輪になって並べ、頭の上に名前と高さを出す。見た目と大きさを見比べるためのもの。
//  確認が終わったら、このファイルごと削除してよい。
//  削除するときは、ARSceneController.placeMonster(in:) の `MonsterLineupEntity.make()` を
//  `MonsterEntity.make(from: monster)` に戻し、その上の `let monster = viewModel.monster` も戻す（参照はそこ 1 か所だけ）
//

import RealityKit
import UIKit

/// 【開発用】全モンスターを輪にして並べる
enum MonsterLineupEntity {
    /// 輪の半径（m）。アンカー（最初に見つかった床）が中心になる
    private static let radius: Float = 2.5

    static func make() async -> Entity {
        let lineup = Entity()
        for (index, monster) in Monster.all.enumerated() {
            let model = await MonsterEntity.make(from: monster)
            let angle = Float(index) / Float(Monster.all.count) * 2 * .pi
            let position = SIMD3<Float>(radius * sin(angle), 0, radius * cos(angle))
            model.position = position
            // 輪の中心の方を向かせる（モデルの正面は +Z）
            model.orientation = simd_quatf(angle: atan2(-position.x, -position.z), axis: [0, 1, 0])
            lineup.addChild(model)

            let label = makeLabel("\(monster.name) \(Int((monster.size * 100).rounded()))cm")
            label.position = position + [0, monster.size + 0.08, 0]
            lineup.addChild(label)
        }
        return lineup
    }

    /// いつもカメラの方を向く文字
    private static func makeLabel(_ text: String) -> Entity {
        let mesh = MeshResource.generateText(text, extrusionDepth: 0.001, font: .boldSystemFont(ofSize: 0.05))
        let textModel = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
        // 文字の真ん中が原点に来るようにずらす
        textModel.position = -mesh.bounds.center
        let label = Entity()
        label.addChild(textModel)
        label.components.set(BillboardComponent())
        return label
    }
}
