//
//  StarterCarouselComponent.swift
//  ARApp
//

import SwiftUI
import SceneKit

/// モンスターを 1 体ずつ円盤の足場に乗せ、輪にして並べる。frontIndex 番目のモンスターが手前に来るように輪を回す
/// 3D は SceneKit で描く（RealityKit を使わない理由は MonsterModelComponent を参照）
struct StarterCarouselComponent: View {
    let monsters: [Monster]
    /// 手前に出すモンスターの番号
    let frontIndex: Int

    var body: some View {
        StarterCarouselSceneView(monsters: monsters, frontIndex: frontIndex)
    }
}

/// SceneKit の SCNView を SwiftUI で使うためのラッパー
private struct StarterCarouselSceneView: UIViewRepresentable {
    let monsters: [Monster]
    let frontIndex: Int

    /// 輪の半径（m）
    private static let ringRadius: Float = 1.3
    /// 足場の円盤の半径と厚さ（m）
    private static let pedestalRadius: CGFloat = 0.45
    private static let pedestalHeight: CGFloat = 0.08
    /// 輪を回すのにかける時間（秒）
    private static let rotationDuration: TimeInterval = 0.4

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

        // 輪の中心は、手前のモンスターの奥にある。輪の中心が原点から ringRadius だけ奥にあるので、手前の位置が原点になる
        let ring = context.coordinator.ring
        ring.position = SCNVector3(0, 0, -Self.ringRadius)
        scene.rootNode.addChildNode(ring)

        for (index, monster) in monsters.enumerated() {
            let angle = Self.slotAngle(index, count: monsters.count)
            // 輪の上の位置に置き、外側（カメラのほう）を向かせる。モデルは +Z 方向が正面
            let slot = SCNNode()
            slot.position = SCNVector3(Self.ringRadius * sin(angle), 0, Self.ringRadius * cos(angle))
            slot.eulerAngles.y = angle
            slot.addChildNode(Self.makePedestal())
            if let model = MonsterSceneNode.make(from: monster) {
                slot.addChildNode(model)
            }
            ring.addChildNode(slot)
        }

        // 手前のモンスターの全身と、左右の 2 体が入るように、少し上から見下ろす
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(0, 1.1, 3.4)
        camera.look(at: SCNVector3(0, 0.5, -0.4))
        scene.rootNode.addChildNode(camera)
        view.pointOfView = camera

        context.coordinator.turn(to: frontIndex, count: monsters.count, animated: false)
        return view
    }

    /// 手前に出すモンスターが変わるたびに呼ばれる
    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.turn(to: frontIndex, count: monsters.count, animated: true)
    }

    /// 輪の上で index 番目のモンスターを置く角度（ラジアン）。0 番目が手前で、番号が増えるほど右回りに並ぶ
    private static func slotAngle(_ index: Int, count: Int) -> Float {
        Float(index) * 2 * .pi / Float(count)
    }

    private static func makePedestal() -> SCNNode {
        let disc = SCNCylinder(radius: pedestalRadius, height: pedestalHeight)
        disc.firstMaterial?.diffuse.contents = UIColor.systemGray4
        let node = SCNNode(geometry: disc)
        // 上の面がちょうど足元（y = 0）に来るように下げる
        node.position.y = -Float(pedestalHeight) / 2
        return node
    }

    final class Coordinator {
        /// モンスターを並べた輪。これを縦の軸まわりに回す
        let ring = SCNNode()
        /// いま手前にいるモンスターの番号
        private var currentIndex = 0
        /// 輪をこれまでに回した量（1 体ぶんを 1 とする）
        /// 端から最初に戻るときも同じ向きに回せるよう、番号ではなく回した量で角度を決める
        private var turnedSteps = 0

        func turn(to index: Int, count: Int, animated: Bool) {
            guard count > 0, index != currentIndex || !animated else { return }
            // 近いほうの向きに回す（3 体なら、0 → 2 は 2 つ進めるより 1 つ戻るほうが近い）
            var delta = (index - currentIndex) % count
            if delta < 0 { delta += count }
            if delta > count / 2 { delta -= count }
            currentIndex = index
            turnedSteps += delta

            SCNTransaction.begin()
            SCNTransaction.animationDuration = animated ? StarterCarouselSceneView.rotationDuration : 0
            ring.eulerAngles.y = -Float(turnedSteps) * 2 * .pi / Float(count)
            SCNTransaction.commit()
        }
    }
}
