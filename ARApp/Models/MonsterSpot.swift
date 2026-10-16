//
//  MonsterSpot.swift
//  ARApp
//

import Foundation

/// マップ上に出現しているモンスター
struct MonsterSpot: Identifiable {
    let id: String
    let name: String
    let position: MapPosition
}

/// マップ上のレイド地点。ボスモンスターと戦える場所
struct RaidSpot: Identifiable {
    let id: String
    /// ボスモンスターの名前
    let bossName: String
    let position: MapPosition
}

extension MonsterSpot {
    /// 仮の出現データ。将来はサーバーから受け取る
    static let samples = [
        MonsterSpot(id: "monster_1", name: "ドッグ", position: MapPosition(x: 0.12, y: 0.72)),
        MonsterSpot(id: "monster_2", name: "キャット", position: MapPosition(x: 0.88, y: 0.45)),
        MonsterSpot(id: "monster_3", name: "パンダ", position: MapPosition(x: 0.62, y: 0.32)),
    ]
}

extension RaidSpot {
    /// 仮のレイド地点。ボスゾーンの部屋の中に置く
    static let samples = [
        RaidSpot(id: "raid_1", bossName: "ドラゴン", position: MapPosition(x: 0.32, y: 0.08)),
    ]
}
