//
//  BattleLobbyComponent.swift
//  ARApp
//

import SwiftUI

/// 対戦前の画面。近くの相手との対戦はマップ画面から始める
struct BattleLobbyComponent: View {
    let myMonster: Monster
    /// 対戦相手を探している
    let isSearching: Bool
    /// 相手探しをやめて、片付けが終わるのを待っている
    let isCancelling: Bool
    /// 対戦できなかったとき（通信の失敗、相手が抜けた）のメッセージ
    let errorMessage: String?
    let onFind: (() -> Void)?
    let onCancel: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Text("MONSTER BATTLE")
                .font(.headline)

            // ロビーでは SceneKit を使い、捕獲・対戦用の ARView と競合させない。
            MonsterModelComponent(monster: myMonster, height: 2.4, facing: .radians(0.4))
                .frame(width: 240, height: 240)
            Text(myMonster.name)
                .font(.title3.bold())

            Text("マップ画面で対戦受付をオンにし、近くの相手と確認してから対戦します。")
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
            } else if let onFind {
                Button(action: onFind) {
                    Text("バトルする")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Text("近くの対戦相手を探すには、マップ画面へ戻ってください")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
        onFind: nil,
        onCancel: {}
    )
    .padding()
}
