//
//  MonsterEntity.swift
//  ARApp
//

import RealityKit
import UIKit

/// モンスターの 3D の見た目を作る
/// 担当：見た目だけ。配置する場所やタイミングは ARSceneController が決める
enum MonsterEntity {
    /// 仮のモンスター（緑の球体の体＋黒い目 2 つ）を作る
    static func make(from monster: Monster) -> Entity {
        let radius = monster.size / 2

        let body = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [SimpleMaterial(color: .systemGreen, roughness: 0.4, isMetallic: false)]
        )
        // アンカーの原点は床面なので、半径ぶん持ち上げて床の上に乗せる
        body.position.y = radius

        let eyeMaterial = SimpleMaterial(color: .black, isMetallic: false)
        for x in [-radius * 0.35, radius * 0.35] {
            let eye = ModelEntity(mesh: .generateSphere(radius: radius * 0.12), materials: [eyeMaterial])
            // 体の中心から見て、少し上・手前（+z 方向）に置く
            eye.position = [x, radius * 0.3, radius * 0.9]
            body.addChild(eye)
        }

        return body
    }
}
