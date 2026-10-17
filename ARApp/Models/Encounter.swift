//
//  Encounter.swift
//  ARApp
//

import Foundation

/// AR にモンスターが 1 回出てくること
/// 同じ種類のモンスターが続けて出ても別の出現として見分けられるように、出現ごとの ID を持つ
struct Encounter: Identifiable {
    let id = UUID()
    let monster: Monster
}

extension Encounter {
    /// 一覧からランダムに 1 体選んで出す（`Monster.all` は空ではない）
    static func random() -> Encounter {
        Encounter(monster: Monster.all.randomElement()!)
    }
}
