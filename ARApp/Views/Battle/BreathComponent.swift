//
//  BreathComponent.swift
//  ARApp
//

import SwiftUI

/// スタミナが減ってきたときに出す「ハァハァ…」。スタミナのバーは出さないので、休憩になる前にこれで気づけるようにする
/// スタミナは時間とともに回復するので、表示している間は少しずつ見直す。減っていないときは何も出さない
struct BreathComponent: View {
    let stamina: Stamina

    /// スタミナがこの割合より少なくなったら出す
    private static let threshold = 0.35

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            if stamina.value(at: context.date) < Stamina.max * Self.threshold {
                Text("ハァハァ…")
                    .font(BattleStyle.display(24))
                    .foregroundStyle(.black)
                    .onBand(BattleStyle.yellow)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    BreathComponent(stamina: Stamina())
        .padding()
        .background(.gray)
}
