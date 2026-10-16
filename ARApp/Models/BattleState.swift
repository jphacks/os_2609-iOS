//
//  BattleState.swift
//  ARApp
//

/// バトルの決着
enum BattleOutcome {
    /// HP を 0 にして倒した
    case defeated
    /// 捕獲に成功した
    case captured
    /// プレイヤーの HP が 0 になった
    case lost
    /// ターン制限までに決着せず逃げられた
    case escaped
}

/// バトルの進み具合。将来サーバーと同期するときは、この値をやり取りする想定
/// 乱数は使わず、捕獲の成否も外から渡された値で決める（同じ入力なら必ず同じ結果になる）
struct BattleState {
    static let playerMaxHP = 100

    let profile: BattleProfile
    private(set) var monsterHP: Int
    private(set) var playerHP = BattleState.playerMaxHP
    /// 今のターン（1 から）
    private(set) var turn = 1
    /// PERFECT が続いている回数。GOOD か MISS で 0 に戻る
    private(set) var combo = 0
    /// 決着がついていなければ nil
    private(set) var outcome: BattleOutcome?

    init(profile: BattleProfile) {
        self.profile = profile
        monsterHP = profile.maxHP
    }

    /// HP が半分以下になると怒って、カーソルが速く、判定エリアが狭くなる
    var isEnraged: Bool { monsterHP * 2 <= profile.maxHP }

    /// 連続 PERFECT によるダメージ倍率。2 回目から 0.25 ずつ上がり、最大 2 倍
    var comboMultiplier: Double {
        min(1 + 0.25 * Double(max(combo - 1, 0)), 2)
    }

    /// 捕獲の成功率。HP が減るほど上がる（満タンで 10%、残りわずかで 95% 近く）
    var captureChance: Double {
        0.1 + 0.85 * (1 - Double(monsterHP) / Double(profile.maxHP))
    }

    /// 判定 1 回ぶんのダメージを与える。与えたダメージを返す
    mutating func hit(_ judgement: TimingJudgement, attackType: AttackType) -> Int {
        guard outcome == nil else { return 0 }
        combo = judgement == .perfect ? combo + 1 : 0
        let damage = Int((Double(judgement.baseDamage) * attackType.damageMultiplier * comboMultiplier).rounded())
        monsterHP = max(monsterHP - damage, 0)
        if monsterHP == 0 {
            outcome = .defeated
        }
        return damage
    }

    /// ターンの判定（エリアごと。当てられなかったエリアは MISS）から反撃のダメージを決める
    /// 全部 PERFECT ならかわす、MISS があれば全力、それ以外は半分
    func counterDamage(for judgements: [TimingJudgement]) -> Int {
        if judgements.contains(.miss) { return profile.attackPower }
        if judgements.allSatisfy({ $0 == .perfect }) { return 0 }
        return profile.attackPower / 2
    }

    /// ターンの終わりにモンスターの反撃を受け、次のターンへ進む
    mutating func receiveCounterattack(damage: Int) {
        guard outcome == nil else { return }
        playerHP = max(playerHP - damage, 0)
        if playerHP == 0 {
            outcome = .lost
        } else if turn >= profile.turnLimit {
            outcome = .escaped
        } else {
            turn += 1
        }
    }

    /// 捕獲を試みる。roll は 0〜1 の乱数で、成功率より小さければ成功
    mutating func tryCapture(roll: Double) -> Bool {
        guard outcome == nil else { return false }
        guard roll < captureChance else { return false }
        outcome = .captured
        return true
    }
}
