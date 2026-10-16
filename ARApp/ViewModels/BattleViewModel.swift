//
//  BattleViewModel.swift
//  ARApp
//

import Foundation
import Observation

/// 対戦画面の状態と、ターンの進行
/// 毎ターン 2 人が同時に攻撃し、相手の攻撃が届いたらまとめてダメージを反映する
/// カーソルの位置は保存せず、開始時刻からの経過時間で毎回計算する
@Observable
final class BattleViewModel {
    enum Phase {
        /// 対戦相手を探す前
        case lobby
        /// 対戦相手を探している
        case searching
        /// 攻撃方法を選んでいる
        case choosingAction
        /// カーソルが動いている
        case attacking
        /// 自分の攻撃を送り、相手の攻撃を待っている
        case waitingForOpponent
        /// ターンの結果を見せている
        case resolving
        /// 決着がついて、結果画面を出している
        case finished
    }

    /// 画面の演出（ダメージ表示、揺れ、振動）のきっかけになる出来事
    struct Event: Identifiable {
        enum Kind {
            case hit(TimingJudgement, damage: Int, combo: Int)
            case turnResolved(dealt: Int, taken: Int)
        }

        let id = UUID()
        let kind: Kind
    }

    /// 攻撃を選んでからカーソルが動き出すまでの時間（秒）
    static let leadTime: TimeInterval = 0.5
    /// ターンの結果を見せる時間（秒）
    static let resultDisplayDuration: TimeInterval = 1.2

    /// 次の対戦で使う自分のモンスター（今はランダム。あとで一覧から選べるようにする）
    private(set) var myMonster = Monster.all.randomElement()!
    /// 対戦中の状態。マッチングするまでは nil
    private(set) var battle: BattleState?
    private(set) var phase = Phase.lobby
    /// 通信に失敗したときに出すメッセージ
    private(set) var errorMessage: String?

    private(set) var attackType = AttackType.normal
    /// 今のターンのゲージ。最初の攻撃までは判定エリアなし
    private(set) var gauge = TimingGauge(traverseDuration: 1, zones: [])
    /// 今のターンのエリアごとの判定。まだ当てていないエリアは nil
    private(set) var zoneResults: [TimingJudgement?] = []
    /// 今のターンに STOP を押した順の判定
    private var tapJudgements: [TimingJudgement] = []
    /// 今のターンの連続 PERFECT の回数。ダメージの表示に使う
    private var turnCombo = 0

    var remainingTaps: Int { gauge.zones.count - tapJudgements.count }
    private(set) var lastEvent: Event?

    /// カーソルが左端を出発する時刻
    private(set) var startedAt = Date.now
    /// ヒットストップが終わる時刻。それまでカーソルは止まって見える
    private(set) var hitStopUntil = Date.distantPast
    /// カーソルを止めた時刻。動いている間は nil
    /// 最初は遠い過去にしておき、カーソルが左端に止まって見えるようにする
    private(set) var stoppedAt: Date? = .distantPast

    private let service: any BattleService
    private var searchTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var turnTask: Task<Void, Never>?

    init(service: any BattleService) {
        self.service = service
    }

    /// 指定した時刻でのカーソル位置（0〜1）
    func cursorPosition(at date: Date) -> Double {
        var time = max(date, hitStopUntil)
        if let stoppedAt {
            time = min(time, stoppedAt)
        }
        return gauge.cursorPosition(elapsed: time.timeIntervalSince(startedAt))
    }

    /// 同じ地点にいる対戦相手を探す
    func findOpponent(locationID: String) {
        guard phase == .lobby else { return }
        phase = .searching
        errorMessage = nil
        searchTask = Task {
            do {
                let match = try await service.findOpponent(locationID: locationID, monster: myMonster)
                guard !Task.isCancelled else { return }
                battle = BattleState(myMonster: match.myMonster, opponentMonster: match.opponentMonster)
                lastEvent = nil
                phase = .choosingAction
            } catch {
                // 自分でやめたとき（cancelSearch）はエラーにしない
                // キャンセルされると、CancellationError 以外のエラーが投げられることもある
                guard !Task.isCancelled else { return }
                fail(error)
            }
        }
    }

    /// 対戦相手を探すのをやめる
    func cancelSearch() {
        guard phase == .searching else { return }
        searchTask?.cancel()
        phase = .lobby
        Task { await service.leave() }
    }

    /// 攻撃方法を選んでターンを始める
    func startAttack(_ type: AttackType) {
        guard phase == .choosingAction, let battle else { return }
        attackType = type
        var generator = SystemRandomNumberGenerator()
        gauge = .random(profile: battle.me.profile, attackType: type, using: &generator)
        zoneResults = Array(repeating: nil, count: gauge.zones.count)
        tapJudgements = []
        turnCombo = battle.me.combo
        startedAt = Date.now.addingTimeInterval(Self.leadTime)
        hitStopUntil = .distantPast
        stoppedAt = nil
        phase = .attacking
        scheduleGaugeEnd()
    }

    /// STOP が押された瞬間の経過時間で判定する
    /// エリアの外（または当て済みのエリア）で押すと MISS。どちらでもタップを 1 回使う
    func stop(at date: Date = .now) {
        // ヒットストップ中の連打は受け付けない
        guard phase == .attacking, remainingTaps > 0, date >= hitStopUntil else { return }

        let judgement: TimingJudgement
        if let result = gauge.judge(elapsed: date.timeIntervalSince(startedAt)),
           zoneResults[result.zoneIndex] == nil {
            zoneResults[result.zoneIndex] = result.judgement
            judgement = result.judgement
        } else {
            judgement = .miss
        }
        record(judgement, at: date)
    }

    /// 対戦をやめてロビーに戻る。次の対戦では別のモンスターを使う
    func leaveBattle() {
        searchTask?.cancel()
        deadlineTask?.cancel()
        turnTask?.cancel()
        Task { await service.leave() }
        battle = nil
        myMonster = Monster.all.randomElement()!
        phase = .lobby
        gauge = TimingGauge(traverseDuration: 1, zones: [])
        zoneResults = []
        tapJudgements = []
        lastEvent = nil
        hitStopUntil = .distantPast
        stoppedAt = .distantPast
    }

    private func record(_ judgement: TimingJudgement, at date: Date) {
        tapJudgements.append(judgement)
        // ダメージが実際に入るのは相手の攻撃がそろってから。ここでは表示だけ
        turnCombo = judgement == .perfect ? turnCombo + 1 : 0
        let damage = BattleFighter.damage(for: judgement, attackType: attackType, combo: turnCombo)
        lastEvent = Event(kind: .hit(judgement, damage: damage, combo: turnCombo))

        // MISS でもカーソルは流れ続ける。タップを使い切ったらターン終了
        if remainingTaps == 0 {
            endAttack(at: date)
            return
        }

        // ヒットストップ：当てた瞬間にカーソルを少しだけ止めて手応えを出す
        // 開始時刻も同じだけ後ろにずらすので、止まっていた分だけカーソルの到着が遅れる
        let hitStop = Self.hitStopDuration(for: judgement)
        hitStopUntil = date.addingTimeInterval(hitStop)
        startedAt = startedAt.addingTimeInterval(hitStop)
        scheduleGaugeEnd()
    }

    /// カーソルが右端に着いたら、タップが残っていてもターンを終える
    private func scheduleGaugeEnd() {
        deadlineTask?.cancel()
        let end = startedAt.addingTimeInterval(gauge.traverseDuration)
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(end.timeIntervalSinceNow))
            guard let self, !Task.isCancelled, self.phase == .attacking else { return }
            self.endAttack(at: end)
        }
    }

    /// カーソルを止めて、自分の攻撃を送る。押さずに残ったタップのぶんは MISS として足す
    private func endAttack(at date: Date) {
        deadlineTask?.cancel()
        stoppedAt = date
        let move = BattleMove(
            attackType: attackType,
            judgements: tapJudgements + Array(repeating: .miss, count: remainingTaps)
        )
        phase = .waitingForOpponent
        exchange(move)
    }

    /// 自分の攻撃を送り、相手の攻撃が届いたら 2 人ぶんのダメージを反映する
    private func exchange(_ move: BattleMove) {
        guard let turn = battle?.turn else { return }
        turnTask = Task {
            do {
                try await service.send(move, turn: turn)
                let opponentMove = try await service.opponentMove(turn: turn)
                guard !Task.isCancelled, var battle else { return }
                let result = battle.resolveTurn(myMove: move, opponentMove: opponentMove)
                self.battle = battle
                lastEvent = Event(kind: .turnResolved(dealt: result.dealt, taken: result.taken))
                phase = .resolving

                try await Task.sleep(for: .seconds(Self.resultDisplayDuration))
                phase = battle.outcome == nil ? .choosingAction : .finished
            } catch {
                // 自分でやめたとき（leaveBattle）はエラーにしない
                guard !Task.isCancelled else { return }
                fail(error)
            }
        }
    }

    /// 相手が見つからない・相手がいなくなった・通信に失敗したときは、対戦をやめてロビーに戻る
    private func fail(_ error: Error) {
        print("対戦の通信に失敗しました: \(error)")
        leaveBattle()
        errorMessage = "対戦できませんでした。もう一度お試しください"
    }

    private static func hitStopDuration(for judgement: TimingJudgement) -> TimeInterval {
        switch judgement {
        case .perfect: 0.12
        case .good: 0.06
        case .miss: 0
        }
    }
}
