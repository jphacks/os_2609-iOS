//
//  MonsterBookView.swift
//  ARApp
//

import SwiftUI

/// 図鑑の画面。捕獲画面のメニューから開き、捕獲画面の上に重ねて出す
struct MonsterBookView: View {
    /// × が押されたときに呼ぶ
    let onClose: () -> Void

    var body: some View {
        VStack {
            MenuScreenHeaderComponent(title: "図鑑", onClose: onClose)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BattleStyle.ink)
        .environment(\.colorScheme, .dark)
    }
}

#Preview {
    MonsterBookView {}
}
