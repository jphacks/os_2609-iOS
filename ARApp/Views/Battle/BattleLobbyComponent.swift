//
//  BattleLobbyComponent.swift
//  ARApp
//

import SwiftUI

/// 対戦前の画面。自分のモンスターを見せ、「バトルする」で対戦相手を探す
struct BattleLobbyComponent: View {
    let myMonster: Monster
    /// 対戦相手を探している
    let isSearching: Bool
    /// 相手探しをやめて、片付けが終わるのを待っている
    let isCancelling: Bool
    /// 対戦できなかったとき（通信の失敗、相手が抜けた）のメッセージ
    let errorMessage: String?
    let onFind: () -> Void
    let onCancel: () -> Void
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

            Text("「バトルする」を押した人どうしで対戦できます。画面をタップして攻撃しよう")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Spacer()

            if isSearching {
                VStack(spacing: 12) {
                    ProgressView()
                    if isCancelling {
                        Text("相手探しをやめています…")
                    } else {
                        Text("対戦相手を待っています…")
                        Button("やめる", role: .cancel, action: onCancel)
                    }
                }
            } else {
                Button(action: onFind) {
                    Text("バトルする")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}

#Preview {
    BattleLobbyComponent(
        myMonster: Monster.all[0],
        isSearching: false,
        isCancelling: false,
        errorMessage: nil,
        onFind: {},
        onCancel: {}
    )
    .padding()
}
