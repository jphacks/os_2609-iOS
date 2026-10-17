//
//  MonsterSceneNode.swift
//  ARApp
//

import SceneKit

/// モンスターの 3D モデルを SceneKit で読み込む
/// RealityKit（MonsterEntity）ではなく SceneKit を使う理由は MonsterModelComponent を参照
enum MonsterSceneNode {
    /// 立っている姿勢として止めておく時刻（秒）。USDZ のアニメーションの Idle の区間（MonsterAnimation を参照）の中ほど
    /// SceneKit では区間を切り出してくり返すのが難しいので、この時刻の姿勢で止める
    /// （止めないと Death から順にすべての動きが流れ、止めて時刻を指定しないと腕を広げた姿勢のまま固まる）
    private static let idlePoseTime: TimeInterval = 3.7

    /// USDZ を読み込み、高さが monster.size になるように縮め、足元の真ん中が原点に来るように置く
    /// 正面は +Z 方向。読み込めなかったときは nil
    static func make(from monster: Monster) -> SCNNode? {
        guard let url = Bundle.main.url(forResource: monster.modelName, withExtension: "usdz"),
              let scene = try? SCNScene(url: url) else {
            // 【開発用】原因を調べるためのログ。リリースするときに消してよい
            print("モデル \(monster.modelName) を SceneKit で読み込めませんでした")
            return nil
        }

        let model = SCNNode()
        scene.rootNode.childNodes.forEach(model.addChildNode)

        // モデルは 3〜4m の大きさで作られているので、高さが size になるように縮小する（MonsterEntity と同じ）
        let (minBounds, maxBounds) = model.boundingBox
        let height = maxBounds.y - minBounds.y
        let scale = height > 0 ? monster.size / height : 1
        model.scale = SCNVector3(scale, scale, scale)
        model.position = SCNVector3(
            -(minBounds.x + maxBounds.x) / 2 * scale,
            -minBounds.y * scale,
            -(minBounds.z + maxBounds.z) / 2 * scale
        )

        freezeInIdlePose(model)
        return model
    }

    private static func freezeInIdlePose(_ model: SCNNode) {
        model.enumerateHierarchy { node, _ in
            for key in node.animationKeys {
                guard let player = node.animationPlayer(forKey: key) else { continue }
                player.animation.timeOffset = idlePoseTime
                player.speed = 0
            }
        }
    }
}
