//
//  RaidSpot.swift
//  ARApp
//

import Foundation

/// マップ上のレイド地点。ボスモンスターと戦える場所
struct RaidSpot: Identifiable {
    let id: String
    /// ボスモンスターの名前
    let bossName: String
    let position: MapPosition
}

extension RaidSpot {
    /// 仮のレイド地点。ボスゾーンの部屋の中に置く
    static let samples = [
        RaidSpot(id: "raid_1", bossName: "ドラゴン", position: MapPosition(x: 0.32, y: 0.08)),
    ]
}
