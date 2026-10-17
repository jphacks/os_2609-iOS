//
//  BattleMove.swift
//  ARApp
//

/// 1 ターンぶんの攻撃の結果。対戦相手にはこれだけを送る
/// ダメージは送らず、受け取った側も同じ計算で求める
struct BattleMove {
    let attackType: AttackType
    /// STOP を押した順の判定。当てられなかったエリアのぶんは最後に MISS を足す
    let judgements: [TimingJudgement]
}
