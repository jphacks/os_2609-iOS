//
//  BattleView.swift
//  ARApp
//

import SwiftUI

/// 対戦画面。同じ地点にいる相手とマッチングし、画面の空いている所をタップして攻撃し、溜まったら必殺技を撃つ
/// 部品は同じフォルダの別ファイルにある（StatBarComponent、BattleEffects など）
struct BattleView: View {
    let locationViewModel: LocationViewModel
    @State private var viewModel: BattleViewModel
    /// タップした位置の波紋。クールダウン中でも出るので、タップが届いているかがわかる
    @State private var tapRipple: TapRipple?
    /// 自分と相手のモンスターに流すアニメーション。どれを流すかは見た目の話なので、この画面で決める
    @State private var myAnimation: MonsterAnimationRequest?
    @State private var opponentAnimation: MonsterAnimationRequest?

    /// 攻撃の動きを流し始めてから、相手に当たるまでの時間（秒）。のけぞりをこの分だけ遅らせる
    private static let impactDelay = 0.25

    init(locationViewModel: LocationViewModel, service: any BattleService) {
        self.locationViewModel = locationViewModel
        _viewModel = State(initialValue: BattleViewModel(service: service))
    }

    var body: some View {
        if let me = viewModel.me, let opponent = viewModel.opponent, let opponentMonster = viewModel.opponentMonster {
            fightScreen(me: me, opponent: opponent, opponentMonster: opponentMonster)
        } else {
            BattleLobbyComponent(
                myMonster: viewModel.myMonster,
                location: locationViewModel.currentLocation,
                isSearching: viewModel.phase == .searching || viewModel.phase == .cancellingSearch,
                isCancelling: viewModel.phase == .cancellingSearch,
                errorMessage: viewModel.errorMessage,
                onFind: { viewModel.findOpponent(locationID: $0.id) },
                onCancel: { viewModel.cancelSearch() }
            )
            .padding()
        }
    }

    private func fightScreen(me: Fighter, opponent: Fighter, opponentMonster: Monster) -> some View {
        VStack(spacing: 16) {
            // 1. 上部：相手の名前と HP
            StatBarComponent(title: opponent.name, value: opponent.hp, maxValue: opponent.maxHP, color: .red)

            // 2. 中央上：相手のモンスター。こちらを向いて、左下の自分のモンスターの方を見る
            BattleMonsterComponent(monster: opponentMonster, animation: opponentAnimation, facing: -0.5)
                .frame(width: 260, height: 260)
                .overlay {
                    if let hit = viewModel.lastHitOnOpponent {
                        FloatingDamageComponent(
                            text: "-\(hit.damage)",
                            color: hit.isSpecial ? .yellow : .red,
                            fontSize: hit.isSpecial ? 64 : 36
                        )
                        .id(hit.id)
                    }
                }
                .shake(trigger: viewModel.lastHitOnOpponent?.id)
                // 相手の攻撃のたびに自分の方へ踏み込む
                .lunge(CGSize(width: -24, height: 36), trigger: viewModel.lastHitOnMe?.id)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Spacer(minLength: 0)

            // 3. 中央下：自分のモンスター。後ろ姿で、右上の相手の方を向く
            BattleMonsterComponent(monster: viewModel.myMonster, animation: myAnimation, facing: .pi - 0.5)
                .frame(width: 250, height: 250)
                .overlay {
                    if let hit = viewModel.lastHitOnMe {
                        FloatingDamageComponent(text: "-\(hit.damage)", color: .purple, fontSize: hit.isSpecial ? 64 : 36)
                            .id(hit.id)
                    }
                }
                .shake(trigger: viewModel.lastHitOnMe?.id)
                // 攻撃するたびに相手の方へ踏み込む
                .lunge(CGSize(width: 24, height: -36), trigger: viewModel.lastHitOnOpponent?.id)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 4. 下部：自分の HP と必殺技ゲージ
            VStack(spacing: 8) {
                StatBarComponent(title: me.name, value: me.hp, maxValue: me.maxHP, color: .green)
                StatBarComponent(
                    title: "必殺技ゲージ",
                    value: me.specialGauge,
                    maxValue: Fighter.specialGaugeMax,
                    color: me.canUseSpecial ? .orange : .yellow
                )
            }

            // 5. 最下部：必殺技ボタン
            Button {
                viewModel.useSpecial()
            } label: {
                Label(me.canUseSpecial ? "必殺技 READY!" : "必殺技", systemImage: "bolt.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .disabled(!me.canUseSpecial)
        }
        .padding()
        // 空いている所もタップできるようにする。ボタンのタップはボタンが優先される
        .contentShape(Rectangle())
        .onTapGesture { location in
            tapRipple = TapRipple(location: location)
            viewModel.attack()
        }
        .overlay {
            if let tapRipple {
                TapRippleComponent()
                    .position(tapRipple.location)
                    .id(tapRipple.id)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            // 必殺技が当たった瞬間、画面全体を光らせる
            if let hit = viewModel.lastHitOnOpponent, hit.isSpecial {
                FlashComponent()
                    .id(hit.id)
            }
        }
        .overlay {
            // 決着が確定したら結果を全面に出す
            if let outcome = viewModel.outcome {
                BattleResultComponent(outcome: outcome, opponentName: opponent.name) {
                    viewModel.leaveBattle()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: viewModel.outcome)
        // HP は引数の me / opponent ではなく viewModel から読む（引数は前に描いたときの値のことがある）
        .onChange(of: viewModel.lastHitOnOpponent?.id) {
            guard let hit = viewModel.lastHitOnOpponent, let opponent = viewModel.opponent else { return }
            myAnimation = attackAnimation(of: viewModel.myMonster, hit: hit)
            opponentAnimation = reactionAnimation(hp: opponent.hp)
        }
        .onChange(of: viewModel.lastHitOnMe?.id) {
            guard let hit = viewModel.lastHitOnMe, let me = viewModel.me else { return }
            opponentAnimation = attackAnimation(of: opponentMonster, hit: hit)
            myAnimation = reactionAnimation(hp: me.hp)
        }
        // 次の対戦で、前の対戦のアニメーション（倒れたままなど）を流さないように消しておく
        .onDisappear {
            myAnimation = nil
            opponentAnimation = nil
        }
    }

    /// 攻撃する側のアニメーション
    private func attackAnimation(of monster: Monster, hit: BattleViewModel.Hit) -> MonsterAnimationRequest {
        MonsterAnimationRequest(animation: hit.isSpecial ? monster.specialAttack : monster.normalAttack)
    }

    /// 攻撃を受けた側のアニメーション。攻撃が当たるタイミングでのけぞり、HP が 0 になったら倒れたままになる
    private func reactionAnimation(hp: Int) -> MonsterAnimationRequest {
        hp == 0
            ? MonsterAnimationRequest(animation: .death, delay: Self.impactDelay, staysAtEnd: true)
            : MonsterAnimationRequest(animation: .hitReact, delay: Self.impactDelay)
    }
}

private struct TapRipple {
    let id = UUID()
    let location: CGPoint
}

#Preview {
    // ダミーの相手。「対戦相手を探す」を押すと CPU とすぐに対戦が始まる
    let locationViewModel = LocationViewModel(scanner: DummyBeaconScanner())
    BattleView(locationViewModel: locationViewModel, service: DummyBattleService())
        .onAppear { locationViewModel.start() }
}
