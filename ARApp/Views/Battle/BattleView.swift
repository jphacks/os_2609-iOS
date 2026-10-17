//
//  BattleView.swift
//  ARApp
//

import SwiftUI

/// 対戦画面。同じ地点にいる相手とマッチングし、毎ターン同時にタイミング攻撃をし合う
/// 部品は同じフォルダの別ファイルにある（MonsterCardView、TimingGaugeView など）
struct BattleView: View {
    let locationViewModel: LocationViewModel
    @State private var viewModel: BattleViewModel
    /// 揺れの演出のきっかけ。増えるたびに 1 回揺れる
    @State private var opponentShakeCount = 0
    @State private var playerShakeCount = 0

    init(locationViewModel: LocationViewModel, service: any BattleService) {
        self.locationViewModel = locationViewModel
        _viewModel = State(initialValue: BattleViewModel(service: service))
    }

    var body: some View {
        Group {
            if let battle = viewModel.battle {
                battleScreen(battle)
            } else {
                BattleLobbyView(
                    myMonster: viewModel.myMonster,
                    location: locationViewModel.currentLocation,
                    isSearching: viewModel.phase == .searching || viewModel.phase == .cancellingSearch,
                    isCancelling: viewModel.phase == .cancellingSearch,
                    errorMessage: viewModel.errorMessage,
                    onFind: { viewModel.findOpponent(locationID: $0.id) },
                    onCancel: { viewModel.cancelSearch() }
                )
            }
        }
        .padding()
        .sensoryFeedback(trigger: viewModel.lastEvent?.id) { _, _ in
            viewModel.lastEvent?.kind.feedback
        }
        .onChange(of: viewModel.lastEvent?.id) {
            guard case .turnResolved(let dealt, let taken) = viewModel.lastEvent?.kind else { return }
            if dealt > 0 { opponentShakeCount += 1 }
            if taken > 0 { playerShakeCount += 1 }
        }
    }

    private func battleScreen(_ battle: BattleState) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("VS \(battle.opponent.monster.name)")
                    .font(.headline)
                Spacer()
                Text("TURN \(battle.turn) / \(BattleState.turnLimit)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            MonsterCardView(
                name: battle.opponent.monster.name,
                trait: battle.opponent.profile.trait,
                isDefeated: battle.opponent.hp == 0
            )
            .overlay {
                if let event = viewModel.lastEvent,
                   case .hit(let judgement, let damage, _) = event.kind, damage > 0 {
                    FloatingDamageView(text: "-\(damage)", color: judgement.color)
                        .id(event.id)
                }
            }
            .shake(trigger: opponentShakeCount)

            HPBarView(
                title: "相手（\(battle.opponent.monster.name)）",
                hp: battle.opponent.hp,
                maxHP: battle.opponent.profile.maxHP,
                color: .red
            )
            HPBarView(
                title: "自分（\(battle.me.monster.name)）",
                hp: battle.me.hp,
                maxHP: battle.me.profile.maxHP,
                color: .green
            )
            .shake(trigger: playerShakeCount)

            if viewModel.phase == .finished, let outcome = battle.outcome {
                BattleResultView(outcome: outcome, opponentName: battle.opponent.monster.name) {
                    viewModel.leaveBattle()
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

                BattleMessageView(
                    event: viewModel.lastEvent,
                    isWaitingForOpponent: viewModel.phase == .waitingForOpponent
                )

                controls
                    .frame(height: 64)
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
            }
        default:
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
    // ダミーの相手。「対戦相手を探す」を押すと CPU とすぐに対戦が始まる
    let locationViewModel = LocationViewModel(scanner: DummyBeaconScanner())
    BattleView(locationViewModel: locationViewModel, service: DummyBattleService())
        .onAppear { locationViewModel.start() }
}
