//
//  BattleFightComponent.swift
//  ARApp
//

import SwiftUI

/// 対戦中の画面。後ろの AR の床の上でモンスター同士が戦い、その上に HP やゲージ、必殺技・フィーバーのボタンを重ねる
/// 当たったときの音と振動、フィーバー・相手の必殺技の予告・勝利の演出もここで出す
/// 1 回の対戦の中だけで使う見た目の状態（流すアニメーション、続けて当てた回数など）はここに持つ
/// 対戦が終わるとこの View ごとなくなるので、次の対戦には前の状態が残らない
struct BattleFightComponent: View {
    let viewModel: BattleViewModel
    let me: Fighter
    let opponent: Fighter
    let myMonster: Monster
    let opponentMonster: Monster
    /// バトルの画面が表示されているか。表示されている間だけ AR を動かす
    let isVisible: Bool

    /// タップした位置の波紋。クールダウン中でも出るので、タップが届いているかがわかる
    @State private var tapRipple: TapRipple?
    /// 自分と相手のモンスターに流すアニメーション。どれを流すかは見た目の話なので、この画面で決める
    @State private var myAnimation: MonsterAnimationRequest?
    @State private var opponentAnimation: MonsterAnimationRequest?
    /// 必殺技の動きを流し終わる時刻。それまでは、そのモンスターに通常攻撃やのけぞりの動きを流さない
    /// 流すと、必殺技の溜めや攻撃の動きが途中で切れてしまうため（倒れるときだけは流す）
    @State private var mySpecialEndsAt = Date.distantPast
    @State private var opponentSpecialEndsAt = Date.distantPast
    /// 最後に相手へ当たった必殺技かとどめ。画面を光らせるのに使う
    /// lastHitOnOpponent を見ると、光る前に次の通常攻撃が当たったときに、光る演出ごと消えてしまう
    @State private var lastFlashHitOnOpponent: BattleViewModel.Hit?
    /// 続けて当てた回数。前に当ててから comboTimeout 秒以内に次を当てると増える
    @State private var comboCount = 0
    /// 相手に当たった瞬間（攻撃を始めてから impactDelay 秒後）の攻撃。変わるたびに振動させる
    @State private var impactOnOpponent: BattleViewModel.Hit?
    /// 決着が確定してから、結果を出し始めたか。勝ったときは「VICTORY!」を見せてから結果を出す
    @State private var isResultShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 決着してから、勝った側が喜び始めるまでの時間（秒）。最後の攻撃の動きを見せてから喜ぶ
    private static let celebrationDelay = 1.0
    /// この時間（秒）次の攻撃を当てなかったら、続けて当てた回数を 0 に戻す
    private static let comboTimeout = 1.2
    /// HP がこの割合より少なくなったら、立っている間の動きを弱った動きにする
    private static let weakHPRatio = 0.2
    /// 確定してから結果を出すまでの時間（秒）。勝ったときは「VICTORY!」を見せ、負けたときは倒れるところを見せる
    private static let victoryDuration = 2.2
    private static let defeatDuration = 1.2

    var body: some View {
        screen
            // HP は引数の me / opponent ではなく viewModel から読む（引数は前に描いたときの値のことがある）
            .onChange(of: viewModel.lastHitOnOpponent?.id) { onHitOnOpponent() }
            // 当てるたびに待ち直し、次を当てないまま時間が過ぎたら、続けて当てた回数を 0 に戻す
            .task(id: viewModel.lastHitOnOpponent?.id) {
                do {
                    try await Task.sleep(for: .seconds(Self.comboTimeout))
                } catch {
                    return // 次の攻撃が当たった
                }
                comboCount = 0
            }
            .onChange(of: viewModel.lastHitOnMe?.id) { onHitOnMe() }
            .onChange(of: viewModel.feverEndsAt) {
                if viewModel.feverEndsAt != nil {
                    BattleSoundPlayer.shared.play(.feverStart)
                }
            }
            .onChange(of: viewModel.incomingDanger?.id) {
                if viewModel.incomingDanger != nil {
                    BattleSoundPlayer.shared.play(.danger)
                }
            }
            // 決着が確定したら、少し待ってから結果を出す
            .task(id: viewModel.outcome) {
                guard let outcome = viewModel.outcome else { return }
                try? await Task.sleep(for: .seconds(outcome == .won ? Self.victoryDuration : Self.defeatDuration))
                isResultShown = true
            }
            .onChange(of: viewModel.outcome) { onOutcome() }
    }

    /// HP やボタンを並べ、後ろに AR を置き、上に演出を重ねる
    /// 修飾子を 1 つの式に続けすぎると型チェックが終わらなくなるので、tappableLayout と分けている
    private var screen: some View {
        tappableLayout
            .overlay { effects }
            .animation(.easeOut(duration: 0.3), value: viewModel.outcome)
            .animation(.easeOut(duration: 0.3), value: isResultShown)
            .animation(.easeOut(duration: 0.2), value: viewModel.feverEndsAt)
            // 当たった瞬間に振動させる
            .sensoryFeedback(trigger: impactOnOpponent?.id) { (_: UUID?, _: UUID?) -> SensoryFeedback? in
                impactFeedback
            }
            // フィーバーが始まったとき、勝ったときは成功の振動、相手の必殺技の予告では警告の振動
            .sensoryFeedback(.success, trigger: viewModel.feverEndsAt) { (_: Date?, endsAt: Date?) -> Bool in
                endsAt != nil
            }
            .sensoryFeedback(.warning, trigger: viewModel.incomingDanger?.id) { (_: UUID?, id: UUID?) -> Bool in
                id != nil
            }
            .sensoryFeedback(.success, trigger: viewModel.outcome) {
                (_: BattleViewModel.Outcome?, outcome: BattleViewModel.Outcome?) -> Bool in
                outcome == .won
            }
            // カメラの映像の上でも文字が読みやすいよう、暗い背景に白い文字にする
            .environment(\.colorScheme, .dark)
    }

    /// 画面のどこをタップしても攻撃する。タップした所に波紋を出す
    private var tappableLayout: some View {
        layout
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
    }

    private var layout: some View {
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

            // 3. 下部：自分の HP、必殺技ゲージ、フィーバーゲージ
            VStack(spacing: 8) {
                StatBarComponent(title: me.name, value: me.hp, maxValue: me.maxHP, color: .green)
                StatBarComponent(
                    title: "必殺技ゲージ",
                    value: me.specialGauge,
                    maxValue: Fighter.specialGaugeMax,
                    color: me.canUseSpecial ? .orange : .yellow
                )
                StatBarComponent(
                    title: "フィーバーゲージ",
                    value: me.feverGauge,
                    maxValue: Fighter.feverGaugeMax,
                    color: me.canUseFever ? .pink : .purple
                )
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            // 4. 最下部：必殺技とフィーバーのボタン
            HStack {
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

                FeverButtonComponent(canUse: me.canUseFever, endsAt: viewModel.feverEndsAt) {
                    viewModel.useFever()
                }
            }
        }
        .padding()
        .background {
            BattleArenaComponent(
                myMonster: myMonster,
                opponentMonster: opponentMonster,
                myIdle: idleAnimation(of: me),
                opponentIdle: idleAnimation(of: opponent),
                myAnimation: myAnimation,
                opponentAnimation: opponentAnimation,
                hitOnOpponent: viewModel.lastHitOnOpponent,
                hitOnMe: viewModel.lastHitOnMe,
                danger: viewModel.incomingDanger,
                isFeverActive: viewModel.feverEndsAt != nil,
                isVictory: viewModel.outcome == .won,
                isVisible: isVisible
            )
            // 攻撃を受けたら、カメラの映像ごと揺らす（視差効果を減らす設定のときは揺らさない）
            .shake(trigger: reduceMotion ? nil : viewModel.lastHitOnMe?.id)
        }
    }

    private func onHitOnOpponent() {
        guard let hit = viewModel.lastHitOnOpponent, let opponent = viewModel.opponent else { return }
        if hit.isSpecial || hit.isFinishing {
            lastFlashHitOnOpponent = hit
        }
        if hit.isSpecial {
            mySpecialEndsAt = .now + Self.specialDuration(of: myMonster)
            myAnimation = attackAnimation(of: myMonster, hit: hit)
        } else if Date.now >= mySpecialEndsAt {
            myAnimation = attackAnimation(of: myMonster, hit: hit)
        }
        if opponent.hp == 0 || Date.now >= opponentSpecialEndsAt {
            opponentAnimation = reactionAnimation(hp: opponent.hp, hit: hit)
        }
        comboCount += 1
        playImpact(of: hit)
    }

    private func onHitOnMe() {
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

    /// 決着が確定したら、勝った側が喜ぶ
    private func onOutcome() {
        guard let outcome = viewModel.outcome, let me = viewModel.me, let opponent = viewModel.opponent else { return }
        if outcome == .won {
            BattleSoundPlayer.shared.play(.victory)
        }
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

    /// 画面全体に重ねる演出（フィーバー、相手の必殺技の予告、画面の光、勝利、結果）
    @ViewBuilder
    private var effects: some View {
        ZStack {
            // フィーバー中は、画面の縁を金色に光らせる。始まったときに「FEVER!」を出す
            if viewModel.feverEndsAt != nil {
                FeverComponent()
            }
            // 相手の必殺技の予告
            if let danger = viewModel.incomingDanger {
                DangerComponent()
                    .id(danger.id)
            }
            // 必殺技やとどめが当たった瞬間（溜めのあと）、画面全体を光らせる。とどめは白く光らせる
            if let hit = lastFlashHitOnOpponent {
                FlashComponent(color: hit.isFinishing ? .white : .yellow, delay: hit.impactDelay)
                    .id(hit.id)
            }
            // 勝ちが確定したら「VICTORY!」を出し、少し見せてから結果を全面に出す
            // 勝ったかどうかは、サーバーで確定した結果（outcome）だけで決める
            if let outcome = viewModel.outcome {
                if isResultShown {
                    BattleResultComponent(outcome: outcome, opponentName: opponent.name) {
                        viewModel.leaveBattle()
                    }
                    .transition(.opacity)
                } else if outcome == .won {
                    VictoryComponent()
                        .transition(.opacity)
                }
            }
        }
    }

    /// AR の中でモンスターが光るのと同じタイミングで、音を鳴らして振動させる
    /// 次の攻撃で取り消さない（通常攻撃が必殺技の溜めの途中で当たっても、必殺技の音を鳴らす）
    private func playImpact(of hit: BattleViewModel.Hit) {
        let sound: BattleSoundPlayer.Sound = if hit.isFinishing {
            .finishHit
        } else if hit.isSpecial {
            .specialHit
        } else if hit.isFever {
            .feverHit
        } else {
            .hit
        }
        Task {
            try? await Task.sleep(for: .seconds(hit.impactDelay))
            impactOnOpponent = hit
            BattleSoundPlayer.shared.play(sound)
        }
    }

    /// 相手に当たった瞬間の振動。通常攻撃は連打しても疲れないよう軽く短く、必殺技ととどめは重く
    private var impactFeedback: SensoryFeedback? {
        guard let hit = impactOnOpponent else { return nil }
        if hit.isSpecial || hit.isFinishing { return .impact(weight: .heavy, intensity: 1) }
        return .impact(flexibility: .rigid, intensity: hit.isFever ? 1 : 0.8)
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
    /// とどめのときは、当たった瞬間に少し止まってから（ヒットストップ）、ゆっくり倒れる
    private func reactionAnimation(hp: Int, hit: BattleViewModel.Hit) -> MonsterAnimationRequest {
        hp == 0
            ? MonsterAnimationRequest(
                animations: [.death],
                delay: hit.impactDelay + BattleViewModel.Hit.hitStopDuration,
                ending: .staysAtEnd,
                speed: BattleViewModel.Hit.finishingDeathSpeed
            )
            : MonsterAnimationRequest(animations: [.hitReact], delay: hit.impactDelay)
    }
}

private struct TapRipple {
    let id = UUID()
    let location: CGPoint
}
