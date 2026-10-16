//
//  BattleState.swift
//  ARApp
//

/// 対戦の決着（自分から見た結果）
enum BattleOutcome {
    case won
    case lost
    case draw
}

/// 対戦に参加しているプレイヤー 1 人ぶんの状態
struct BattleFighter {
    let monster: Monster
    let profile: BattleProfile
    private(set) var hp: Int
    /// PERFECT が続いている回数。GOOD か MISS で 0 に戻る。ターンをまたいで続く
    private(set) var combo = 0

    init(monster: Monster) {
        self.monster = monster
        profile = .of(monster)
        hp = profile.maxHP
    }

    /// 残り HP の割合（0〜1）。ターン制限で決着するときに比べる
    var hpRatio: Double { Double(hp) / Double(profile.maxHP) }

    /// 判定 1 回ぶんのダメージ。combo はこの判定を含めた連続 PERFECT の回数
    static func damage(for judgement: TimingJudgement, attackType: AttackType, combo: Int) -> Int {
        Int((Double(judgement.baseDamage) * attackType.damageMultiplier * comboMultiplier(combo)).rounded())
    }

    /// 連続 PERFECT によるダメージ倍率。2 回目から 0.25 ずつ上がり、最大 2 倍
    static func comboMultiplier(_ combo: Int) -> Double {
        min(1 + 0.25 * Double(max(combo - 1, 0)), 2)
    }

    /// 1 ターンぶんの攻撃をして、コンボを更新する。相手に与えるダメージの合計を返す
    mutating func attack(with move: BattleMove) -> Int {
        var total = 0
        for judgement in move.judgements {
            combo = judgement == .perfect ? combo + 1 : 0
            total += Self.damage(for: judgement, attackType: move.attackType, combo: combo)
        }
        return total
    }

    mutating func takeDamage(_ damage: Int) {
        hp = max(hp - damage, 0)
    }
}

/// 対戦の進み具合
/// 2 人とも同じ攻撃の結果（BattleMove）から同じ計算をするので、どちらの端末でも結果が食い違わない
/// 乱数は使わない
struct BattleState {
    /// このターン数で決着しなければ、残り HP の割合が多いほうの勝ち
    static let turnLimit = 10

    private(set) var me: BattleFighter
    private(set) var opponent: BattleFighter
    /// 今のターン（1 から）
    private(set) var turn = 1
    /// 決着がついていなければ nil
    private(set) var outcome: BattleOutcome?

    init(myMonster: Monster, opponentMonster: Monster) {
        me = BattleFighter(monster: myMonster)
        opponent = BattleFighter(monster: opponentMonster)
    }

    /// 2 人の攻撃がそろったら、同時にダメージを与え合って次のターンへ進む
    /// 与えたダメージと受けたダメージを返す
    mutating func resolveTurn(myMove: BattleMove, opponentMove: BattleMove) -> (dealt: Int, taken: Int) {
        guard outcome == nil else { return (0, 0) }
        let dealt = me.attack(with: myMove)
        let taken = opponent.attack(with: opponentMove)
        opponent.takeDamage(dealt)
        me.takeDamage(taken)

        switch (me.hp, opponent.hp) {
        case (0, 0): outcome = .draw
        case (_, 0): outcome = .won
        case (0, _): outcome = .lost
        default:
            if turn >= Self.turnLimit {
                outcome = me.hpRatio > opponent.hpRatio ? .won : me.hpRatio < opponent.hpRatio ? .lost : .draw
            } else {
                turn += 1
            }
        }
        return (dealt, taken)
    }
}
