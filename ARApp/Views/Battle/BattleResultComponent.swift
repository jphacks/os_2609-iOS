//
//  BattleResultComponent.swift
//  ARApp
//

import SwiftUI

/// 対戦の結果
struct BattleResultComponent: View {
    let outcome: BattleOutcome
    let opponentName: String
    let onRestart: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol.name)
                .font(.system(size: 44))
                .foregroundStyle(symbol.color)
            Text(title)
                .font(.largeTitle.bold())
            Text(message)
            Button("ロビーに戻る", action: onRestart)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(.top, 8)
    }

    private var symbol: (name: String, color: Color) {
        switch outcome {
        case .won: ("trophy.fill", .yellow)
        case .lost: ("xmark.octagon.fill", .gray)
        case .draw: ("equal.circle.fill", .blue)
        }
    }

    private var title: String {
        switch outcome {
        case .won: "VICTORY!"
        case .lost: "DEFEAT..."
        case .draw: "DRAW"
        }
    }

    private var message: String {
        switch outcome {
        case .won: "\(opponentName)に勝った！"
        case .lost: "\(opponentName)に負けてしまった…"
        case .draw: "\(opponentName)と引き分け"
        }
    }
}

#Preview {
    BattleResultComponent(outcome: .won, opponentName: "ライオン") {}
}
