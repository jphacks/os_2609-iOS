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
    /// ブースA〜C は 2026-10-17 に試しに測った値（BeaconA〜C が起動、D は未起動。-100 は受信できなかったもの）
    static let registered = [
        Location(id: "entrance", name: "入口", position: MapPosition(x: 0.5, y: 0.88),
                 fingerprint: [-52, -67, -81, -73]),
        Location(id: "booth_a", name: "ブースA", position: MapPosition(x: 0.22, y: 0.58),
                 fingerprint: [-47, -100, -63, -100]),
        Location(id: "booth_b", name: "ブースB", position: MapPosition(x: 0.78, y: 0.58),
                 fingerprint: [-71, -86, -64, -100]),
        Location(id: "booth_c", name: "ブースC", position: MapPosition(x: 0.22, y: 0.2),
                 fingerprint: [-69, -100, -39, -100]),
        Location(id: "stairs", name: "階段", position: MapPosition(x: 0.8, y: 0.2),
                 fingerprint: [-76, -70, -61, -47]),
    ]
}
