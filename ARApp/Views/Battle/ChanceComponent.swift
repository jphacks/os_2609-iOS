//
//  ChanceComponent.swift
//  ARApp
//

import SwiftUI

/// フィーバーのチャンスの演出（パチンコのカットイン）
/// 「チャンス！」と書いた帯が横から飛び込み、帯の色が 青 → 緑 → 赤 → 金 と上がっていく
/// 金まで上がれば当たり（このあと FeverComponent が出る）。途中で止まったら、帯が真っ二つに砕けて消える
/// チャンスの間だけ置く（BattleViewModel の chance があるとき）。色を上げる間隔は BattleViewModel.chanceStepDuration に合わせる
struct ChanceComponent: View {
    let chance: FeverLottery.Chance

    /// 今の帯の色
    @State private var level = FeverLottery.Level.blue
    @State private var isSlidIn = false
    @State private var isBroken = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            // 砕けるときに左右に分かれて飛ぶよう、帯を 2 つ重ねて、それぞれ半分だけ見せる
            ZStack {
                band
                    .clipShape(BrokenHalf(isLeft: true))
                    .offset(x: isBroken ? -90 : 0, y: isBroken ? 30 : 0)
                    .rotationEffect(.degrees(isBroken ? -10 : 0))
                band
                    .clipShape(BrokenHalf(isLeft: false))
                    .offset(x: isBroken ? 90 : 0, y: isBroken ? 45 : 0)
                    .rotationEffect(.degrees(isBroken ? 12 : 0))
            }
            // 色が上がるたびに、一瞬大きくなって弾む
            .phaseAnimator([1, 1.12], trigger: level) { content, scale in
                content.scaleEffect(reduceMotion ? 1 : scale)
            } animation: { _ in
                .spring(duration: 0.2, bounce: 0.6)
            }

            levelMeter
        }
        .opacity(isBroken ? 0 : 1)
        .rotationEffect(.degrees(-4))
        .offset(x: isSlidIn || reduceMotion ? 0 : -600)
        .allowsHitTesting(false)
        .sensoryFeedback(trigger: level) { _, newLevel in
            .impact(weight: newLevel == .gold ? .heavy : .medium)
        }
        .sensoryFeedback(.error, trigger: isBroken) { _, isBroken in isBroken }
        .task { await play() }
    }

    /// 「チャンス！」と書いた帯
    private var band: some View {
        Text("チャンス！")
            .font(BattleStyle.display(56))
            .foregroundStyle(level.textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 48)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(level.color)
            .overlay(alignment: .top) { Rectangle().fill(.white).frame(height: 5) }
            .overlay(alignment: .bottom) { Rectangle().fill(.black).frame(height: 5) }
            .clipShape(SlantedRectangle(slant: 40))
    }

    /// 今どの色まで上がったかを、4 つの四角で見せる
    private var levelMeter: some View {
        HStack(spacing: 6) {
            ForEach(FeverLottery.Level.allCases, id: \.self) { step in
                Rectangle()
                    .fill(step.rawValue <= level.rawValue ? step.color : .black.opacity(0.6))
                    .frame(width: 32, height: 10)
                    .overlay { Rectangle().stroke(.white, lineWidth: 1) }
            }
        }
    }

    /// 飛び込んでから、決まった色まで 1 段ずつ上げ、金でなければ砕く
    private func play() async {
        withAnimation(.spring(duration: 0.3, bounce: 0.3)) { isSlidIn = true }
        BattleSoundPlayer.shared.play(.chanceStep(.blue))
        for next in FeverLottery.Level.allCases.dropFirst() where next.rawValue <= chance.finalLevel.rawValue {
            do {
                try await Task.sleep(for: .seconds(BattleViewModel.chanceStepDuration))
            } catch {
                return // 対戦が終わった
            }
            level = next
            BattleSoundPlayer.shared.play(.chanceStep(next))
        }
        do {
            try await Task.sleep(for: .seconds(BattleViewModel.chanceStepDuration))
        } catch {
            return
        }
        if !chance.willWin {
            BattleSoundPlayer.shared.play(.chanceBreak)
            withAnimation(.easeIn(duration: 0.45)) { isBroken = true }
        }
    }
}

private extension FeverLottery.Level {
    var color: Color {
        switch self {
        case .blue: BattleStyle.cyan
        case .green: BattleStyle.lime
        case .red: BattleStyle.red
        case .gold: BattleStyle.yellow
        }
    }

    /// 帯の上の文字の色。帯の色の上で読みやすい方
    var textColor: Color {
        self == .red ? .white : .black
    }
}

/// 帯を斜めに真っ二つにした、片方の半分
private struct BrokenHalf: Shape {
    let isLeft: Bool

    func path(in rect: CGRect) -> Path {
        // 上は少し右、下は少し左で切って、斜めの割れ目にする
        let top = rect.minX + rect.width * 0.56
        let bottom = rect.minX + rect.width * 0.44
        return Path { path in
            if isLeft {
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: top, y: rect.minY))
                path.addLine(to: CGPoint(x: bottom, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            } else {
                path.move(to: CGPoint(x: top, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: bottom, y: rect.maxY))
            }
            path.closeSubpath()
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        ChanceComponent(chance: FeverLottery.Chance(finalLevel: .red))
        ChanceComponent(chance: FeverLottery.Chance(finalLevel: .gold))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.gray)
}
