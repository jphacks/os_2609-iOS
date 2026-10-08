//
//  ARViewContainer.swift
//  ARApp
//

import SwiftUI
import RealityKit
import ARKit

/// RealityKit の ARView（UIKit の UIView）を SwiftUI で使うためのラッパー
struct ARViewContainer: UIViewRepresentable {

    /// SwiftUI がこの View を初めて表示するときに 1 回だけ呼ばれる
    func makeUIView(context: Context) -> ARView {
        // automaticallyConfigureSession: false にして、セッション設定を自分で行う
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)

        // ワールドトラッキング（端末の位置・向きを 6 自由度で追跡）を開始
        let configuration = ARWorldTrackingConfiguration()
        arView.session.run(configuration)

        return arView
    }

    /// SwiftUI の状態が変わったときに呼ばれる（Step 1 では更新するものがない）
    func updateUIView(_ uiView: ARView, context: Context) {}

    /// View が画面から取り除かれるときに呼ばれる。カメラとセンサーを停止する
    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        uiView.session.pause()
    }
}
