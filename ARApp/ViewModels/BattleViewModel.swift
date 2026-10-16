//
//  BattleViewModel.swift
//  ARApp
//

import Foundation
import Observation

/// タイミングバトル画面の状態と、ターンの進行
/// カーソルの位置は保存せず、開始時刻からの経過時間で毎回計算する
@Observable
final class BattleViewModel {
    enum Phase {
        /// 攻撃方法を選んでいる
        case choosingAction
        /// カーソルが動いている
        case attacking
        /// 結果と反撃を見せている
        case resolving
    }

    /// 画面の演出（ダメージ表示、揺れ、振動）のきっかけになる出来事
    struct Event: Identifiable {
        enum Kind {
            case hit(TimingJudgement, damage: Int, combo: Int)
            case counterattack(damage: Int)
            case capture(succeeded: Bool)
        }

        let id = UUID()
        let kind: Kind
    }

    /// 攻撃を選んでからカーソルが動き出すまでの時間（秒）
    static let leadTime: TimeInterval = 0.5
    /// 結果や反撃を見せる時間（秒）
    static let resultDisplayDuration: TimeInterval = 0.9

    private(set) var monster: Monster
    private(set) var battle: BattleState
    private(set) var phase = Phase.choosingAction
    /// 決着がついて、結果画面を出すタイミングになったら true
    private(set) var isFinished = false

    private(set) var attackType = AttackType.normal
    /// 今のターンのゲージ。最初の攻撃までは判定エリアなし
    private(set) var gauge = TimingGauge(traverseDuration: 1, zones: [])
    /// 今のターンのエリアごとの判定。まだ当てていないエリアは nil
    private(set) var zoneResults: [TimingJudgement?] = []
    /// 今のターンに STOP を押した回数。エリアの数まで押せる
    private(set) var tapCount = 0

    var remainingTaps: Int { gauge.zones.count - tapCount }
    private(set) var lastEvent: Event?

    /// カーソルが左端を出発する時刻
    private(set) var startedAt = Date.now
    /// ヒットストップが終わる時刻。それまでカーソルは止まって見える
    private(set) var hitStopUntil = Date.distantPast
    /// カーソルを止めた時刻。動いている間は nil
    /// 最初は遠い過去にしておき、カーソルが左端に止まって見えるようにする
    private(set) var stoppedAt: Date? = .distantPast

    private var deadlineTask: Task<Void, Never>?
    private var resolveTask: Task<Void, Never>?

    init() {
        // `Monster.all` は空ではない
        let monster = Monster.all.randomElement()!
        self.monster = monster
        battle = BattleState(profile: .of(monster))
    }

    /// 指定した時刻でのカーソル位置（0〜1）
    func cursorPosition(at date: Date) -> Double {
        var time = max(date, hitStopUntil)
        if let stoppedAt {
            time = min(time, stoppedAt)
        }
        return gauge.cursorPosition(elapsed: time.timeIntervalSince(startedAt))
    }

    /// 攻撃方法を選んでターンを始める
    func startAttack(_ type: AttackType) {
        guard phase == .choosingAction, battle.outcome == nil else { return }
        attackType = type
        var generator = SystemRandomNumberGenerator()
        gauge = .random(profile: battle.profile, attackType: type, isEnraged: battle.isEnraged, using: &generator)
        zoneResults = Array(repeating: nil, count: gauge.zones.count)
        tapCount = 0
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
        tapCount += 1

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

    /// 攻撃のかわりに捕獲を試みる。失敗すると全力で反撃される
    func capture() {
        guard phase == .choosingAction, battle.outcome == nil else { return }
        let succeeded = battle.tryCapture(roll: Double.random(in: 0..<1))
        lastEvent = Event(kind: .capture(succeeded: succeeded))
        finishTurn(counterDamage: battle.profile.attackPower)
    }

    /// 新しいモンスターと最初から戦う
    func restartBattle() {
        deadlineTask?.cancel()
        resolveTask?.cancel()
        monster = Monster.all.randomElement()!
        battle = BattleState(profile: .of(monster))
        phase = .choosingAction
        isFinished = false
        gauge = TimingGauge(traverseDuration: 1, zones: [])
        zoneResults = []
        tapCount = 0
        lastEvent = nil
        hitStopUntil = .distantPast
        stoppedAt = .distantPast
    }

    private func record(_ judgement: TimingJudgement, at date: Date) {
        let damage = battle.hit(judgement, attackType: attackType)
        lastEvent = Event(kind: .hit(judgement, damage: damage, combo: battle.combo))

        // MISS でもカーソルは流れ続ける。タップを使い切るか倒したらターン終了
        if battle.outcome != nil || remainingTaps == 0 {
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

    /// カーソルを止めて反撃に進む。当てられなかったエリアは MISS 扱い
    private func endAttack(at date: Date) {
        stoppedAt = date
        let judgements = zoneResults.map { $0 ?? .miss }
        finishTurn(counterDamage: battle.counterDamage(for: judgements))
    }

    /// ターンを終える。決着がついていなければ、少し待ってからモンスターが反撃する
    private func finishTurn(counterDamage: Int) {
        deadlineTask?.cancel()
        phase = .resolving
        resolveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.resultDisplayDuration))
            guard let self, !Task.isCancelled else { return }

            if self.battle.outcome == nil {
                self.battle.receiveCounterattack(damage: counterDamage)
                self.lastEvent = Event(kind: .counterattack(damage: counterDamage))
                try? await Task.sleep(for: .seconds(Self.resultDisplayDuration))
                guard !Task.isCancelled else { return }
            }

            if self.battle.outcome == nil {
                self.phase = .choosingAction
            } else {
                self.isFinished = true
            }
        }
    }

    private static func hitStopDuration(for judgement: TimingJudgement) -> TimeInterval {
        switch judgement {
        case .perfect: 0.12
        case .good: 0.06
        case .miss: 0
        }
    }
}
