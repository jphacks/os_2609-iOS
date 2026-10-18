//
//  FeverComponent.swift
//  ARApp
//

import SwiftUI

/// フィーバー中の演出。画面の縁を金色に光らせ、始まったときに大きく「FEVER!」を出す
/// フィーバーの間だけ置く。置かれたときに「FEVER!」が出て、少しすると消える（縁の光は残る）
struct FeverComponent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 「FEVER!」の出方。0：出る前（大きく透明）、1：出ている、2：消えた（少し大きく透明）
    @State private var bannerPhase = 0

    /// 「FEVER!」を出しておく時間（秒）
    private static let bannerDuration = 0.9

    var body: some View {
        ZStack {
            EdgeGlowComponent(color: BattleStyle.yellow, pulses: !reduceMotion, pulseDuration: 0.35)

            Text("FEVER!")
                .font(BattleStyle.display(96))
                .foregroundStyle(BattleStyle.yellow)
                .onBand(BattleStyle.pink, slant: 24)
                .scaleEffect(reduceMotion ? 1 : [2.5, 1, 1.4][bannerPhase])
                .opacity(bannerPhase == 1 ? 1 : 0)
                .allowsHitTesting(false)
        }
        .task {
            withAnimation(.spring(duration: 0.35, bounce: 0.5)) { bannerPhase = 1 }
            try? await Task.sleep(for: .seconds(Self.bannerDuration))
            withAnimation(.easeIn(duration: 0.25)) { bannerPhase = 2 }
        }
    }
}

#Preview {
    FeverComponent()
        .background(.black)
}
