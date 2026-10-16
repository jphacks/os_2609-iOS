//
//  MapSpot.swift
//  ARApp
//

import Foundation

/// マップ上の位置。マップの幅・高さに対する割合（0〜1）で表す
/// 画面サイズに依存しないので、どの端末でも同じ場所に表示できる
struct MapPosition: Equatable {
    /// 0 が左端、1 が右端
    let x: Double
    /// 0 が上端、1 が下端
    let y: Double
}

/// 現在地として推定される場所と、マップ上でその場所を表示する位置
struct MapSpot: Identifiable {
    /// 位置推定で返ってくる場所 ID（例："entrance"）
    let id: String
    let name: String
    let position: MapPosition
}

extension MapSpot {
    /// 会場の場所一覧。位置は会場の見取り図に合わせて調整する
    static let all = [
        MapSpot(id: "entrance", name: "入口", position: MapPosition(x: 0.5, y: 0.88)),
        MapSpot(id: "booth_a", name: "ブースA", position: MapPosition(x: 0.22, y: 0.58)),
        MapSpot(id: "booth_b", name: "ブースB", position: MapPosition(x: 0.78, y: 0.58)),
        MapSpot(id: "stairs", name: "階段", position: MapPosition(x: 0.8, y: 0.2)),
        MapSpot(id: "boss_zone", name: "ボスゾーン", position: MapPosition(x: 0.32, y: 0.2)),
    ]
}
