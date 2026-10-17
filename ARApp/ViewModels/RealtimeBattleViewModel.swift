//
//  RealtimeBattleViewModel.swift
//  ARApp
//

import Foundation
import Observation

/// リアルタイムバトル画面の状態と、バトルの進行
/// 状態は ID で持ち、画面には「自分」と「相手」に変換して渡す
@Observable
final class RealtimeBattleViewModel {
    /// 自分から見た決着
    enum Outcome {
        case won
        case lost
    }

    /// 攻撃が当たった出来事。画面の演出（ダメージ表示、揺れ）のきっかけになる
    struct Hit: Identifiable {
        let id = UUID()
        let damage: Int
        /// 必殺技による攻撃か（演出を派手にする）
        let isSpecial: Bool
    }

    private let myFighter: RealtimeFighter
    private let opponent: BattleOpponent

    private(set) var state: RealtimeBattleState
    /// バトルごとに変わる ID。リトライで変わると、View の .task(id:) が相手の行動の受け取りをやり直す
    private(set) var battleID = UUID()
    /// 最後に相手へ当たった攻撃。View はこれが変わるたびに演出を流す
    private(set) var lastHitOnOpponent: Hit?
    /// 最後に自分へ当たった攻撃
    private(set) var lastHitOnMe: Hit?
    /// この時刻になるまで次の通常攻撃はできない（クールダウン）
    private var nextNormalAttackAt = ContinuousClock.now

    init(
        me: RealtimeFighter = RealtimeFighter(id: "me", name: "ナイト", maxHP: 100),
        opponent: BattleOpponent
    ) {
        myFighter = me
        self.opponent = opponent
        state = RealtimeBattleState(me, opponent.fighter)
    }

    var me: RealtimeFighter { state.fighters[myFighter.id] ?? myFighter }
    var opponentFighter: RealtimeFighter { state.fighters[opponent.fighter.id] ?? opponent.fighter }

    var outcome: Outcome? {
        guard let winner = state.winner else { return nil }
        return winner == myFighter.id ? .won : .lost
    }

    /// 画面がタップされたときに呼ぶ。クールダウン中は何も起きない
    func attack() {
        let now = ContinuousClock.now
        guard now >= nextNormalAttackAt else { return }
        if perform(.normalAttack) {
            nextNormalAttackAt = now + .seconds(RealtimeBattleEngine.normalAttackCooldown)
        }
    }

    /// 必殺技ボタンが押されたときに呼ぶ。ゲージが満タンでなければ何も起きない
    func useSpecial() {
        perform(.specialAttack)
    }

    /// 初期状態に戻して、もう一度バトルする
    func retry() {
        state = RealtimeBattleState(myFighter, opponent.fighter)
        lastHitOnOpponent = nil
        lastHitOnMe = nil
        nextNormalAttackAt = .now
        battleID = UUID()
    }

    /// 決着がつくまで相手の行動を受け取って反映する
    /// View の .task から呼ぶ。画面が消えると Task ごとキャンセルされるので、再表示しても重複して動かない
    func receiveOpponentActions() async {
        for await action in opponent.actions() {
            guard let damage = RealtimeBattleEngine.apply(action, by: opponent.fighter.id, to: &state) else { continue }
            lastHitOnMe = Hit(damage: damage, isSpecial: action == .specialAttack)
            if state.winner != nil { return }
        }
    }

    /// 自分の行動を反映して相手に伝える。行えたら true
    @discardableResult
    private func perform(_ action: BattleAction) -> Bool {
        guard let damage = RealtimeBattleEngine.apply(action, by: myFighter.id, to: &state) else { return false }
        lastHitOnOpponent = Hit(damage: damage, isSpecial: action == .specialAttack)
        opponent.send(action)
        return true
    }
}
