//
//  Location.swift
//  ARApp
//

import Foundation

/// 現在地の候補になる地点と、そこで事前に測った RSSI のパターン（フィンガープリント）
struct Location: Identifiable {
    /// 場所 ID。マップの `MapSpot.id` と同じ値にする
    let id: String
    let name: String
    /// この地点での各ビーコンの RSSI（dBm）。並びは `Location.beaconNames` と同じ
    let fingerprint: [Int]
}

extension Location {
    /// 位置推定に使うビーコンの名前。RSSI の配列は常にこの順に並べる
    static let beaconNames = ["BeaconA", "BeaconB", "BeaconC", "BeaconD"]

    /// 登録済みの地点。数値は仮のものなので、実際の場所で測った値に置き換える
    static let registered = [
        Location(id: "entrance", name: "入口", fingerprint: [-52, -67, -81, -73]),
        Location(id: "booth_a", name: "ブースA", fingerprint: [-68, -48, -71, -84]),
        Location(id: "booth_b", name: "ブースB", fingerprint: [-80, -66, -45, -72]),
        Location(id: "stairs", name: "階段", fingerprint: [-76, -70, -61, -47]),
        Location(id: "boss_zone", name: "ボスゾーン", fingerprint: [-66, -78, -74, -58]),
    ]
}
