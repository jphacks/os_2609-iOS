//
//  PlaceholderMonsterEntity.swift
//  ARApp
//
//  ⚠️⚠️⚠️ テスト用のコード ⚠️⚠️⚠️
//  3D モデル（USDZ）を読み込めなかったときに、代わりに出す緑の球体。
//  モデルが表示されることを確認できたら、このファイルごと削除してよい。
//  削除するときは、MonsterEntity.swift の catch 内の
//  `PlaceholderMonsterEntity.make(size:)` を `Entity()` に置き換える（参照はそこ 1 か所だけ）。
//

import RealityKit
import UIKit

/// 【テスト用】モデルの代わりに出す緑の球体
enum PlaceholderMonsterEntity {
    static func make(size: Float) -> Entity {
        let radius = size / 2
        let body = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [SimpleMaterial(color: .systemGreen, roughness: 0.4, isMetallic: false)]
        )
        // アンカーの原点は床面なので、半径ぶん持ち上げて床の上に乗せる
        body.position.y = radius
        return body
    }
}
