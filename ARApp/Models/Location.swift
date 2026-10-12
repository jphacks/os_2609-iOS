//
//  Location.swift
//  ARApp
//

import Foundation

/// 現在地の候補になる地点と、そこで事前に測った RSSI のパターン（フィンガープリント）
struct Location: Identifiable {
    let name: String
    /// この地点での各ビーコンの RSSI（dBm）。並びは `Location.beaconNames` と同じ
    let fingerprint: [Int]

    var id: String { name }
}

extension Location {
    /// 位置推定に使うビーコンの名前。RSSI の配列は常にこの順に並べる
    static let beaconNames = ["BeaconA", "BeaconB", "BeaconC", "BeaconD"]

    /// 登録済みの地点。数値は仮のものなので、実際の場所で測った値に置き換える
    static let registered = [
        Location(name: "受付", fingerprint: [-52, -67, -81, -73]),
        Location(name: "展示エリアA", fingerprint: [-68, -48, -71, -84]),
        Location(name: "展示エリアB", fingerprint: [-80, -66, -45, -72]),
        Location(name: "階段前", fingerprint: [-76, -70, -61, -47]),
    ]
}
