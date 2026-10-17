//
//  WildMonster.swift
//  ARApp
//

import Foundation

/// 会場のどこかに出現している野生のモンスター 1 体
/// 同じ種類が 2 体出ても区別できるように、出現するたびに別の id が付く
struct WildMonster: Identifiable {
    let id: UUID
    let monster: Monster
    /// 出現している地点（`Location.id`）
    let locationID: Location.ID
    /// この時刻を過ぎると逃げる
    let escapesAt: Date
}
