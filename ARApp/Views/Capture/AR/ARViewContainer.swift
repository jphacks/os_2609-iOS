//
//  ARViewContainer.swift
//  ARApp
//

import SwiftUI
import RealityKit
import ARKit

/// RealityKit の ARView（UIKit の UIView）を SwiftUI で使うためのラッパー
/// 担当：SwiftUI との橋渡しと、AR セッションの開始
/// AR セッションは ARCaptureView が持ち、野生のモンスターとのバトルでも同じものを使う（位置の基準と見つけた床を引き継ぐ）
/// そのため、ARView を外してもセッションは止めない。止めるのは ARCaptureView（別のタブに移ったとき）
struct ARViewContainer: UIViewRepresentable {
    let viewModel: ARCaptureViewModel
    let session: ARSession

    /// SwiftUI の Coordinator の仕組みを使って、ARSceneController を 1 つだけ作って保持する
    /// （makeUIView より先に 1 回だけ呼ばれ、ARView が存在する間ずっと同じインスタンスが使われる）
    func makeCoordinator() -> ARSceneController {
        ARSceneController(viewModel: viewModel)
    }

    /// SwiftUI がこの View を初めて表示するときに 1 回だけ呼ばれる
    func makeUIView(context: Context) -> ARView {
        // automaticallyConfigureSession: false にして、セッション設定を自分で行う
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        arView.session = session

        // モンスターのテクスチャは落ち着いた色なので、光を約 2.4 倍（2 の 1.25 乗）にして見やすくする
        // 明るすぎる・暗すぎるときはこの値で調整する（0 で元の明るさ、1 で 2 倍、1.5 で約 2.8 倍）
        arView.environment.lighting.intensityExponent = 1.25
        // AR が失敗・中断したときに開始し直すのは ARSceneController が担当する
        arView.session.delegate = context.coordinator
        Self.runSession(on: arView)

        context.coordinator.start(in: arView)

        return arView
    }

    /// AR を開始する。失敗した AR を開始し直すときは、ARSceneController が options を付けて呼ぶ
    static func runSession(on arView: ARView, options: ARSession.RunOptions = []) {
        // ワールドトラッキング（端末の位置・向きを 6 自由度で追跡）を開始
        // 床にアンカーを置くため、水平面の検出を有効にする
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        // カメラ映像から部屋の明るさや色を取り込み、モンスターを周りと同じ光で照らす
        // 自分でセッションを設定すると初期値は .none になり、暗い代わりの光で照らされる
        configuration.environmentTexturing = .automatic
        arView.session.run(configuration, options: options)
    }

    /// SwiftUI の状態が変わったときに呼ばれる
    /// ここで読んだ ViewModel のプロパティ（shownMonsters）が変わるたびに、SwiftUI がもう一度呼んでくれる
    /// shownMonsters は床の状態と出現しているモンスターから計算しているので、それらが変わったときも呼ばれる
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.sync(viewModel.shownMonsters)
    }

    /// View が画面から取り除かれるときに呼ばれる
    /// セッションは止めない。バトルに切り替えるときは、止めずにそのままバトルの ARView に渡す
    /// （止めると、再開したときに ARKit が位置を探し直し、置いた場所がずれることがある）
    static func dismantleUIView(_ uiView: ARView, coordinator: ARSceneController) {
        coordinator.stop()
    }
}
