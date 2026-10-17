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

    /// 登録済みの地点。位置は `VenueMap.png` 上の割合で表す
    /// 各 fingerprint は地点1〜6で実測した値。並びは BeaconA〜D
    static let registered = [
        Location(id: "point_1", name: "1", position: MapPosition(x: 0.113, y: 0.899),
                 fingerprint: [-54, -100, -75, -68]),
        Location(id: "point_2", name: "2", position: MapPosition(x: 0.127, y: 0.653),
                 fingerprint: [-65, -100, -69, -84]),
        Location(id: "point_3", name: "3", position: MapPosition(x: 0.107, y: 0.378),
                 fingerprint: [-72, -100, -74, -63]),
        Location(id: "point_4", name: "4", position: MapPosition(x: 0.414, y: 0.361),
                 fingerprint: [-86, -90, -71, -78]),
        Location(id: "point_5", name: "5", position: MapPosition(x: 0.418, y: 0.623),
                 fingerprint: [-71, -100, -74, -74]),
        Location(id: "point_6", name: "6", position: MapPosition(x: 0.479, y: 0.947),
                 fingerprint: [-81, -82, -77, -100]),
    ]
}
