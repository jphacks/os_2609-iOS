//
//  MonsterModelComponent.swift
//  ARApp
//

import SwiftUI
import SceneKit

/// モンスターの 3D モデルを、カメラ映像なしで表示する。指で左右にドラッグするとモデルが回る
/// 捕獲したモンスターの詳細画面と、最初にモンスターを選ぶ画面で使うので Views/Monster に置いている
///
/// RealityKit（RealityView や ARView）ではなく SceneKit で表示する
/// 捕獲画面の ARView が動いている間に RealityKit の画面をもう 1 つ出すと、捕獲画面の AR が壊れる
/// （RealityView：床に置けなくなる・タブで戻ると真っ暗になる、ARView：置いたモンスターが描かれなくなる）
/// SceneKit は RealityKit とは別の仕組みで描くので、捕獲画面に影響しない
struct MonsterModelComponent: View {
    let monster: Monster

    /// 指で回した角度（縦の軸まわり）
    @State private var angle = Angle.zero
    /// ドラッグを始めたときの角度。ドラッグ中はここに指の移動量を足す
    @State private var angleAtDragStart = Angle.zero

    /// 指を 1pt 動かしたときに回る角度
    private static let degreesPerPoint = 0.5

    var body: some View {
        MonsterModelSceneView(monster: monster, angle: angle)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        angle = angleAtDragStart + .degrees(value.translation.width * Self.degreesPerPoint)
                    }
                    .onEnded { _ in
                        angleAtDragStart = angle
                    }
            )
    }
}

/// SceneKit の SCNView を SwiftUI で使うためのラッパー。モデルを 1 体だけ、回す台に乗せて表示する
private struct MonsterModelSceneView: UIViewRepresentable {
    let monster: Monster
    let angle: Angle

    /// 立っている姿勢として止めておく時刻（秒）。USDZ のアニメーションの Idle の区間（MonsterAnimation を参照）の中ほど
    /// SceneKit では区間を切り出してくり返すのが難しいので、この時刻の姿勢で止める
    /// （止めないと Death から順にすべての動きが流れ、止めて時刻を指定しないと腕を広げた姿勢のまま固まる）
    private static let idlePoseTime: TimeInterval = 3.7

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .systemBackground
        view.autoenablesDefaultLighting = true
        view.isPlaying = true

        let scene = SCNScene()
        view.scene = scene
        scene.rootNode.addChildNode(context.coordinator.turntable)
        if let model = Self.loadModel(of: monster) {
            context.coordinator.turntable.addChildNode(model)
        }

        // 一番大きいモンスター（高さ 1.8m）でも画面に収まる距離から見る
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(0, 0, 3)
        scene.rootNode.addChildNode(camera)
        view.pointOfView = camera

        return view
    }

    /// 指で回した角度が変わるたびに呼ばれる
    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.turntable.eulerAngles.y = Float(angle.radians)
    }

    final class Coordinator {
        /// モデルを乗せて回す台
        let turntable = SCNNode()
    }

    /// USDZ を読み込み、高さが monster.size になるように縮め、体の真ん中が原点に来るように置く
    private static func loadModel(of monster: Monster) -> SCNNode? {
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
            -minBounds.y * scale - monster.size / 2,
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
