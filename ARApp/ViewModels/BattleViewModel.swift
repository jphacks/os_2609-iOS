//
//  BattleViewModel.swift
//  ARApp
//

import Foundation
import Observation

/// 対戦画面の状態と、バトルの進行
/// バトルの画面を開いている人どうしを自動でマッチングし、お互いにタップで攻撃し合う
/// 画面を開いている間は、相手が見つかるまで自動で待ち続ける
/// 自分の行動はすぐに反映して相手に送り、相手の行動は届いた順に反映する（どちらも BattleEngine で計算する）
@Observable
final class BattleViewModel {
    enum Phase {
        /// 対戦相手を待っていない（画面を開いていない、または通信に失敗してやり直すのを待っている）
        case lobby
        /// 対戦相手を待っている
        case searching
        /// 相手探しをやめて、片付けが終わるのを待っている
        case cancellingSearch
        /// 対戦中（決着がついて結果を出している間も含む）
        case fighting
    }

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

    /// 状態の中で自分と相手を見分ける ID。どちらの端末でも、自分が myID になる
    private static let myID: FighterID = "me"
    private static let opponentID: FighterID = "opponent"

    /// 次の対戦で使う自分のモンスター
    /// 【仮】今はランダム。捕まえたモンスターから選べるようにしたら、ここと leaveBattle() の選び直しを置き換える
    private(set) var myMonster = Monster.all.randomElement()!
    /// 対戦中の相手のモンスター。マッチングするまでは nil
    private(set) var opponentMonster: Monster?
    private(set) var phase = Phase.lobby
    /// 対戦中の状態。マッチングするまでは nil
    private(set) var state: BattleState?
    /// 確定した決着。決着がついていない、またはまだ確定していなければ nil
    private(set) var outcome: Outcome?
    /// 通信に失敗したときに出すメッセージ
    private(set) var errorMessage: String?
    /// 最後に相手へ当たった攻撃。View はこれが変わるたびに演出を流す
    private(set) var lastHitOnOpponent: Hit?
    /// 最後に自分へ当たった攻撃
    private(set) var lastHitOnMe: Hit?
    /// この時刻になるまで次の通常攻撃はできない（クールダウン）
    private var nextNormalAttackAt = ContinuousClock.now
    /// バトルの画面が表示されていて、対戦相手を待ちたいか
    private var wantsToWait = false

    /// 通信に失敗したとき、もう一度相手を待ち始めるまでの時間（秒）
    private static let retryDelay: Double = 3

    private let service: any BattleService
    private var searchTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var finishTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    /// 対戦をやめたときの片付け。次の相手探しは、これが終わってから始める
    private var leaveTask: Task<Void, Never>?

    init(service: any BattleService) {
        self.service = service
    }

    var me: Fighter? { state?.fighters[Self.myID] }
    var opponent: Fighter? { state?.fighters[Self.opponentID] }

    /// バトルの画面が表示されたときに呼ぶ。対戦相手を待ち始める
    func startWaiting() {
        wantsToWait = true
        findOpponentIfWanted()
    }

    /// バトルの画面が隠れたときに呼ぶ。対戦相手を待つのをやめる（対戦中ならそのまま続ける）
    func stopWaiting() {
        wantsToWait = false
        retryTask?.cancel()
        retryTask = nil
        cancelSearch()
    }

    /// 画面が表示されていて、ロビーにいれば、対戦相手を待ち始める
    private func findOpponentIfWanted() {
        guard wantsToWait, phase == .lobby else { return }
        phase = .searching
        errorMessage = nil
        searchTask = Task { [leaveTask] in
            // 前の対戦の片付けが終わる前に始めると、片付けが新しい相手探しの状態まで消してしまう
            await leaveTask?.value
            do {
                let opponentMonster = try await service.findOpponent(monster: myMonster)
                guard !Task.isCancelled else { return }
                startBattle(against: opponentMonster)
            } catch {
                // 自分でやめたとき（cancelSearch）はエラーにしない
                // キャンセルされると、CancellationError 以外のエラーが投げられることもある
                guard !Task.isCancelled else { return }
                fail(error)
            }
        }
    }

    /// 対戦相手を探すのをやめる
    /// 片付けが終わってからロビーに戻る
    /// 終わる前に次の相手探しを始めると、前の片付けが新しい相手探しの状態まで消してしまうため
    /// 片付けている間に画面がまた表示されていたら、片付け終わってから待ち直す
    private func cancelSearch() {
        guard phase == .searching, let searchTask else { return }
        phase = .cancellingSearch
        searchTask.cancel()
        Task {
            await searchTask.value
            // キャンセルと同時にマッチングが終わっていた場合に備えて、対戦からも抜ける
            await service.leave()
            phase = .lobby
            findOpponentIfWanted()
        }
    }

    /// 画面がタップされたときに呼ぶ。クールダウン中は何も起きない
    func attack() {
        let now = ContinuousClock.now
        guard now >= nextNormalAttackAt else { return }
        if perform(.normalAttack) {
            nextNormalAttackAt = now + .seconds(BattleEngine.normalAttackCooldown)
        }
    }

    /// 必殺技ボタンが押されたときに呼ぶ。ゲージが満タンでなければ何も起きない
    func useSpecial() {
        perform(.specialAttack)
    }

    /// 結果を見終わったときに呼ぶ。ロビーに戻り、次の対戦相手を待ち始める。次の対戦では別のモンスターを使う
    func leaveBattle() {
        reset()
        findOpponentIfWanted()
    }

    /// 対戦や相手探しをやめて、ロビーの状態に戻す
    private func reset() {
        searchTask?.cancel()
        receiveTask?.cancel()
        finishTask?.cancel()
        finishTask = nil
        leaveTask = Task { await service.leave() }
        state = nil
        opponentMonster = nil
        outcome = nil
        lastHitOnOpponent = nil
        lastHitOnMe = nil
        myMonster = Monster.all.randomElement()!
        phase = .lobby
    }

    private func startBattle(against opponentMonster: Monster) {
        self.opponentMonster = opponentMonster
        state = BattleState(
            Fighter(id: Self.myID, name: myMonster.name, maxHP: BattleEngine.maxHP),
            Fighter(id: Self.opponentID, name: opponentMonster.name, maxHP: BattleEngine.maxHP)
        )
        nextNormalAttackAt = .now
        phase = .fighting
        receiveOpponentActions()
    }

    /// 決着がつくまで相手の行動を受け取って反映する
    private func receiveOpponentActions() {
        receiveTask = Task {
            do {
                for try await action in service.opponentActions() {
                    guard var state,
                          let damage = BattleEngine.apply(action, by: Self.opponentID, to: &state)
                    else { continue }
                    self.state = state
                    lastHitOnMe = Hit(damage: damage, isSpecial: action == .specialAttack)
                    if state.winner != nil { break }
                }
                // 自分の端末で決着がついた、または相手の端末で決着がついて受け取りが終わった
                guard !Task.isCancelled else { return }
                confirmOutcome()
            } catch {
                // 自分でやめたとき（leaveBattle）や、自分の攻撃で決着がついたときはエラーにしない
                guard !Task.isCancelled else { return }
                fail(error)
            }
        }
    }

    /// 自分の行動を反映して相手に伝える。行えたら true
    @discardableResult
    private func perform(_ action: BattleAction) -> Bool {
        guard phase == .fighting, finishTask == nil, var state,
              let damage = BattleEngine.apply(action, by: Self.myID, to: &state)
        else { return false }
        self.state = state
        lastHitOnOpponent = Hit(damage: damage, isSpecial: action == .specialAttack)
        service.send(action)
        if state.winner != nil {
            confirmOutcome()
        }
        return true
    }

    /// 相手の行動の受け取りをやめて、決着を確定させる
    private func confirmOutcome() {
        guard finishTask == nil else { return }
        receiveTask?.cancel()
        let iWon = state?.winner == Self.myID
        finishTask = Task {
            do {
                let confirmed = try await service.finish(iWon: iWon)
                guard !Task.isCancelled else { return }
                outcome = confirmed ? .won : .lost
            } catch {
                guard !Task.isCancelled else { return }
                fail(error)
            }
        }
    }

    /// 相手がいなくなった・通信に失敗したときは、対戦をやめてロビーに戻り、少し待ってから相手を待ち直す
    /// すぐに待ち直すと、通信できない間ずっと失敗をくり返してしまうため
    private func fail(_ error: Error) {
        // 【開発用】原因を調べるためのログ。リリースするときに消してよい
        print("対戦の通信に失敗しました: \(error)")
        reset()
        errorMessage = "通信に失敗しました。もう一度相手を探します"
        retryTask = Task {
            try? await Task.sleep(for: .seconds(Self.retryDelay))
            guard !Task.isCancelled else { return }
            findOpponentIfWanted()
        }
    }
}
