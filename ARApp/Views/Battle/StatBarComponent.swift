//
//  StatBarComponent.swift
//  ARApp
//

import SwiftUI

/// 名前と数値付きの横棒（HP バー・ゲージ共通）。格闘ゲームのように、斜めに切った形で 10 等分の目盛りを付ける
/// 減ったときは、減った分を白く残しておき、少し遅れて減らす（どれだけ減ったかが見える）
struct StatBarComponent: View {
    let title: String
    let value: Int
    let maxValue: Int
    let color: Color

    /// 白く残す分の終わりの値。減ったあと、少し待ってから value に追いつく。nil のときは value と同じ
    @State private var trailValue: Int?

    /// 減ってから、白く残した分を減らし始めるまでの時間（秒）。連打している間は待ち直すので、まとめて減る
    private static let trailDelay = 0.4
    /// 目盛りで区切る数
    private static let segmentCount = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(BattleStyle.display(17))
                    .foregroundStyle(color)
                Spacer()
                Text("\(value)")
                    .font(BattleStyle.display(17).monospacedDigit())
                    .foregroundStyle(.white)
                Text("/ \(maxValue)")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.white.opacity(0.6))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.black)
                    Rectangle()
                        .fill(.white)
                        .frame(width: width(of: trailValue ?? value, in: proxy.size.width))
                    Rectangle()
                        .fill(color)
                        .frame(width: width(of: value, in: proxy.size.width))
                    // 目盛り
                    HStack(spacing: 0) {
                        ForEach(0..<Self.segmentCount, id: \.self) { index in
                            Spacer(minLength: 0)
                            if index < Self.segmentCount - 1 {
                                Rectangle().fill(.black.opacity(0.5)).frame(width: 2)
                            }
                        }
                    }
                }
                .clipShape(SlantedRectangle(slant: 6))
                .overlay { SlantedRectangle(slant: 6).stroke(.white, lineWidth: 1.5) }
            }
            .frame(height: 14)
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
    VStack {
        StatBarComponent(title: "ネコ", value: 220, maxValue: 300, color: BattleStyle.lime)
        StatBarComponent(title: "スタミナ", value: 40, maxValue: 100, color: BattleStyle.cyan)
    }
    .padding()
    .background(BattleStyle.ink)
}
