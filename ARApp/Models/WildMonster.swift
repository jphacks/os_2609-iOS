//
//  WildMonster.swift
//  ARApp
//

import Foundation

/// 捕獲画面で出現している野生のモンスター 1 体
/// 同じ種類が出ても区別できるように、出現するたびに別の id が付く
struct WildMonster: Identifiable {
    let id = UUID()
    let monster: Monster
}
