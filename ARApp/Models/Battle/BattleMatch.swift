//
//  BattleMatch.swift
//  ARApp
//

/// マッチングした対戦の情報
struct BattleMatch {
    /// 対戦の ID。攻撃を送る・受け取るときに使う
    let id: String
    let myMonster: Monster
    let opponentMonster: Monster
}
