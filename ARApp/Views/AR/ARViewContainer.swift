//
//  ARViewContainer.swift
//  ARApp
//

import SwiftUI
import RealityKit
import ARKit

/// RealityKit の ARView（UIKit の UIView）を SwiftUI で使うためのラッパー
/// 担当：SwiftUI との橋渡しと、AR セッションの開始・停止
struct ARViewContainer: UIViewRepresentable {
    let viewModel: ARCaptureViewModel

    /// SwiftUI の Coordinator の仕組みを使って、ARSceneController を 1 つだけ作って保持する
    /// （makeUIView より先に 1 回だけ呼ばれ、ARView が存在する間ずっと同じインスタンスが使われる）
    func makeCoordinator() -> ARSceneController {
        ARSceneController(viewModel: viewModel)
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

    /// SwiftUI の状態が変わったときに呼ばれる（今は更新するものがない）
    func updateUIView(_ uiView: ARView, context: Context) {}

    /// View が画面から取り除かれるときに呼ばれる。カメラとセンサーを停止する
    static func dismantleUIView(_ uiView: ARView, coordinator: ARSceneController) {
        coordinator.stop()
        uiView.session.pause()
    }
}
