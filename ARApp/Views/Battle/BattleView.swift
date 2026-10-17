//
//  BattleView.swift
//  ARApp
//

import SwiftUI

/// 対戦画面。同じ地点にいる相手とマッチングし、画面の空いている所をタップして攻撃し、溜まったら必殺技を撃つ
/// 対戦中は、カメラに映る床の上でモンスター同士が戦う（AR）
/// 部品は同じフォルダの別ファイルにある（StatBarComponent、BattleEffects など）
struct BattleView: View {
    let locationViewModel: LocationViewModel
    @State private var viewModel: BattleViewModel
    /// タップした位置の波紋。クールダウン中でも出るので、タップが届いているかがわかる
    @State private var tapRipple: TapRipple?
    /// 自分と相手のモンスターに流すアニメーション。どれを流すかは見た目の話なので、この画面で決める
    @State private var myAnimation: MonsterAnimationRequest?
    @State private var opponentAnimation: MonsterAnimationRequest?
    /// この画面が表示されているか
    /// TabView は別のタブに切り替えても画面を残すので、自分で ARView を外してカメラを止める
    @State private var isVisible = false

    /// 攻撃の動きを流し始めてから、相手に当たるまでの時間（秒）。のけぞりをこの分だけ遅らせる
    private static let attackImpactTime = 0.25
    /// 必殺技を撃つ前の溜めの動き
    private static let specialCharge = MonsterAnimation.jump
    /// 決着してから、勝った側が喜び始めるまでの時間（秒）。最後の攻撃の動きを見せてから喜ぶ
    private static let celebrationDelay = 1.0

    init(locationViewModel: LocationViewModel, service: any BattleService) {
        self.locationViewModel = locationViewModel
        _viewModel = State(initialValue: BattleViewModel(service: service))
    }

    var body: some View {
        content
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
    }

    @ViewBuilder
    private var content: some View {
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
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            // 2. 中央：当たったダメージの数字。モンスターは後ろの AR の床の上にいる
            // 数字はモンスターの位置には合わせず、相手の分は上、自分の分は下に出す
            ZStack {
                if let hit = viewModel.lastHitOnOpponent {
                    FloatingDamageComponent(
                        text: "-\(hit.damage)",
                        color: hit.isSpecial ? .yellow : .red,
                        fontSize: hit.isSpecial ? 64 : 36
                    )
                    .id(hit.id)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 120)
                }
                if let hit = viewModel.lastHitOnMe {
                    FloatingDamageComponent(text: "-\(hit.damage)", color: .purple, fontSize: hit.isSpecial ? 64 : 36)
                        .id(hit.id)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 3. 下部：自分の HP と必殺技ゲージ
            VStack(spacing: 8) {
                StatBarComponent(title: me.name, value: me.hp, maxValue: me.maxHP, color: .green)
                StatBarComponent(
                    title: "必殺技ゲージ",
                    value: me.specialGauge,
                    maxValue: Fighter.specialGaugeMax,
                    color: me.canUseSpecial ? .orange : .yellow
                )
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            // 4. 最下部：必殺技ボタン
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
        .background {
            BattleArenaComponent(
                myMonster: viewModel.myMonster,
                opponentMonster: opponentMonster,
                myAnimation: myAnimation,
                opponentAnimation: opponentAnimation,
                hitOnOpponentID: viewModel.lastHitOnOpponent?.id,
                hitOnMeID: viewModel.lastHitOnMe?.id,
                isVisible: isVisible
            )
            // 攻撃を受けたら、カメラの映像ごと揺らす
            .shake(trigger: viewModel.lastHitOnMe?.id)
        }
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
            // 必殺技が当たった瞬間（溜めのあと）、画面全体を光らせる
            if let hit = viewModel.lastHitOnOpponent, hit.isSpecial {
                FlashComponent(delay: Self.impactDelay(of: hit))
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
        // カメラの映像の上でも文字が読みやすいよう、暗い背景に白い文字にする
        .environment(\.colorScheme, .dark)
        // HP は引数の me / opponent ではなく viewModel から読む（引数は前に描いたときの値のことがある）
        .onChange(of: viewModel.lastHitOnOpponent?.id) {
            guard let hit = viewModel.lastHitOnOpponent, let opponent = viewModel.opponent else { return }
            myAnimation = attackAnimation(of: viewModel.myMonster, hit: hit)
            opponentAnimation = reactionAnimation(hp: opponent.hp, hit: hit)
        }
        .onChange(of: viewModel.lastHitOnMe?.id) {
            guard let hit = viewModel.lastHitOnMe, let me = viewModel.me else { return }
            opponentAnimation = attackAnimation(of: opponentMonster, hit: hit)
            myAnimation = reactionAnimation(hp: me.hp, hit: hit)
        }
        // 決着したら、勝った側が喜ぶ
        .onChange(of: viewModel.outcome) {
            guard let outcome = viewModel.outcome, let me = viewModel.me, let opponent = viewModel.opponent else { return }
            let celebration = MonsterAnimationRequest(animations: [.yes, .wave], delay: Self.celebrationDelay, ending: .repeats)
            // 確定した勝敗が、この端末の HP と食い違うこともある（ほぼ同時に倒し合ったときなど）
            // そのときは負けた側がまだ倒れていないので、ここで倒す
            let defeat = MonsterAnimationRequest(animations: [.death], ending: .staysAtEnd)
            switch outcome {
            case .won:
                myAnimation = celebration
                if opponent.hp > 0 { opponentAnimation = defeat }
            case .lost:
                opponentAnimation = celebration
                if me.hp > 0 { myAnimation = defeat }
            }
        }
        // 次の対戦で、前の対戦のアニメーション（倒れたままなど）を流さないように消しておく
        .onDisappear {
            myAnimation = nil
            opponentAnimation = nil
        }
    }

    /// 攻撃する側のアニメーション。必殺技は、溜めの動きのあとに攻撃する
    private func attackAnimation(of monster: Monster, hit: BattleViewModel.Hit) -> MonsterAnimationRequest {
        hit.isSpecial
            ? MonsterAnimationRequest(animations: [Self.specialCharge, monster.specialAttack])
            : MonsterAnimationRequest(animations: [monster.normalAttack])
    }

    /// 攻撃を受けた側のアニメーション。攻撃が当たるタイミングでのけぞり、HP が 0 になったら倒れたままになる
    private func reactionAnimation(hp: Int, hit: BattleViewModel.Hit) -> MonsterAnimationRequest {
        hp == 0
            ? MonsterAnimationRequest(animations: [.death], delay: Self.impactDelay(of: hit), ending: .staysAtEnd)
            : MonsterAnimationRequest(animations: [.hitReact], delay: Self.impactDelay(of: hit))
    }

    /// 攻撃の動きを流し始めてから、相手に当たるまでの時間（秒）。必殺技は溜めの動きの分だけ遅くなる
    /// 溜めの動きは、終わる少し前（混ぜて切り替える時間）から攻撃の動きに切り替わる
    private static func impactDelay(of hit: BattleViewModel.Hit) -> Double {
        let chargeTime = hit.isSpecial ? specialCharge.duration - MonsterAnimation.transitionDuration : 0
        return chargeTime + attackImpactTime
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
