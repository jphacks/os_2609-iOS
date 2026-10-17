//
//  LocationEstimationConfig.swift
//  ARApp
//

import Foundation

/// 現在地の推定で使う、調整用の値
/// 実機で試しながら変える値をここにまとめる。値を比べたいときは、別の値で作って LocationViewModel に渡す
struct LocationEstimationConfig {
    /// 1 回の推定のために RSSI を集める時間（秒）。この間隔で推定し直す
    var measurementDuration: TimeInterval = 2
    /// 測定中に 1 回も受信できなかったビーコンの RSSI（とても遠い扱い）
    var missingRSSI = -100
    /// マップ上の位置を求めるときに使う、RSSI のパターンが近い地点の数
    var positionNeighborCount = 3
    /// マップ上の位置を求めるときの重みの乗数。重みは 1 / (距離 + 1)^positionWeightPower
    /// 大きいほど地点の上で点がぴったり乗り、小さいほど RSSI の誤差で点が揺れにくい
    var positionWeightPower = 2.0
    /// 【仮】一番近い地点との RSSI の距離がこれ以下なら、その地点に「着いた」とみなす
    /// 登録地点どうしの距離は 28〜33、2 地点の中間は 14 前後（2026-10-17 の実測値）。会場で測りながら調整する
    var arrivalThreshold = 10.0
}
