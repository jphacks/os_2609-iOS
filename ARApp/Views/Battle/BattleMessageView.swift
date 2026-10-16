//
//  BattleMessageView.swift
//  ARApp
//

import SwiftUI

/// 直前の出来事を文字で伝える
struct BattleMessageView: View {
    let event: BattleViewModel.Event?
    let isWaitingForOpponent: Bool

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
        if isWaitingForOpponent { return "相手の攻撃を待っています…" }
        return switch event?.kind {
        case .hit(.perfect, _, let combo) where combo >= 2: "PERFECT! \(combo) COMBO"
        case .hit(.perfect, _, _): "PERFECT!"
        case .hit(.good, _, _): "GOOD"
        case .hit(.miss, _, _): "MISS..."
        case .turnResolved: "ターン終了"
        case nil: "攻撃方法を選ぼう"
        }
    }

    private var detail: String {
        if isWaitingForOpponent { return "2 人の攻撃がそろうとダメージが入る" }
        return switch event?.kind {
        case .hit(_, let damage, _): "\(damage) ダメージ"
        case .turnResolved(let dealt, let taken): "\(dealt) ダメージを与えて、\(taken) ダメージを受けた"
        case nil: "STOP はエリアの数だけ押せる。外しても流れ続ける"
        }
    }

    private var color: Color {
        if isWaitingForOpponent { return .secondary }
        return switch event?.kind {
        case .hit(let judgement, _, _): judgement.color
        case .turnResolved(let dealt, let taken): dealt >= taken ? .blue : .red
        case nil: .primary
        }
    }
}

#Preview {
    BattleMessageView(event: nil, isWaitingForOpponent: false)
}
