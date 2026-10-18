//
//  MonsterThumbnail.swift
//  ARApp
//

import SceneKit
import UIKit

/// モンスターの 3D モデルを、正面から見た画像にする（図鑑や編成のマスに使う）
/// SceneKit で描くので、捕獲画面の ARView（RealityKit）とはぶつからない
/// 1 回描いた画像は覚えておく
///
/// SceneKit の読み込みは、いくつも同時に行うと止まることがある（メインスレッドの外で並行して描いたら、画面ごと固まった）
/// そのため、メインスレッドで 1 体ずつ順番に描き、1 体ごとに画面の更新やタップに順番を譲る
enum MonsterThumbnail {
    /// 描く画像の大きさ（pt）
    private static let imageSize = CGSize(width: 200, height: 200)
    /// モデルの周りに空ける余白（モデルの大きさに対する割合）
    private static let margin: Float = 0.08
    /// 1 体描くたびに待つ時間。この間に画面を更新し、タップを受け付ける
    private static let pauseBetweenRenders: Duration = .milliseconds(30)

    /// 描いた画像。モデル名ごとに覚えておく
    private static var cache: [String: UIImage] = [:]
    /// 読み込めなかったモデル名。何度描いても失敗するので、2 回目からは描かずに nil を返す
    private static var failedModelNames: Set<String> = []
    /// 最後に頼まれた画像を描くタスク。次に頼まれた画像は、これが終わってから描く
    private static var lastRender: Task<Void, Never>?

    /// モンスターの画像。初めてなら描き、2 回目からは覚えている画像を返す
    /// 読み込めなかったときと、描く前に頼んだ側がキャンセルされたとき（図鑑を閉じたなど）は nil
    /// 背景は透明。まだ捕まえていないモンスターは、この画像を 1 色で塗ってシルエットにする
    static func image(for monster: Monster) async -> UIImage? {
        if let cached = cache[monster.modelName] {
            return cached
        }
        guard !failedModelNames.contains(monster.modelName) else { return nil }

        let previous = lastRender
        let render = Task { () -> UIImage? in
            await previous?.value
            if let cached = cache[monster.modelName] {
                return cached
            }
            try? await Task.sleep(for: pauseBetweenRenders)
            // 待っている間に頼んだ側がいなくなっていたら描かない。描くとメインスレッドが止まり、戻った AR がカクつく
            guard !Task.isCancelled else { return nil }
            let image = Self.render(monster)
            if let image {
                cache[monster.modelName] = image
            } else {
                failedModelNames.insert(monster.modelName)
            }
            return image
        }
        lastRender = Task { _ = await render.value }
        // 描くタスクは頼んだ側とは別に動くので、頼んだ側がキャンセルされたら、描くタスクにも伝える
        return await withTaskCancellationHandler {
            await render.value
        } onCancel: {
            render.cancel()
        }
    }

    private static func render(_ monster: Monster) -> UIImage? {
        guard let model = MonsterSceneNode.make(from: monster, height: 1) else { return nil }
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        scene.rootNode.addChildNode(model)

        // モデル全体がちょうど収まるように、遠近のないカメラで正面から写す（翼や武器が横に広いモンスターもある）
        let (minBounds, maxBounds) = scene.rootNode.boundingBox
        let width = maxBounds.x - minBounds.x
        let height = maxBounds.y - minBounds.y
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = Double(max(width, height) / 2 * (1 + margin * 2))
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3((minBounds.x + maxBounds.x) / 2, (minBounds.y + maxBounds.y) / 2, 5)
        scene.rootNode.addChildNode(cameraNode)

        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = scene
        renderer.pointOfView = cameraNode
        renderer.autoenablesDefaultLighting = true
        return renderer.snapshot(atTime: 0, with: imageSize, antialiasingMode: .multisampling4X)
    }
}
