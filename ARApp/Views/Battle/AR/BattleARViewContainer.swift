//
//  BattleARViewContainer.swift
//  ARApp
//

import SwiftUI
import RealityKit
import ARKit

/// バトル画面の ARView を SwiftUI で使うためのラッパー
/// 担当：SwiftUI との橋渡しと、AR セッションの開始・停止（捕獲画面の ARViewContainer と同じ）
struct BattleARViewContainer: UIViewRepresentable {
    let myMonster: Monster
    let opponentMonster: Monster
    let myAnimation: MonsterAnimationRequest?
    let opponentAnimation: MonsterAnimationRequest?
    /// 攻撃が当たった出来事。変わるたびに、攻撃した側のモンスターが踏み込み、受けた側の頭の上にダメージの数字が出る
    let hitOnOpponent: BattleViewModel.Hit?
    let hitOnMe: BattleViewModel.Hit?
    /// 2 体とも床に置き終わったときに呼ばれる
    let onPlaced: () -> Void

    func makeCoordinator() -> BattleARSceneController {
        BattleARSceneController(myMonster: myMonster, opponentMonster: opponentMonster, onPlaced: onPlaced)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)

        // 床にモンスターを置くため、水平面の検出を有効にする
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        // 明るさは捕獲画面（ARViewContainer）と同じにする。理由はそちらに書いてある
        configuration.environmentTexturing = .automatic
        arView.environment.lighting.intensityExponent = 1.25
        arView.session.run(configuration)

        context.coordinator.start(in: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.update(
            myAnimation: myAnimation,
            opponentAnimation: opponentAnimation,
            hitOnOpponent: hitOnOpponent,
            hitOnMe: hitOnMe
        )
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: BattleARSceneController) {
        coordinator.stop()
        uiView.session.pause()
    }
}
