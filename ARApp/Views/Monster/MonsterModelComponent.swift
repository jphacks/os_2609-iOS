//
//  MonsterModelComponent.swift
//  ARApp
//

import SwiftUI
import SceneKit

/// モンスターの 3D モデルを、カメラ映像なしで表示する。指で左右にドラッグするとモデルが回る
/// 捕獲したモンスターの詳細画面、バトル画面の対戦前の画面、最初にモンスターを選ぶ画面で使う。アニメーションはせず、立っている姿勢で止めて表示する
///
/// RealityKit（RealityView や ARView）ではなく SceneKit で表示する
/// ARView が動いている間や、ARView を作る直前に RealityKit の画面をもう 1 つ出すと、AR が壊れる
/// （RealityView：床に置けなくなる・タブで戻ると真っ暗になる・次に作った ARView がカメラの映像を描かず真っ黒になる、
///   ARView：置いたモンスターが描かれなくなる）
/// SceneKit は RealityKit とは別の仕組みで描くので、AR に影響しない
struct MonsterModelComponent: View {
    let monster: Monster
    /// モデルの高さ（m）。省略すると monster.size（現実の大きさ）になり、モンスターどうしの大きさの違いがわかる
    /// 一番大きいモンスター（1.8m）がちょうど収まる距離から見ているので、どれも大きく見せたいときは 2.4 くらいにする
    var height: Float? = nil
    /// 最初の向き。0 で正面（カメラの方）、正の値でカメラから見て右を向く
    var facing: Angle = .zero

    /// 指で回した角度（縦の軸まわり）
    @State private var angle = Angle.zero
    /// ドラッグを始めたときの角度。ドラッグ中はここに指の移動量を足す
    @State private var angleAtDragStart = Angle.zero

    /// 指を 1pt 動かしたときに回る角度
    private static let degreesPerPoint = 0.5

    var body: some View {
        MonsterModelSceneView(monster: monster, height: height ?? monster.size, angle: facing + angle)
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
    let height: Float
    let angle: Angle

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        // 背景は置く場所の色に任せる（詳細画面は白や黒、対戦前の画面は濃い紺）
        view.backgroundColor = .clear
        view.autoenablesDefaultLighting = true
        view.isPlaying = true

        let scene = SCNScene()
        view.scene = scene
        scene.rootNode.addChildNode(context.coordinator.turntable)
        context.coordinator.show(monster, height: height)

        // 一番大きいモンスター（高さ 1.8m）でも画面に収まる距離から見る
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(0, 0, 3)
        scene.rootNode.addChildNode(camera)
        view.pointOfView = camera

        return view
    }

    /// 指で回した角度や、出すモンスターが変わるたびに呼ばれる
    /// バトルの対戦前の画面はタブに残り続けるので、編成で選び直すと、作り直されないままモンスターだけが変わる
    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.show(monster, height: height)
        context.coordinator.turntable.eulerAngles.y = Float(angle.radians)
    }

    final class Coordinator {
        /// モデルを乗せて回す台
        let turntable = SCNNode()
        /// 今台に乗せているモデルの名前と高さ。変わったときだけ読み込み直す（USDZ の読み込みは重い）
        private var shownModelName: String?
        private var shownHeight: Float?

        /// 台に乗せるモデルを、monster のモデルにする
        func show(_ monster: Monster, height: Float) {
            guard monster.modelName != shownModelName || height != shownHeight else { return }
            shownModelName = monster.modelName
            shownHeight = height
            turntable.childNodes.forEach { $0.removeFromParentNode() }
            if let model = MonsterSceneNode.make(from: monster, height: height) {
                // 足元が原点なので、体の真ん中が画面の中心に来るように下げる
                model.position.y -= height / 2
                turntable.addChildNode(model)
            }
        }
    }
}
