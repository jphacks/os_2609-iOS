//
//  BattleView.swift
//  ARApp
//

import SwiftUI

/// タイミングバトル画面。攻撃方法を選び、流れるカーソルを判定エリアで止めていく
struct BattleView: View {
    @State private var viewModel = BattleViewModel()
    /// 揺れの演出のきっかけ。増えるたびに 1 回揺れる
    @State private var monsterShakeCount = 0
    @State private var playerShakeCount = 0

    private var battle: BattleState { viewModel.battle }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("MONSTER BATTLE")
                    .font(.headline)
                Spacer()
                Text("TURN \(battle.turn) / \(battle.profile.turnLimit)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            MonsterCard(
                name: viewModel.monster.name,
                trait: battle.profile.trait,
                isEnraged: battle.isEnraged,
                isDefeated: battle.outcome == .defeated
            )
            .overlay {
                if let event = viewModel.lastEvent,
                   case .hit(let judgement, let damage, _) = event.kind, damage > 0 {
                    FloatingDamage(text: "-\(damage)", color: judgement.color)
                        .id(event.id)
                }
            }
            .shake(trigger: monsterShakeCount)

            HPBar(title: "BOSS HP", hp: battle.monsterHP, maxHP: battle.profile.maxHP, color: .red)
            HPBar(title: "YOUR HP", hp: battle.playerHP, maxHP: BattleState.playerMaxHP, color: .green)
                .shake(trigger: playerShakeCount)

            if viewModel.isFinished, let outcome = battle.outcome {
                ResultView(outcome: outcome, monsterName: viewModel.monster.name) {
                    viewModel.restartBattle()
                }
            } else {
                // 止まっている間は再描画しない。位置は描画する時刻から毎回計算する
                TimelineView(.animation(paused: viewModel.phase != .attacking)) { context in
                    TimingGaugeView(
                        position: viewModel.cursorPosition(at: context.date),
                        zones: viewModel.gauge.zones,
                        results: viewModel.zoneResults
                    )
                }
                .frame(height: 70)

                EventMessage(event: viewModel.lastEvent, monsterName: viewModel.monster.name)

                controls
                    .frame(height: 64)
            }
        }
        .padding()
        .sensoryFeedback(trigger: viewModel.lastEvent?.id) { _, _ in
            viewModel.lastEvent?.kind.feedback
        }
        .onChange(of: viewModel.lastEvent?.id) {
            switch viewModel.lastEvent?.kind {
            case .hit(_, let damage, _) where damage > 0:
                monsterShakeCount += 1
            case .counterattack(let damage) where damage > 0:
                playerShakeCount += 1
            default:
                break
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch viewModel.phase {
        case .choosingAction:
            HStack(spacing: 8) {
                ActionButton(title: "攻撃", detail: "ふつう", tint: .blue) {
                    viewModel.startAttack(.normal)
                }
                ActionButton(title: "強攻撃", detail: "ダメージ×2・狭い", tint: .orange) {
                    viewModel.startAttack(.strong)
                }
                ActionButton(title: "捕獲", detail: "成功率 \(Int(battle.captureChance * 100))%", tint: .purple) {
                    viewModel.capture()
                }
            }
        case .attacking, .resolving:
            Button {
                viewModel.stop()
            } label: {
                VStack(spacing: 2) {
                    Text("STOP!")
                        .font(.title2.bold())
                    Text("あと \(viewModel.remainingTaps) 回")
                        .font(.caption.monospacedDigit())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.phase != .attacking)
        }
    }
}

/// モンスターの見た目（3D モデルは AR 画面でだけ使うので、ここでは仮のアイコン）
private struct MonsterCard: View {
    let name: String
    let trait: String
    let isEnraged: Bool
    let isDefeated: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(
                    LinearGradient(
                        colors: isEnraged ? [.red, .orange] : [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .rect(cornerRadius: 12)
                )
                .overlay(alignment: .topTrailing) {
                    if isEnraged {
                        Label("怒り", systemImage: "flame.fill")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.4), in: .capsule)
                            .foregroundStyle(.white)
                            .padding(8)
                    }
                }
                .opacity(isDefeated ? 0.3 : 1)
                .animation(.easeInOut, value: isEnraged)

            HStack(spacing: 8) {
                Text(name)
                    .font(.title3.bold())
                Text(trait)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// モンスターの上に浮かんで消えるダメージの数字
private struct FloatingDamage: View {
    let text: String
    let color: Color

    @State private var isRisen = false

    var body: some View {
        Text(text)
            .font(.system(size: 44, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.4), radius: 2)
            .scaleEffect(isRisen ? 1 : 1.6)
            .offset(y: isRisen ? -40 : 0)
            .opacity(isRisen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) {
                    isRisen = true
                }
            }
    }
}

private struct HPBar: View {
    let title: String
    let hp: Int
    let maxHP: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(hp) / \(maxHP)")
                    .monospacedDigit()
            }
            .font(.subheadline)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.gray.opacity(0.2))
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * Double(hp) / Double(maxHP))
                }
            }
            .frame(height: 10)
            .animation(.easeOut(duration: 0.4), value: hp)
        }
    }
}

/// 横一直線のゲージ、判定エリア、カーソル。位置はすべて 0 が左端、1 が右端
private struct TimingGaugeView: View {
    let position: Double
    let zones: [TimingZone]
    /// エリアごとの判定。当てたエリアは結果の色になる
    let results: [TimingJudgement?]

    private let cursorWidth: CGFloat = 20

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let x = { (value: Double) in xPosition(of: value, totalWidth: geometry.size.width) }

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.gray.opacity(0.5))
                    .frame(height: 8)
                    .padding(.horizontal, cursorWidth / 2)

                ForEach(zones.indices, id: \.self) { index in
                    let zone = zones[index]
                    let result = index < results.count ? results[index] : nil
                    let color = result?.color ?? .green

                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.15))
                        .strokeBorder(color, lineWidth: 3)
                        .frame(width: x(zone.goodRange.upperBound) - x(zone.goodRange.lowerBound), height: height)
                        .offset(x: x(zone.goodRange.lowerBound))

                    Rectangle()
                        .fill(color.opacity(0.4))
                        .frame(width: x(zone.perfectRange.upperBound) - x(zone.perfectRange.lowerBound), height: height - 6)
                        .offset(x: x(zone.perfectRange.lowerBound))
                }

                RoundedRectangle(cornerRadius: 6)
                    .fill(.blue)
                    .frame(width: cursorWidth, height: height * 0.75)
                    .offset(x: x(position) - cursorWidth / 2)
            }
            .frame(maxHeight: .infinity)
        }
    }

    /// ゲージ上の位置（0〜1）を、左端からの x 座標に変換する
    /// カーソルの中心が線の端から端まで動くように、カーソルの幅ぶん内側に寄せる
    private func xPosition(of value: Double, totalWidth: CGFloat) -> CGFloat {
        cursorWidth / 2 + (totalWidth - cursorWidth) * value
    }
}

/// 直前の出来事を文字で伝える
private struct EventMessage: View {
    let event: BattleViewModel.Event?
    let monsterName: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(height: 52)
    }

    private var title: String {
        switch event?.kind {
        case .hit(.perfect, _, let combo) where combo >= 2: "PERFECT! \(combo) COMBO"
        case .hit(.perfect, _, _): "PERFECT!"
        case .hit(.good, _, _): "GOOD"
        case .hit(.miss, _, _): "MISS..."
        case .counterattack(let damage): damage > 0 ? "\(monsterName)の反撃！" : "攻撃をかわした！"
        case .capture(let succeeded): succeeded ? "捕まえた！" : "捕獲失敗…"
        case nil: "攻撃方法を選ぼう"
        }
    }

    private var detail: String {
        switch event?.kind {
        case .hit(_, let damage, _): "\(damage) ダメージ"
        case .counterattack(let damage): damage > 0 ? "\(damage) ダメージを受けた" : "全部 PERFECT で反撃を回避"
        case .capture(let succeeded): succeeded ? " " : "弱らせるほど捕まえやすい"
        case nil: "STOP はエリアの数だけ押せる。外しても流れ続ける"
        }
    }

    private var color: Color {
        switch event?.kind {
        case .hit(let judgement, _, _): judgement.color
        case .counterattack(let damage): damage > 0 ? .red : .blue
        case .capture(let succeeded): succeeded ? .purple : .gray
        case nil: .primary
        }
    }
}

private struct ActionButton: View {
    let title: String
    let detail: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }
}

private struct ResultView: View {
    let outcome: BattleOutcome
    let monsterName: String
    let onRestart: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol.name)
                .font(.system(size: 44))
                .foregroundStyle(symbol.color)
            Text(title)
                .font(.largeTitle.bold())
            Text(message)
            Button("次のモンスターとたたかう", action: onRestart)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(.top, 8)
    }

    private var symbol: (name: String, color: Color) {
        switch outcome {
        case .defeated: ("trophy.fill", .yellow)
        case .captured: ("sparkles", .purple)
        case .lost: ("xmark.octagon.fill", .gray)
        case .escaped: ("figure.run", .gray)
        }
    }

    private var title: String {
        switch outcome {
        case .defeated: "VICTORY!"
        case .captured: "GET!"
        case .lost: "DEFEAT..."
        case .escaped: "ESCAPED..."
        }
    }

    private var message: String {
        switch outcome {
        case .defeated: "\(monsterName)をたおした！"
        case .captured: "\(monsterName)を捕まえた！"
        case .lost: "\(monsterName)にやられてしまった…"
        case .escaped: "\(monsterName)は逃げてしまった…"
        }
    }
}

private extension TimingJudgement {
    var color: Color {
        switch self {
        case .perfect: .orange
        case .good: .green
        case .miss: .gray
        }
    }
}

private extension BattleViewModel.Event.Kind {
    /// 出来事ごとの振動
    var feedback: SensoryFeedback? {
        switch self {
        case .hit(.perfect, _, _): .impact(weight: .heavy, intensity: 1)
        case .hit(.good, _, _): .impact(weight: .light)
        case .hit(.miss, _, _): .error
        case .counterattack(let damage): damage > 0 ? .impact(flexibility: .rigid, intensity: 1) : .success
        case .capture(let succeeded): succeeded ? .success : .error
        }
    }
}

private extension View {
    /// trigger が変わるたびに左右に揺れる
    func shake(trigger: Int) -> some View {
        keyframeAnimator(initialValue: 0.0, trigger: trigger) { content, offset in
            content.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(12, duration: 0.05)
                CubicKeyframe(-10, duration: 0.07)
                CubicKeyframe(6, duration: 0.07)
                CubicKeyframe(-3, duration: 0.06)
                CubicKeyframe(0, duration: 0.05)
            }
        }
    }
}

#Preview {
    BattleView()
}
