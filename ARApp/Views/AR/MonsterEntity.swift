//
//  MonsterEntity.swift
//  ARApp
//

import RealityKit
import UIKit

/// モンスターの 3D の見た目を作る
/// 担当：見た目だけ。配置する場所やタイミングは ARSceneController が決める
enum MonsterEntity {
    /// モンスターの 3D モデル（USDZ）を読み込み、`monster.size` の大きさに合わせる
    /// ファイルの読み込みには時間がかかるので async になっている
    static func make(from monster: Monster) async -> Entity {
        do {
            let model = try await Entity(named: monster.modelName)

            // モデルは 1〜2m の大きさで作られているので、一番長い辺が size になるように縮小する
            // 原点は足元にあるので、そのまま床の上に乗る
            let longestSide = model.visualBounds(relativeTo: nil).extents.max()
            if longestSide > 0 {
                model.scale = .init(repeating: monster.size / longestSide)
            }
            return model
        } catch {
            print("モデル \(monster.modelName) を読み込めませんでした: \(error)")
            return makePlaceholder(size: monster.size)
        }
    }

    /// モデルを読み込めなかったときに代わりに出す緑の球体
    private static func makePlaceholder(size: Float) -> Entity {
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
