//
//  Stamina.swift
//  ARApp
//

import Foundation

/// スタミナ。通常攻撃とよけるたびに減り、時間がたつと回復する
/// 使い切ると、へとへとになって restDuration 秒の間休憩する（攻撃もよけるのもできない）
/// 連打し続けると休憩で手が止まるので、スタミナを見ながらリズムよく攻撃するほうが強い
/// クールダウンと同じく、入力した端末だけで数える（相手には送らない）
struct Stamina {
    static let max = 100.0
    static let attackCost = 15.0
    static let dodgeCost = 20.0
    /// 1 秒に回復する量。0.6 秒に 1 回の攻撃なら、減らずに続けられる
    static let recoveryPerSecond = 25.0
    /// へとへとになってから、また動けるようになるまでの時間（秒）。終わると満タンに戻る
    static let restDuration = 3.5

    /// 最後に増減したときの値と時刻。今の値は、ここから回復した分を足して求める
    private var storedValue = max
    private var storedAt = Date.now
    /// 休憩が終わる時刻。休憩していなければ nil か、過ぎた時刻
    private(set) var restEndsAt: Date?

    func isResting(at date: Date) -> Bool {
        restEndsAt.map { date < $0 } ?? false
    }

    /// date の時点の値。休憩中は、0 から満タンまで、休憩が終わるのに合わせて増えていく
    func value(at date: Date) -> Double {
        if let restEndsAt, date < restEndsAt {
            return Self.max * (1 - restEndsAt.timeIntervalSince(date) / Self.restDuration)
        }
        return min(storedValue + Self.recoveryPerSecond * date.timeIntervalSince(storedAt), Self.max)
    }

    /// 通常攻撃の分を使う。使い切ったら休憩を始める。休憩中でないことを確かめてから呼ぶ
    mutating func spendForAttack(at date: Date) {
        let remaining = value(at: date) - Self.attackCost
        if remaining <= 0 {
            let restEndsAt = date + Self.restDuration
            self.restEndsAt = restEndsAt
            // 休憩が終わった時点で満タンになっているようにする
            storedValue = Self.max
            storedAt = restEndsAt
        } else {
            storedValue = remaining
            storedAt = date
        }
    }

    /// よける分を使う。休憩中や、足りないときは使えずに false を返す（よけるだけでは休憩にならない）
    mutating func spendForDodge(at date: Date) -> Bool {
        let value = value(at: date)
        guard !isResting(at: date), value >= Self.dodgeCost else { return false }
        storedValue = value - Self.dodgeCost
        storedAt = date
        return true
    }
}
