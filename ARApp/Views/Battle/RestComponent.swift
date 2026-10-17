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
        VStack(spacing: 2) {
            Text("へとへと…")
                .font(.system(size: 36, weight: .black, design: .rounded))
            Text("連打しすぎ！ひと休み")
                .font(.subheadline.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.red.opacity(0.75), in: Capsule())
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
