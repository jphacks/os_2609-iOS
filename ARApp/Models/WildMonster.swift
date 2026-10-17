//
//  WildMonster.swift
//  ARApp
//

import Foundation

/// AR 空間に出現している野生のモンスター 1 体
/// 同じ種類が 2 体出ても区別できるように、出現するたびに別の id を付ける
struct WildMonster: Identifiable {
    let id = UUID()
    let monster: Monster
}
