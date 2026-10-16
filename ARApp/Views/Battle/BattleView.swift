//
//  BattleView.swift
//  ARApp
//

import SwiftUI

/// タイミングバトル画面。攻撃方法を選び、流れるカーソルを判定エリアで止めていく
/// 部品は同じフォルダの別ファイルにある（MonsterCardView、TimingGaugeView など）
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

            MonsterCardView(
                name: viewModel.monster.name,
                trait: battle.profile.trait,
                isEnraged: battle.isEnraged,
                isDefeated: battle.outcome == .defeated
            )
            .overlay {
                if let event = viewModel.lastEvent,
                   case .hit(let judgement, let damage, _) = event.kind, damage > 0 {
                    FloatingDamageView(text: "-\(damage)", color: judgement.color)
                        .id(event.id)
                }
            }
            .shake(trigger: monsterShakeCount)

            HPBarView(title: "BOSS HP", hp: battle.monsterHP, maxHP: battle.profile.maxHP, color: .red)
            HPBarView(title: "YOUR HP", hp: battle.playerHP, maxHP: BattleState.playerMaxHP, color: .green)
                .shake(trigger: playerShakeCount)

            if viewModel.isFinished, let outcome = battle.outcome {
                BattleResultView(outcome: outcome, monsterName: viewModel.monster.name) {
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

                BattleMessageView(event: viewModel.lastEvent, monsterName: viewModel.monster.name)

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
                ActionButtonView(title: "攻撃", detail: "ふつう", tint: .blue) {
                    viewModel.startAttack(.normal)
                }
                ActionButtonView(title: "強攻撃", detail: "ダメージ×2・狭い", tint: .orange) {
                    viewModel.startAttack(.strong)
                }
                ActionButtonView(title: "捕獲", detail: "成功率 \(Int(battle.captureChance * 100))%", tint: .purple) {
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

private struct ActionButtonView: View {
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

#Preview {
    BattleView()
}
