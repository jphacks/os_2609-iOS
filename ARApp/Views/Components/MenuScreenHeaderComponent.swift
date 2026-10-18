//
//  MenuScreenHeaderComponent.swift
//  ARApp
//

import SwiftUI

/// メニューから開く画面（図鑑・編成）の見出し。左に題名、右に閉じるボタンを置く
struct MenuScreenHeaderComponent: View {
    let title: String
    /// × が押されたときに呼ぶ
    let onClose: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(BattleStyle.display(36))
                .foregroundStyle(.black)
                .onBand(BattleStyle.yellow)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.black)
                    .frame(width: 48, height: 48)
                    .background(.white, in: Circle())
                    .overlay { Circle().stroke(.black, lineWidth: 3) }
                    .hardShadow()
            }
            .accessibilityLabel("閉じる")
        }
    }
}

#Preview {
    MenuScreenHeaderComponent(title: "図鑑") {}
        .padding()
        .background(BattleStyle.ink)
}
