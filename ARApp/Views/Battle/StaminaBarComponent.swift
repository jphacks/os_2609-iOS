//
//  StaminaBarComponent.swift
//  ARApp
//

import SwiftUI

/// スタミナのバー。スタミナは時間とともに回復するので、表示している間は少しずつ描き直す
/// へとへとで休憩している間は赤くなり、満タンに戻っていく様子を見せる
struct StaminaBarComponent: View {
    let stamina: Stamina
    let isResting: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.05)) { context in
            StatBarComponent(
                title: isResting ? "スタミナ（へとへと…）" : "スタミナ",
                value: Int(stamina.value(at: context.date)),
                maxValue: Int(Stamina.max),
                color: isResting ? .red : .cyan
            )
        }
    }
}

#Preview {
    VStack {
        StaminaBarComponent(stamina: Stamina(), isResting: false)
        StaminaBarComponent(stamina: Stamina(), isResting: true)
    }
    .padding()
}
