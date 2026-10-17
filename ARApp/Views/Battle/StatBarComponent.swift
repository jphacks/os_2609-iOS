//
//  StatBarComponent.swift
//  ARApp
//

import SwiftUI

/// 名前と数値付きの横棒（HP バー・必殺技ゲージ共通）
/// 減ったときは、減った分を白く残しておき、少し遅れて減らす（格闘ゲームの HP バーのように、どれだけ減ったかが見える）
struct StatBarComponent: View {
    let title: String
    let value: Int
    let maxValue: Int
    let color: Color

    /// 白く残す分の終わりの値。減ったあと、少し待ってから value に追いつく。nil のときは value と同じ
    @State private var trailValue: Int?

    /// 減ってから、白く残した分を減らし始めるまでの時間（秒）。連打している間は待ち直すので、まとめて減る
    private static let trailDelay = 0.4

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(value) / \(maxValue)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(.white.opacity(0.8))
                        .frame(width: width(of: trailValue ?? value, in: proxy.size.width))
                    Capsule()
                        .fill(color)
                        .frame(width: width(of: value, in: proxy.size.width))
                }
            }
            .frame(height: 12)
            .animation(.easeOut(duration: 0.15), value: value)
        }
        // 減ったときは、減る前の値を白く残す
        // 増えたときは白く残す分がないので、色の付いた棒と一緒に伸ばす（先に白い棒だけが伸びて見えないようにする）
        .onChange(of: value) { oldValue, newValue in
            if newValue > oldValue {
                trailValue = nil
            } else if trailValue == nil {
                trailValue = oldValue
            }
        }
        .task(id: value) {
            do {
                try await Task.sleep(for: .seconds(Self.trailDelay))
            } catch {
                return // 待っている間にまた減った
            }
            withAnimation(.easeInOut(duration: 0.4)) { trailValue = value }
        }
    }

    private func width(of value: Int, in totalWidth: CGFloat) -> CGFloat {
        totalWidth * CGFloat(value) / CGFloat(maxValue)
    }
}

#Preview {
    StatBarComponent(title: "ネコ", value: 220, maxValue: 300, color: .green)
        .padding()
}
