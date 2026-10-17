//
//  BattleResultComponent.swift
//  ARApp
//

import SwiftUI

/// 勝敗を全面に出し、ロビーに戻るボタンを置く。下の画面へのタップも遮る
struct BattleResultComponent: View {
    let outcome: BattleViewModel.Outcome
    let opponentName: String
    let onBack: () -> Void

    private var accent: Color { outcome == .won ? BattleStyle.yellow : BattleStyle.red }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: outcome == .won ? "crown.fill" : "xmark.octagon.fill")
                    .font(.system(size: 64, weight: .black))
                    .foregroundStyle(accent)
                Text(outcome == .won ? "勝利！" : "敗北…")
                    .font(BattleStyle.display(64))
                    .foregroundStyle(accent)
                Text(outcome == .won ? "\(opponentName)に勝った！" : "\(opponentName)に負けてしまった…")
                    .font(.headline)
                    .foregroundStyle(.white)
                Button("ロビーに戻る", action: onBack)
                    .buttonStyle(BattleButtonStyle(color: accent))
                    .padding(.top, 8)
            }
            .padding(32)
            .background(BattleStyle.ink, in: SlantedRectangle(slant: 24))
            .overlay { SlantedRectangle(slant: 24).stroke(accent, lineWidth: 4) }
            .hardShadow(offset: 8)
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    BattleResultComponent(outcome: .won, opponentName: "ライオン") {}
}
