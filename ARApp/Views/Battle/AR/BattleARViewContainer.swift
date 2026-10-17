//
//  BattleARViewContainer.swift
//  ARApp
//
//  ⚠️⚠️⚠️ 開発用のコードを含む ⚠️⚠️⚠️
//  バトル画面のカメラが真っ黒になる件を確かめるためのログ（BattleARSessionLogger、BattleARLoggingView、「🔍 [BattleAR]」の print）がある。
//  真っ黒にならないことを確かめたら、BattleARSessionLogger と BattleARLoggingView を消し、
//  makeUIView の BattleARLoggingView を ARView に戻して、makeUIView・dismantleUIView の中の「🔍 [BattleAR]」の行を消す。
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

/// 【開発用】片付いたとき（メモリから消えたとき）と、大きさが変わったときにログを出す ARView
final class BattleARLoggingView: ARView {
    private static var count = 0
    private let number: Int
    private var lastSize = CGSize.zero

    required override init(frame: CGRect, cameraMode: ARView.CameraMode, automaticallyConfigureSession: Bool) {
        Self.count += 1
        number = Self.count
        super.init(frame: frame, cameraMode: cameraMode, automaticallyConfigureSession: automaticallyConfigureSession)
        print("🔍 [BattleAR] \(number) 個目の ARView を作った")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @available(*, unavailable)
    required init(frame: CGRect) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != lastSize else { return }
        lastSize = bounds.size
        print("🔍 [BattleAR] \(number) 個目の ARView の大きさ: \(bounds.size)")
    }

    deinit {
        print("🔍 [BattleAR] \(number) 個目の ARView がメモリから消えた")
    }
}

/// バトル画面の ARView を SwiftUI で使うためのラッパー
/// 担当：SwiftUI との橋渡しと、AR セッションの開始・停止（捕獲画面の ARViewContainer と同じ）
struct BattleARViewContainer: UIViewRepresentable {
    /// ARView を作るときの大きさ。表示する場所の大きさを渡す
    let initialSize: CGSize
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
    /// 相手の必殺技の予告。変わるたびに、相手のモンスターが赤く点滅する
    let danger: BattleViewModel.Danger?
    /// よけるためにスワイプした出来事。変わるたびに、自分のモンスターが横にかわす
    let myDodge: BattleViewModel.Dodge?
    /// フィーバー中は、自分のモンスターから金色の光が立ちのぼる
    let isFeverActive: Bool
    /// 勝ちが確定したら、自分のモンスターから金色の火花が散る
    let isVictory: Bool
    /// 2 体とも床に置き終わったときに呼ばれる
    let onPlaced: () -> Void

    func makeCoordinator() -> BattleARSceneController {
        BattleARSceneController(myMonster: myMonster, opponentMonster: opponentMonster, onPlaced: onPlaced)
    }

    func makeUIView(context: Context) -> ARView {
        // 大きさ 0 で作ると、SwiftUI が大きさを決める前に描き始めたときに描く場所を用意できず、
        // そのまま真っ黒になることがある（HP などの後ろに置いているので、大きさが決まるのが遅れやすい）
        // 最初から表示する場所の大きさで作る
        let arView = BattleARLoggingView(frame: CGRect(origin: .zero, size: initialSize), cameraMode: .ar, automaticallyConfigureSession: false)
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
            hitOnMe: hitOnMe,
            danger: danger,
            myDodge: myDodge,
            isFeverActive: isFeverActive,
            isVictory: isVictory
        )
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: BattleARSceneController) {
        print("🔍 [BattleAR] dismantleUIView")
        coordinator.stop()
        uiView.session.pause()
    }
}
