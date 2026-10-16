//
//  BattleResultView.swift
//  ARApp
//

import SwiftUI

/// バトルの結果
struct BattleResultView: View {
    let outcome: BattleOutcome
    let monsterName: String
    let onRestart: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol.name)
                .font(.system(size: 44))
                .foregroundStyle(symbol.color)
            Text(title)
                .font(.largeTitle.bold())
            Text(message)
            Button("次のモンスターとたたかう", action: onRestart)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(.top, 8)
    }

    private var symbol: (name: String, color: Color) {
        switch outcome {
        case .defeated: ("trophy.fill", .yellow)
        case .captured: ("sparkles", .purple)
        case .lost: ("xmark.octagon.fill", .gray)
        case .escaped: ("figure.run", .gray)
        }
    }

    private var title: String {
        switch outcome {
        case .defeated: "VICTORY!"
        case .captured: "GET!"
        case .lost: "DEFEAT..."
        case .escaped: "ESCAPED..."
        }
    }

    private var message: String {
        switch outcome {
        case .defeated: "\(monsterName)をたおした！"
        case .captured: "\(monsterName)を捕まえた！"
        case .lost: "\(monsterName)にやられてしまった…"
        case .escaped: "\(monsterName)は逃げてしまった…"
        }
    }
}

#Preview {
    BattleResultView(outcome: .captured, monsterName: "ライオン") {}
}
