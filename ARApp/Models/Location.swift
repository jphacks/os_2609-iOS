//
//  Location.swift
//  ARApp
//

import Foundation

/// BLE で推定するチェックポイント
/// フィンガープリントと、マップに表示するアイコンの位置をまとめて持つ
struct Location: Identifiable {
    /// チェックポイント ID（例："checkpoint_1"）
    let id: String
    let name: String
    /// マップ上で、このチェックポイントのアイコンを表示する位置
    let iconPosition: MapPosition
    /// ビーコン名ごとの RSSI（dBm）。未測定のビーコンはキーを追加しない
    let fingerprint: [String: Int]
}

extension Location {
    /// 長辺の両側に 3 台ずつ置くビーコンの広告名。ESP32 側もこの名前に揃える
    static let beaconIDs = ["BeaconA", "BeaconB", "BeaconC", "BeaconD", "BeaconE", "BeaconF"]

    /// `Resources/map.png` を基準にしたチェックポイントの設定。
    /// ID、フィンガープリント、UI アイコン座標をここでまとめて編集する
    ///
    /// 既存の A〜D の値は仮の初期値。6 台を所定の位置に固定した後、各チェックポイントで
    /// iPhone を使って測定した値に置き換える。未測定の BeaconE / F を `-100` で埋めず、
    /// 実測後にキーと値を追加する。
    static let checkpoints: [String: Location] = [
        "checkpoint_1": Location(
            id: "checkpoint_1",
            name: "1",
            iconPosition: MapPosition(x: 0.066, y: 0.132),
            fingerprint: ["BeaconA": -54, "BeaconB": -100, "BeaconC": -75, "BeaconD": -68]
        ),
        "checkpoint_2": Location(
            id: "checkpoint_2",
            name: "2",
            iconPosition: MapPosition(x: 0.888, y: 0.131),
            fingerprint: ["BeaconA": -65, "BeaconB": -100, "BeaconC": -69, "BeaconD": -84]
        ),
        "checkpoint_3": Location(
            id: "checkpoint_3",
            name: "3",
            iconPosition: MapPosition(x: 0.105, y: 0.561),
            fingerprint: ["BeaconA": -72, "BeaconB": -100, "BeaconC": -74, "BeaconD": -63]
        ),
        "checkpoint_4": Location(
            id: "checkpoint_4",
            name: "4",
            iconPosition: MapPosition(x: 0.871, y: 0.520),
            fingerprint: ["BeaconA": -86, "BeaconB": -90, "BeaconC": -71, "BeaconD": -78]
        ),
        "checkpoint_5": Location(
            id: "checkpoint_5",
            name: "5",
            iconPosition: MapPosition(x: 0.094, y: 0.942),
            fingerprint: ["BeaconA": -71, "BeaconB": -100, "BeaconC": -74, "BeaconD": -74]
        ),
        "checkpoint_6": Location(
            id: "checkpoint_6",
            name: "6",
            iconPosition: MapPosition(x: 0.859, y: 0.964),
            fingerprint: ["BeaconA": -81, "BeaconB": -82, "BeaconC": -77, "BeaconD": -100]
        ),
    ]

    /// UI と推定で使う表示順。辞書の列挙順に依存しない
    static let checkpointIDs = ["checkpoint_1", "checkpoint_2", "checkpoint_3", "checkpoint_4", "checkpoint_5", "checkpoint_6"]

    static let registered = checkpointIDs.compactMap { checkpoints[$0] }
}
