//
//  RestComponent.swift
//  ARApp
//

import SwiftUI

/// へとへとで休憩している間に出す「へとへと…」。連打しすぎたことがわかるようにする
/// 休憩している間だけ置く（BattleViewModel の isResting が true のとき）
struct RestComponent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDropped = false
    @State private var isTilted = false

    var body: some View {
        VStack(spacing: 0) {
            Text("へとへと…")
                .font(BattleStyle.display(40))
            Text("連打しすぎ！ひと休み")
                .font(BattleStyle.display(16))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .padding(.vertical, 8)
        .background(BattleStyle.red, in: SlantedRectangle(slant: 16))
        .overlay { SlantedRectangle(slant: 16).stroke(.black, lineWidth: 3) }
        .hardShadow()
        // 上から落ちてきて、ふらふら揺れる
        .offset(y: isDropped || reduceMotion ? 0 : -40)
        .rotationEffect(.degrees(reduceMotion ? 0 : isTilted ? -3 : 3))
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(duration: 0.3, bounce: 0.5)) { isDropped = true }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) { isTilted = true }
        }
    }
}

#Preview {
    RestComponent()
        .padding()
        .background(.black)
}
