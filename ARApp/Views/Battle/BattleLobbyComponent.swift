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
                .font(BattleStyle.display(44))
                .foregroundStyle(BattleStyle.yellow)
                .hardShadow(BattleStyle.pink)

            // RealityKit ではなく SceneKit で表示する。理由は MonsterModelComponent に書いてある
            // 小さいモンスターも大きく見えるよう、どれも同じ高さにそろえる
            MonsterModelComponent(monster: myMonster, height: 2.4, facing: .radians(0.4))
                .frame(width: 240, height: 240)
            Text(myMonster.name)
                .font(BattleStyle.display(28))
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .background(BattleStyle.cyan, in: SlantedRectangle())

            Text("「バトルする」を押した人どうしで対戦できます。画面をタップして攻撃しよう")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote.bold())
                    .foregroundStyle(BattleStyle.red)
            }

            Spacer()

            if isSearching {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(BattleStyle.pink)
                    if isCancelling {
                        Text("相手探しをやめています…")
                            .font(BattleStyle.display(20))
                    } else {
                        Text("対戦相手を待っています…")
                            .font(BattleStyle.display(20))
                        Button("やめる", action: onCancel)
                            .buttonStyle(BattleButtonStyle(color: .white))
                    }
                }
            } else {
                Button("バトルする", action: onFind)
                    .buttonStyle(BattleButtonStyle())
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
