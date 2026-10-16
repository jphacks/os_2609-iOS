//
//  Location.swift
//  ARApp
//

import Foundation

/// 現在地の候補になる地点
/// 位置推定に使う RSSI のパターン（フィンガープリント）と、マップに表示する位置をまとめて持つ
struct Location: Identifiable {
    /// 場所 ID（例："entrance"）
    let id: String
    let name: String
    /// マップ上でこの地点を表示する位置
    let position: MapPosition
    /// この地点での各ビーコンの RSSI（dBm）。並びは `Location.beaconNames` と同じ
    let fingerprint: [Int]
}

extension Location {
    /// 位置推定に使うビーコンの名前。RSSI の配列は常にこの順に並べる
    static let beaconNames = ["BeaconA", "BeaconB", "BeaconC", "BeaconD"]

    /// 登録済みの地点。位置は会場の見取り図に合わせて調整する
    /// RSSI の数値は仮のものなので、実際の場所で測った値に置き換える
    static let registered = [
        Location(id: "entrance", name: "入口", position: MapPosition(x: 0.5, y: 0.88),
                 fingerprint: [-52, -67, -81, -73]),
        Location(id: "booth_a", name: "ブースA", position: MapPosition(x: 0.22, y: 0.58),
                 fingerprint: [-68, -48, -71, -84]),
        Location(id: "booth_b", name: "ブースB", position: MapPosition(x: 0.78, y: 0.58),
                 fingerprint: [-80, -66, -45, -72]),
        Location(id: "stairs", name: "階段", position: MapPosition(x: 0.8, y: 0.2),
                 fingerprint: [-76, -70, -61, -47]),
        Location(id: "boss_zone", name: "ボスゾーン", position: MapPosition(x: 0.32, y: 0.2),
                 fingerprint: [-66, -78, -74, -58]),
    ]
}
