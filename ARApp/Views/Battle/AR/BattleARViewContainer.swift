//
//  BattleARViewContainer.swift
//  ARApp
//

import SwiftUI
import RealityKit
import ARKit

/// バトル画面の ARView を SwiftUI で使うためのラッパー
/// 担当：SwiftUI との橋渡しと、AR セッションの開始・停止（捕獲画面の ARViewContainer と同じ）
/// 野生のモンスターとのバトルでは、捕獲画面の AR セッションを引き継いで使い、外しても止めない（止めるのは ARCaptureView）
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
    /// 野生のモンスターとのバトルで、捕獲画面から引き継ぐ AR。nil なら自分で AR セッションを始める
    let arHandoff: ARHandoff?
    /// 2 体とも床に置き終わったときに呼ばれる
    let onPlaced: () -> Void

    func makeCoordinator() -> BattleARSceneController {
        BattleARSceneController(myMonster: myMonster, opponentMonster: opponentMonster, arHandoff: arHandoff, onPlaced: onPlaced)
    }

    func makeUIView(context: Context) -> ARView {
        // 大きさ 0 で作ると、SwiftUI が大きさを決める前に描き始めたときに描く場所を用意できず、
        // そのまま真っ黒になることがある（HP などの後ろに置いているので、大きさが決まるのが遅れやすい）
        // 最初から表示する場所の大きさで作る
        let arView = ARView(frame: CGRect(origin: .zero, size: initialSize), cameraMode: .ar, automaticallyConfigureSession: false)
        if let arHandoff {
            // 捕獲画面と同じセッションを使う。動いたままなので、下の run は設定を確かめるだけになる
            arView.session = arHandoff.session
        }

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
        coordinator.stop()
        // 捕獲画面から引き継いだセッションは、捕獲画面に戻ってからも使うので止めない
        if !coordinator.usesHandoff {
            uiView.session.pause()
        }
    }
}

/// 捕獲画面から引き継ぐ AR。野生のモンスターとのバトルで、捕獲画面の AR セッションをそのまま使う
/// 位置の基準と見つけた床が残っているので、床を探し直さずに、すぐにモンスターを置ける
struct ARHandoff {
    /// 捕獲画面と同じ AR セッション
    let session: ARSession
    /// 相手のモンスターを置く場所（ワールド座標、足元）。捕獲画面でそのモンスターがいた場所
    let opponentPosition: SIMD3<Float>
}
