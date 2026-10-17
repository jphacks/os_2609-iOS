//
//  BattleView.swift
//  ARApp
//

import SwiftUI
import ARKit

/// 対戦画面。開いている間は自動で対戦相手を待ち、見つかったら対戦が始まる
/// 画面の空いている所をタップして攻撃し、溜まったら必殺技を撃つ
/// 対戦中は、カメラに映る床の上でモンスター同士が戦う（AR）
/// 部品は同じフォルダの別ファイルにある（StatBarComponent、BattleEffects など）
struct BattleView: View {
    @State private var viewModel: BattleViewModel
    /// タップした位置の波紋。クールダウン中でも出るので、タップが届いているかがわかる
    @State private var tapRipple: TapRipple?
    /// 自分と相手のモンスターに流すアニメーション。どれを流すかは見た目の話なので、この画面で決める
    @State private var myAnimation: MonsterAnimationRequest?
    @State private var opponentAnimation: MonsterAnimationRequest?
    /// 必殺技の動きを流し終わる時刻。それまでは、そのモンスターに通常攻撃やのけぞりの動きを流さない
    /// 流すと、必殺技の溜めや攻撃の動きが途中で切れてしまうため（倒れるときだけは流す）
    @State private var mySpecialEndsAt = Date.distantPast
    @State private var opponentSpecialEndsAt = Date.distantPast
    /// 最後に相手へ当たった必殺技。画面を光らせるのに使う
    /// lastHitOnOpponent を見ると、光る前に次の通常攻撃が当たったときに、光る演出ごと消えてしまう
    @State private var lastSpecialHitOnOpponent: BattleViewModel.Hit?
    /// 続けて当てた回数。前に当ててから comboTimeout 秒以内に次を当てると増える
    @State private var comboCount = 0
    /// この画面が表示されているか
    /// TabView は別のタブに切り替えても画面を残すので、自分で ARView を外してカメラを止める
    @State private var isVisible = false

    /// AR を使える端末では、画面を開いたら自動で対戦相手を待つ
    /// 【開発用】AR を使えない端末（シミュレータ）では、ロビーの「バトルする」ボタンを押したときだけ待つ
    private static let waitsAutomatically = ARWorldTrackingConfiguration.isSupported
    /// 決着してから、勝った側が喜び始めるまでの時間（秒）。最後の攻撃の動きを見せてから喜ぶ
    private static let celebrationDelay = 1.0
    /// この時間（秒）次の攻撃を当てなかったら、続けて当てた回数を 0 に戻す
    private static let comboTimeout = 1.2
    /// HP がこの割合より少なくなったら、立っている間の動きを弱った動きにする
    private static let weakHPRatio = 0.2

    init(service: any BattleService) {
        _viewModel = State(initialValue: BattleViewModel(service: service))
    }

    var body: some View {
        content
            .onAppear {
                isVisible = true
                if Self.waitsAutomatically {
                    viewModel.startWaiting()
                }
            }
            .onDisappear {
                isVisible = false
                viewModel.stopWaiting()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let me = viewModel.me, let opponent = viewModel.opponent, let opponentMonster = viewModel.opponentMonster {
            fightScreen(me: me, opponent: opponent, opponentMonster: opponentMonster)
        } else {
            BattleLobbyComponent(
                myMonster: viewModel.myMonster,
                isWaiting: viewModel.phase == .searching,
                errorMessage: viewModel.errorMessage,
                onStart: Self.waitsAutomatically ? nil : { viewModel.startWaiting() }
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

            // 2. 中央：後ろの AR の床の上で戦うモンスターが見えるように空けておく。右上に、続けて当てた回数を出す
            // 回数を出していない間も場所を取るように、透明な View に重ねる（ComboComponent は回数が少ないと空になる）
            Color.clear
                .overlay(alignment: .topTrailing) {
                    ComboComponent(count: comboCount)
                }

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
                myIdle: idleAnimation(of: me),
                opponentIdle: idleAnimation(of: opponent),
                myAnimation: myAnimation,
                opponentAnimation: opponentAnimation,
                hitOnOpponent: viewModel.lastHitOnOpponent,
                hitOnMe: viewModel.lastHitOnMe,
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
            if let hit = lastSpecialHitOnOpponent {
                FlashComponent(delay: hit.impactDelay)
                    .id(hit.id)
            }
        }
        .overlay {
            // 決着が確定したら結果を全面に出す
            if let outcome = viewModel.outcome {
                BattleResultComponent(outcome: outcome, opponentName: opponent.name) {
                    // 【開発用】ボタンで待ち始める端末では、次もボタンを押すまで待たない
                    if !Self.waitsAutomatically {
                        viewModel.stopWaiting()
                    }
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
            if hit.isSpecial {
                lastSpecialHitOnOpponent = hit
                mySpecialEndsAt = .now + Self.specialDuration(of: viewModel.myMonster)
                myAnimation = attackAnimation(of: viewModel.myMonster, hit: hit)
            } else if Date.now >= mySpecialEndsAt {
                myAnimation = attackAnimation(of: viewModel.myMonster, hit: hit)
            }
            if opponent.hp == 0 || Date.now >= opponentSpecialEndsAt {
                opponentAnimation = reactionAnimation(hp: opponent.hp, hit: hit)
            }
            comboCount += 1
        }
        // 当てるたびに待ち直し、次を当てないまま時間が過ぎたら、続けて当てた回数を 0 に戻す
        .task(id: viewModel.lastHitOnOpponent?.id) {
            do {
                try await Task.sleep(for: .seconds(Self.comboTimeout))
            } catch {
                return // 次の攻撃が当たった
            }
            comboCount = 0
        }
        .onChange(of: viewModel.lastHitOnMe?.id) {
            guard let hit = viewModel.lastHitOnMe, let me = viewModel.me else { return }
            if hit.isSpecial {
                opponentSpecialEndsAt = .now + Self.specialDuration(of: opponentMonster)
                opponentAnimation = attackAnimation(of: opponentMonster, hit: hit)
            } else if Date.now >= opponentSpecialEndsAt {
                opponentAnimation = attackAnimation(of: opponentMonster, hit: hit)
            }
            if me.hp == 0 || Date.now >= mySpecialEndsAt {
                myAnimation = reactionAnimation(hp: me.hp, hit: hit)
            }
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
            mySpecialEndsAt = .distantPast
            opponentSpecialEndsAt = .distantPast
            lastSpecialHitOnOpponent = nil
            comboCount = 0
        }
    }

    /// 立っている間にくり返すアニメーション。HP が少ないと、頭を抱えてしゃがむ弱った動きになる
    private func idleAnimation(of fighter: Fighter) -> MonsterAnimation {
        Double(fighter.hp) < Double(fighter.maxHP) * Self.weakHPRatio ? .duck : .idle
    }

    /// 攻撃する側のアニメーション。必殺技は、溜めの動きのあとに攻撃する
    private func attackAnimation(of monster: Monster, hit: BattleViewModel.Hit) -> MonsterAnimationRequest {
        hit.isSpecial
            ? MonsterAnimationRequest(animations: [BattleViewModel.Hit.specialCharge, monster.specialAttack])
            : MonsterAnimationRequest(animations: [monster.normalAttack])
    }

    /// 必殺技の動き（溜め → 攻撃）を流し終わるまでの時間（秒）
    private static func specialDuration(of monster: Monster) -> Double {
        BattleViewModel.Hit.specialCharge.duration - MonsterAnimation.transitionDuration + monster.specialAttack.duration
    }

    /// 攻撃を受けた側のアニメーション。攻撃が当たるタイミングでのけぞり、HP が 0 になったら倒れたままになる
    private func reactionAnimation(hp: Int, hit: BattleViewModel.Hit) -> MonsterAnimationRequest {
        hp == 0
            ? MonsterAnimationRequest(animations: [.death], delay: hit.impactDelay, ending: .staysAtEnd)
            : MonsterAnimationRequest(animations: [.hitReact], delay: hit.impactDelay)
    }
}

private struct TapRipple {
    let id = UUID()
    let location: CGPoint
}

#Preview {
    // ダミーの相手。開くと少し待ってから CPU との対戦が始まる
    BattleView(service: DummyBattleService())
}
