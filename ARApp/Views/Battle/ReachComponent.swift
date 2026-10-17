//
//  ReachComponent.swift
//  ARApp
//

import SwiftUI

/// フィーバーのリーチ（パチンコのスロット）。「7 7 ？」と並び、3 つ目がくるくる回ってから止まる
/// 7 で止まれば当たり（このあとフィーバーが始まる）、ほかの数字ならはずれ
/// 赤いリーチ（激アツ）は、枠が赤く光り、回るのが最後にゆっくりになって焦らす
/// リーチの間だけ置く（BattleViewModel の reach があるとき）。止めるタイミングは BattleViewModel.reachDuration に合わせる
struct ReachComponent: View {
    let reach: FeverLottery.Reach
    @State private var startedAt = Date.now
    /// はずれのときに止める数字。7 の隣で止めて「惜しい」と思わせる
    @State private var missDigit = Bool.random() ? 6 : 8

    /// 止まった数字を見せておく時間（秒）
    private static let resultDuration = 0.6

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(startedAt)
            let isStopped = elapsed >= BattleViewModel.reachDuration - Self.resultDuration
            VStack(spacing: 8) {
                Text(title(isStopped: isStopped))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .italic()
                    .foregroundStyle(accent)
                HStack(spacing: 8) {
                    ReelComponent(digit: 7, accent: accent)
                    ReelComponent(digit: 7, accent: accent)
                    ReelComponent(digit: isStopped ? finalDigit : spinningDigit(elapsed: elapsed), accent: accent)
                }
            }
            .padding(16)
            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(accent, lineWidth: 3)
                    .shadow(color: accent, radius: reach.isHot ? 12 : 4)
            }
            .scaleEffect(isStopped && reach.willWin ? 1.15 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.6), value: isStopped)
        }
        .shadow(radius: 8)
        .allowsHitTesting(false)
        .transition(.scale.combined(with: .opacity))
    }

    private var accent: Color { reach.isHot ? .red : .cyan }
    private var finalDigit: Int { reach.willWin ? 7 : missDigit }

    private func title(isStopped: Bool) -> String {
        if isStopped { return reach.willWin ? "大当たり!!" : "ざんねん…" }
        return reach.isHot ? "激アツ!!" : "リーチ!"
    }

    /// 回っている間の数字。激アツは止まる直前にゆっくりになる
    private func spinningDigit(elapsed: Double) -> Int {
        let spinEnd = BattleViewModel.reachDuration - Self.resultDuration
        let slowsDown = reach.isHot && elapsed > spinEnd - 0.5
        let step = Int(elapsed / (slowsDown ? 0.18 : 0.05))
        return step % 9 + 1
    }
}

/// スロットの数字 1 つぶん
private struct ReelComponent: View {
    let digit: Int
    let accent: Color

    var body: some View {
        Text("\(digit)")
            .font(.system(size: 64, weight: .black, design: .rounded).monospacedDigit())
            .foregroundStyle(digit == 7 ? .yellow : .white)
            .shadow(color: digit == 7 ? .orange : .clear, radius: 6)
            .frame(width: 64, height: 84)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(accent.opacity(0.6), lineWidth: 1)
            }
    }
}

#Preview {
    VStack(spacing: 24) {
        ReachComponent(reach: FeverLottery.Reach(isHot: false, willWin: false))
        ReachComponent(reach: FeverLottery.Reach(isHot: true, willWin: true))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.gray)
}
