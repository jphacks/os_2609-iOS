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
    /// ビーコン名ごとの RSSI（dBm）。BeaconA〜F の6本すべてを持つ
    let fingerprint: [String: Int]
}

extension Location {
    /// 長辺の両側に 3 台ずつ置くビーコンの広告名。ESP32 側もこの名前に揃える
    static let beaconIDs = ["BeaconA", "BeaconB", "BeaconC", "BeaconD", "BeaconE", "BeaconF"]

    /// map.png 上のチェックポイントとビーコンの対応。1=A、2=B、…、6=F
    static let checkpointIDByBeaconID = [
        "BeaconA": "checkpoint_1",
        "BeaconB": "checkpoint_2",
        "BeaconC": "checkpoint_3",
        "BeaconD": "checkpoint_4",
        "BeaconE": "checkpoint_5",
        "BeaconF": "checkpoint_6",
    ]

    /// `Resources/map.png` を基準にしたチェックポイントの設定。
    /// ID、フィンガープリント、UI アイコン座標をここでまとめて編集する
    ///
    /// 1=A、2=B、…、6=F の配置を基にした6台分の初期推定値。
    /// 設置後は各地点で表示される BeaconA〜F の中央値を測定し、各辞書の6値を実測値に置き換える。
    /// 6台すべてが比較対象になるため、キーを削除しない。
    static let checkpoints: [String: Location] = [
        "checkpoint_1": Location(
            id: "checkpoint_1",
            name: "1",
            iconPosition: MapPosition(x: 0.066, y: 0.132),
            fingerprint: [
                "BeaconA": -54, "BeaconB": -79, "BeaconC": -67,
                "BeaconD": -81, "BeaconE": -78, "BeaconF": -89,
            ]
        ),
        "checkpoint_2": Location(
            id: "checkpoint_2",
            name: "2",
            iconPosition: MapPosition(x: 0.888, y: 0.131),
            fingerprint: [
                "BeaconA": -79, "BeaconB": -54, "BeaconC": -81,
                "BeaconD": -66, "BeaconE": -88, "BeaconF": -79,
            ]
        ),
        "checkpoint_3": Location(
            id: "checkpoint_3",
            name: "3",
            iconPosition: MapPosition(x: 0.105, y: 0.561),
            fingerprint: [
                "BeaconA": -67, "BeaconB": -81, "BeaconC": -54,
                "BeaconD": -77, "BeaconE": -65, "BeaconF": -80,
            ]
        ),
        "checkpoint_4": Location(
            id: "checkpoint_4",
            name: "4",
            iconPosition: MapPosition(x: 0.871, y: 0.520),
            fingerprint: [
                "BeaconA": -81, "BeaconB": -66, "BeaconC": -77,
                "BeaconD": -54, "BeaconE": -81, "BeaconF": -67,
            ]
        ),
        "checkpoint_5": Location(
            id: "checkpoint_5",
            name: "5",
            iconPosition: MapPosition(x: 0.094, y: 0.942),
            fingerprint: [
                "BeaconA": -78, "BeaconB": -88, "BeaconC": -65,
                "BeaconD": -81, "BeaconE": -54, "BeaconF": -77,
            ]
        ),
        "checkpoint_6": Location(
            id: "checkpoint_6",
            name: "6",
            iconPosition: MapPosition(x: 0.859, y: 0.964),
            fingerprint: [
                "BeaconA": -89, "BeaconB": -79, "BeaconC": -80,
                "BeaconD": -67, "BeaconE": -77, "BeaconF": -54,
            ]
        ),
    ]

    /// UI と推定で使う表示順。辞書の列挙順に依存しない
    static let checkpointIDs = ["checkpoint_1", "checkpoint_2", "checkpoint_3", "checkpoint_4", "checkpoint_5", "checkpoint_6"]

    static let registered = checkpointIDs.compactMap { checkpoints[$0] }
}
