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

    /// map.png 上のビーコン配置。1=A、2=B、…、6=F（7・8は判定用チェックポイント）
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
    /// 1〜8の各地点で実測した6台分のフィンガープリント。
    /// 各辞書は BeaconA〜F の順で、提示された実測中央値をそのままハードコードしている。
    /// 6台すべてが比較対象になるため、キーを削除しない。
    static let checkpoints: [String: Location] = [
        "checkpoint_1": Location(
            id: "checkpoint_1",
            name: "1",
            iconPosition: MapPosition(x: 0.069, y: 0.136),
            fingerprint: [
                "BeaconA": -54, "BeaconB": -88, "BeaconC": -54,
                "BeaconD": -62, "BeaconE": -62, "BeaconF": -69,
            ]
        ),
        "checkpoint_2": Location(
            id: "checkpoint_2",
            name: "2",
            iconPosition: MapPosition(x: 0.889, y: 0.132),
            fingerprint: [
                "BeaconA": -64, "BeaconB": -75, "BeaconC": -58,
                "BeaconD": -60, "BeaconE": -69, "BeaconF": -66,
            ]
        ),
        "checkpoint_3": Location(
            id: "checkpoint_3",
            name: "3",
            iconPosition: MapPosition(x: 0.195, y: 0.372),
            fingerprint: [
                "BeaconA": -62, "BeaconB": -87, "BeaconC": -52,
                "BeaconD": -60, "BeaconE": -65, "BeaconF": -72,
            ]
        ),
        "checkpoint_4": Location(
            id: "checkpoint_4",
            name: "4",
            iconPosition: MapPosition(x: 0.861, y: 0.362),
            fingerprint: [
                "BeaconA": -66, "BeaconB": -87, "BeaconC": -53,
                "BeaconD": -58, "BeaconE": -67, "BeaconF": -75,
            ]
        ),
        "checkpoint_5": Location(
            id: "checkpoint_5",
            name: "5",
            iconPosition: MapPosition(x: 0.095, y: 0.941),
            fingerprint: [
                "BeaconA": -67, "BeaconB": -94, "BeaconC": -60,
                "BeaconD": -64, "BeaconE": -54, "BeaconF": -68,
            ]
        ),
        "checkpoint_6": Location(
            id: "checkpoint_6",
            name: "6",
            iconPosition: MapPosition(x: 0.860, y: 0.963),
            fingerprint: [
                "BeaconA": -68, "BeaconB": -86, "BeaconC": -65,
                "BeaconD": -65, "BeaconE": -68, "BeaconF": -53,
            ]
        ),
        "checkpoint_7": Location(
            id: "checkpoint_7",
            name: "7",
            iconPosition: MapPosition(x: 0.498, y: 0.674),
            fingerprint: [
                "BeaconA": -66, "BeaconB": -100, "BeaconC": -66,
                "BeaconD": -75, "BeaconE": -66, "BeaconF": -63,
            ]
        ),
        "checkpoint_8": Location(
            id: "checkpoint_8",
            name: "8",
            iconPosition: MapPosition(x: 0.506, y: 0.321),
            fingerprint: [
                "BeaconA": -69, "BeaconB": -90, "BeaconC": -61,
                "BeaconD": -61, "BeaconE": -66, "BeaconF": -65,
            ]
        ),
    ]

    /// UI と推定で使う表示順。辞書の列挙順に依存しない
    static let checkpointIDs = ["checkpoint_1", "checkpoint_2", "checkpoint_3", "checkpoint_4", "checkpoint_5", "checkpoint_6", "checkpoint_7", "checkpoint_8"]

    static let registered = checkpointIDs.compactMap { checkpoints[$0] }
}
