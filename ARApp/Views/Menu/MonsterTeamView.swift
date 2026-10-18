//
//  MonsterTeamView.swift
//  ARApp
//

import SwiftUI

/// 編成の画面。捕まえたモンスターから、バトルに出すモンスターを選ぶ。捕獲画面のメニューから開き、捕獲画面の上に重ねて出す
struct MonsterTeamView: View {
    /// × が押されたときに呼ぶ
    let onClose: () -> Void

    var body: some View {
        VStack {
            MenuScreenHeaderComponent(title: "編成", onClose: onClose)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BattleStyle.ink)
        .environment(\.colorScheme, .dark)
    }
}

#Preview {
    MonsterTeamView {}
}
