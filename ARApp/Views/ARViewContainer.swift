//
//  ARViewContainer.swift
//  ARApp
//

import SwiftUI
import RealityKit
import ARKit
import Combine

/// RealityKit の ARView（UIKit の UIView）を SwiftUI で使うためのラッパー
struct ARViewContainer: UIViewRepresentable {
    let viewModel: ARCaptureViewModel

    /// ARView の命令的な操作を担当するオブジェクト。makeUIView より先に 1 回だけ作られる
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    /// SwiftUI がこの View を初めて表示するときに 1 回だけ呼ばれる
    func makeUIView(context: Context) -> ARView {
        // automaticallyConfigureSession: false にして、セッション設定を自分で行う
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)

        // ワールドトラッキング（端末の位置・向きを 6 自由度で追跡）を開始
        // 床にアンカーを置くため、水平面の検出を有効にする
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arView.session.run(configuration)

        context.coordinator.placeMonster(in: arView)

        return arView
    }

    /// SwiftUI の状態が変わったときに呼ばれる（Step 2 では更新するものがない）
    func updateUIView(_ uiView: ARView, context: Context) {}

    /// View が画面から取り除かれるときに呼ばれる。カメラとセンサーを停止する
    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.anchoredSubscription?.cancel()
        uiView.session.pause()
    }

    final class Coordinator {
        private let viewModel: ARCaptureViewModel
        /// アンカーの配置状態の購読。保持していないとすぐに解除される
        var anchoredSubscription: Cancellable?

        init(viewModel: ARCaptureViewModel) {
            self.viewModel = viewModel
        }

        func placeMonster(in arView: ARView) {
            // 20cm 四方以上の水平面が見つかったら、そこに自動で固定されるアンカー
            let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.2, 0.2]))
            anchor.addChild(makeMonsterEntity(for: viewModel.monster))
            arView.scene.addAnchor(anchor)

            // 平面が見つかってアンカーが固定されたら ViewModel に知らせる
            anchoredSubscription = arView.scene.subscribe(
                to: SceneEvents.AnchoredStateChanged.self,
                on: anchor
            ) { [weak self] event in
                self?.viewModel.isMonsterPlaced = event.isAnchored
            }
        }

        /// 仮のモンスター（緑の球体の体＋黒い目 2 つ）を作る
        private func makeMonsterEntity(for monster: Monster) -> Entity {
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
}
