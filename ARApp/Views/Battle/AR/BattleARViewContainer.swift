//
//  BattleARViewContainer.swift
//  ARApp
//
//  ⚠️⚠️⚠️ 開発用のコードを含む ⚠️⚠️⚠️
//  バトル画面のカメラが真っ黒になる原因を調べるためのログ（BattleARSessionLogger と「🔍 [BattleAR]」の print）がある。
//  原因がわかったら、BattleARSessionLogger と、makeUIView・dismantleUIView の中の「🔍 [BattleAR]」の行を消す。
//

import SwiftUI
import RealityKit
import ARKit

/// 【開発用】AR セッションの様子（カメラの映像が届いているか、失敗・中断したか）をログに出す
final class BattleARSessionLogger: NSObject, ARSessionDelegate {
    static let shared = BattleARSessionLogger()
    /// 届いたカメラの映像の枚数。ARView を作るたびに 0 に戻す
    var frameCount = 0

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        frameCount += 1
        if frameCount == 1 || frameCount % 300 == 0 {
            print("🔍 [BattleAR] カメラの映像が届いた（\(frameCount) 枚目）tracking=\(frame.camera.trackingState)")
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("🔍 [BattleAR] セッションが失敗した: \(error)")
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("🔍 [BattleAR] セッションが中断された")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        print("🔍 [BattleAR] セッションの中断が終わった")
    }
}

/// バトル画面の ARView を SwiftUI で使うためのラッパー
/// 担当：SwiftUI との橋渡しと、AR セッションの開始・停止（捕獲画面の ARViewContainer と同じ）
struct BattleARViewContainer: UIViewRepresentable {
    let myMonster: Monster
    let opponentMonster: Monster
    /// 立っている間にくり返すアニメーション（HP が少ないと弱った動きになる）
    let myIdle: MonsterAnimation
    let opponentIdle: MonsterAnimation
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
        print("🔍 [BattleAR] makeUIView カメラの許可=\(AVCaptureDevice.authorizationStatus(for: .video).rawValue)（3 なら許可済み）")
        BattleARSessionLogger.shared.frameCount = 0
        arView.session.delegate = BattleARSessionLogger.shared

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
            myIdle: myIdle,
            opponentIdle: opponentIdle,
            myAnimation: myAnimation,
            opponentAnimation: opponentAnimation,
            hitOnOpponent: hitOnOpponent,
            hitOnMe: hitOnMe
        )
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: BattleARSceneController) {
        print("🔍 [BattleAR] dismantleUIView")
        coordinator.stop()
        uiView.session.pause()
    }
}
