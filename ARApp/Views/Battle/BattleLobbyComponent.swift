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

    var body: some View {
        VStack(spacing: 20) {
            Text("MONSTER BATTLE")
                .font(.headline)

            // RealityKit ではなく SceneKit で表示する。理由は MonsterModelComponent に書いてある
            // 小さいモンスターも大きく見えるよう、どれも同じ高さにそろえる
            MonsterModelComponent(monster: myMonster, height: 2.4, facing: .radians(0.4))
                .frame(width: 240, height: 240)
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
