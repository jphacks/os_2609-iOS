//
//  BattleLobbyComponent.swift
//  ARApp
//

import SwiftUI

/// 対戦前の画面。自分のモンスターを見せ、「バトルする」で対戦相手を探す
/// 野生のモンスターとのバトルでは、相手のモンスターを横に並べ、「にげる」も置く
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
    /// 野生のモンスターとのバトルなら、相手のモンスター。ほかのプレイヤーとの対戦なら nil（相手は探すまでわからない）
    var wildMonster: Monster? = nil
    /// 「にげる」が押されたときに呼ぶ。野生のモンスターとのバトルのときだけ渡す（nil ならボタンを出さない）
    var onFlee: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Text("MONSTER BATTLE")
                .font(BattleStyle.display(44))
                .foregroundStyle(BattleStyle.yellow)
                .hardShadow(BattleStyle.pink)

            if let wildMonster {
                // 自分は左、相手は右に置き、向かい合わせる
                HStack(spacing: 4) {
                    LobbyMonsterComponent(monster: myMonster, color: BattleStyle.cyan, facing: .radians(0.6), modelSize: 150, nameSize: 20)
                    Text("VS")
                        .font(BattleStyle.display(32))
                        .foregroundStyle(BattleStyle.yellow)
                        .hardShadow(BattleStyle.pink)
                    LobbyMonsterComponent(monster: wildMonster, color: BattleStyle.pink, facing: .radians(-0.6), modelSize: 150, nameSize: 20)
                }
            } else {
                LobbyMonsterComponent(monster: myMonster, color: BattleStyle.cyan, facing: .radians(0.4), modelSize: 240, nameSize: 28)
            }

            Text(wildMonster.map { "野生の\($0.name)が勝負をしかけてきた！勝つと捕まえられます。画面をタップして攻撃しよう" }
                 ?? "マップ画面で対戦受付をオンにし、近くの相手と確認してから対戦します。")
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
            } else if let onFind {
                Button("バトルする", action: onFind)
                    .buttonStyle(BattleButtonStyle())
                if let onFlee {
                    Button("にげる", action: onFlee)
                        .buttonStyle(BattleButtonStyle(color: .white))
                }
            } else {
                Text("近くの対戦相手を探すには、マップ画面へ戻ってください")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// 対戦前の画面に出す、3D のモンスター 1 体と名前
private struct LobbyMonsterComponent: View {
    let monster: Monster
    /// 名前の帯の色
    let color: Color
    let facing: Angle
    /// 3D を出す正方形の一辺（pt）
    let modelSize: CGFloat
    let nameSize: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            // RealityKit ではなく SceneKit で表示する。理由は MonsterModelComponent に書いてある
            // 小さいモンスターも大きく見えるよう、どれも同じ高さにそろえる
            MonsterModelComponent(monster: monster, height: 2.4, facing: facing)
                .frame(width: modelSize, height: modelSize)
            Text(monster.name)
                .font(BattleStyle.display(nameSize))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 16)
                .background(color, in: SlantedRectangle())
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

#Preview("野生のモンスター") {
    BattleLobbyComponent(
        myMonster: Monster.all[0],
        isSearching: false,
        isCancelling: false,
        errorMessage: nil,
        onFind: {},
        onCancel: {},
        wildMonster: Monster.all[10],
        onFlee: {}
    )
    .padding()
    .background(BattleStyle.ink)
    .environment(\.colorScheme, .dark)
}
