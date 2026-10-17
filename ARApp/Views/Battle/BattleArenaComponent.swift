//
//  BattleArenaComponent.swift
//  ARApp
//

import SwiftUI
import ARKit

/// 対戦中の画面の背景。カメラに映る床の上で、自分と相手のモンスターが戦う（AR）
/// AR を使えない端末（シミュレータ、プレビュー）では、モンスターを出さずにメッセージだけを出す
struct BattleArenaComponent: View {
    let myMonster: Monster
    let opponentMonster: Monster
    let myIdle: MonsterAnimation
    let opponentIdle: MonsterAnimation
    let myAnimation: MonsterAnimationRequest?
    let opponentAnimation: MonsterAnimationRequest?
    let hitOnOpponent: BattleViewModel.Hit?
    let hitOnMe: BattleViewModel.Hit?
    let danger: BattleViewModel.Danger?
    let myDodge: BattleViewModel.Dodge?
    let isFeverActive: Bool
    let isVictory: Bool
    /// 画面が表示されているか。表示されている間だけ ARView を置く
    let isVisible: Bool
    /// 床にモンスターを置き終わったか。置くまでは「床を映して」と案内する
    @State private var isPlaced = false

    var body: some View {
        ZStack {
            Color.black
            // ワールドトラッキングは実機でのみ動作する（シミュレータは非対応）
            if !ARWorldTrackingConfiguration.isSupported {
                Text("この端末では AR を使えないため、モンスターは表示されません")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if isVisible {
                // 外すと BattleARViewContainer の dismantleUIView が呼ばれ、セッションが止まる
                // ARView は最初から表示する場所の大きさで作る必要があるので、大きさが決まってから置く
                GeometryReader { proxy in
                    if proxy.size.width > 0, proxy.size.height > 0 {
                        BattleARViewContainer(
                            initialSize: proxy.size,
                            myMonster: myMonster,
                            opponentMonster: opponentMonster,
                            myIdle: myIdle,
                            opponentIdle: opponentIdle,
                            myAnimation: myAnimation,
                            opponentAnimation: opponentAnimation,
                            hitOnOpponent: hitOnOpponent,
                            hitOnMe: hitOnMe,
                            danger: danger,
                            myDodge: myDodge,
                            isFeverActive: isFeverActive,
                            isVictory: isVictory,
                            onPlaced: { isPlaced = true }
                        )
                    }
                }
                if !isPlaced {
                    Text("床を映すと、モンスターが現れます")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
        .ignoresSafeArea()
        // ARView を外すとモンスターもいなくなるので、次に表示したときは床を探すところからやり直す
        .onChange(of: isVisible) {
            if !isVisible { isPlaced = false }
        }
    }
}
