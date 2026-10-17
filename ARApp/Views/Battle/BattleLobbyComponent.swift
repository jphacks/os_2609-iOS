//
//  BattleLobbyComponent.swift
//  ARApp
//

import SwiftUI

/// 対戦相手を待っている間の画面。自分のモンスターを見せる
/// 待つのは自動（BattleViewModel が、画面を開いている間ずっと待つ）なので、ボタンは置かない
struct BattleLobbyComponent: View {
    let myMonster: Monster
    /// 通信に失敗したときのメッセージ。少しすると自動で待ち直す
    let errorMessage: String?
    /// ときどき手を振るアニメーション
    @State private var waveAnimation: MonsterAnimationRequest?

    /// 手を振る間隔（秒）
    private static let waveIntervalRange: ClosedRange<Double> = 4...8

    var body: some View {
        VStack(spacing: 20) {
            Text("MONSTER BATTLE")
                .font(.headline)

            BattleMonsterComponent(monster: myMonster, animation: waveAnimation, facing: 0.4)
                .frame(width: 240, height: 240)
                // 画面が表示されている間、ときどき手を振る
                .task {
                    while true {
                        do {
                            try await Task.sleep(for: .seconds(Double.random(in: Self.waveIntervalRange)))
                        } catch {
                            return // 画面が閉じられた
                        }
                        waveAnimation = MonsterAnimationRequest(animations: [.wave])
                    }
                }
            Text(myMonster.name)
                .font(.title3.bold())

            Text("この画面を開いている人と対戦できます。画面をタップして攻撃しよう")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("対戦相手を待っています…")
                }
            }
        }
    }
}

#Preview {
    BattleLobbyComponent(myMonster: Monster.all[0], errorMessage: nil)
        .padding()
}
