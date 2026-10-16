//
//  BattleMessageView.swift
//  ARApp
//

import SwiftUI

/// 直前の出来事を文字で伝える
struct BattleMessageView: View {
    let event: BattleViewModel.Event?
    let monsterName: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(height: 52)
    }

    private var title: String {
        switch event?.kind {
        case .hit(.perfect, _, let combo) where combo >= 2: "PERFECT! \(combo) COMBO"
        case .hit(.perfect, _, _): "PERFECT!"
        case .hit(.good, _, _): "GOOD"
        case .hit(.miss, _, _): "MISS..."
        case .counterattack(let damage): damage > 0 ? "\(monsterName)の反撃！" : "攻撃をかわした！"
        case .capture(let succeeded): succeeded ? "捕まえた！" : "捕獲失敗…"
        case nil: "攻撃方法を選ぼう"
        }
    }

    private var detail: String {
        switch event?.kind {
        case .hit(_, let damage, _): "\(damage) ダメージ"
        case .counterattack(let damage): damage > 0 ? "\(damage) ダメージを受けた" : "全部 PERFECT で反撃を回避"
        case .capture(let succeeded): succeeded ? " " : "弱らせるほど捕まえやすい"
        case nil: "STOP はエリアの数だけ押せる。外しても流れ続ける"
        }
    }

    private var color: Color {
        switch event?.kind {
        case .hit(let judgement, _, _): judgement.color
        case .counterattack(let damage): damage > 0 ? .red : .blue
        case .capture(let succeeded): succeeded ? .purple : .gray
        case nil: .primary
        }
    }
}

#Preview {
    BattleMessageView(event: nil, monsterName: "ライオン")
}
