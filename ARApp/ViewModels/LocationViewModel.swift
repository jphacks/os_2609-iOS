//
//  LocationViewModel.swift
//  ARApp
//

import Foundation
import Observation

/// ビーコンの RSSI から現在地を推定する
/// 一定時間 RSSI を集めてはビーコンごとの中央値で推定し、集めた値を捨てて次を集め直す
/// （前の測定と重ねないので、推定が前の場所に引きずられない）
@Observable
final class LocationViewModel {
    /// 1 回の推定のために RSSI を集める時間（秒）。この間隔で推定し直す
    static let measurementDuration: TimeInterval = 2
    /// 期間内に 1 回も受信できなかったビーコンの RSSI（とても遠い扱い）
    static let missingRSSI = -100
    /// マップ上の位置を求めるときに使う、RSSI のパターンが近い地点の数
    static let positionNeighborCount = 3

    /// 推定した現在地。ビーコンを 1 台も受信できていない間は nil
    private(set) var currentLocation: Location?
    /// マップに自分を表示する位置。地点と地点の間にいるときは、その間になる
    /// ビーコンを 1 台も受信できていない間は nil
    private(set) var currentPosition: MapPosition?
    /// 推定に使った各ビーコンの RSSI。並びは `Location.beaconNames` と同じ
    /// 地点を登録するときは、その場所でこの値を控えて `Location.registered` に書く
    /// 【開発用】LocationStatusComponent でしか使っていない。あの部品を消すときに一緒に消す
    private(set) var currentRSSI: [Int] = []

    var statusMessage: String {
        if let currentLocation {
            "現在地：\(currentLocation.name)"
        } else {
            "ビーコンを探しています…"
        }
    }

    private let scanner: any BeaconScanner
    /// ビーコンごとの、今の測定で受信した RSSI
    private var samples: [String: [Int]] = [:]
    private var updateTask: Task<Void, Never>?

    init(scanner: any BeaconScanner) {
        self.scanner = scanner
    }

    func start() {
        guard updateTask == nil else { return }
        scanner.onReceive = { [weak self] beaconName, rssi in
            self?.record(beaconName: beaconName, rssi: rssi)
        }
        scanner.start()

        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.measurementDuration))
                guard let self, !Task.isCancelled else { return }
                self.updateEstimate()
            }
        }
    }

    func stop() {
        scanner.stop()
        scanner.onReceive = nil
        updateTask?.cancel()
        updateTask = nil
        samples = [:]
    }

    /// ビーコンを受信するたびに呼ばれる。対象のビーコンだけ記録する
    private func record(beaconName: String, rssi: Int) {
        guard Location.beaconNames.contains(beaconName) else { return }
        samples[beaconName, default: []].append(rssi)
    }

    /// この `measurementDuration` 秒に集めた RSSI から現在地を推定し直し、次の測定のために集めた値を捨てる
    private func updateEstimate() {
        defer { samples = [:] }

        // 1 台も受信できていないときは、どの地点とも言えない
        guard samples.values.contains(where: { !$0.isEmpty }) else {
            currentRSSI = []
            currentLocation = nil
            currentPosition = nil
            return
        }

        // ビーコンごとに中央値を取る。RSSI は揺れが大きいので、外れ値に強い中央値を使う
        let rssi = Location.beaconNames.map { beaconName in
            Self.median(samples[beaconName] ?? []) ?? Self.missingRSSI
        }
        currentRSSI = rssi

        // RSSI のパターンが一番似ている（距離が一番小さい）地点を現在地とする
        currentLocation = Location.registered.min {
            Self.distance($0.fingerprint, rssi) < Self.distance($1.fingerprint, rssi)
        }
        currentPosition = Self.weightedPosition(rssi: rssi)
    }

    /// 重み付き k 近傍法でマップ上の位置を求める
    /// RSSI のパターンが近い上位 `positionNeighborCount` 地点の位置を、パターンが近いほど重くして平均する
    private static func weightedPosition(rssi: [Int]) -> MapPosition? {
        let neighbors = Location.registered
            .map { (position: $0.position, distance: distance($0.fingerprint, rssi)) }
            .sorted { $0.distance < $1.distance }
            .prefix(positionNeighborCount)

        // 距離の 2 乗の逆数で重み付けし、ある地点に立っているときは点がほぼその地点に乗るようにする
        // （1 乗だと他の地点にも引っ張られ、地点の上に立っていても点がずれる）
        // 距離が 0 でも割れるように 1 を足す
        let weighted = neighbors.map { (position: $0.position, weight: 1 / pow($0.distance + 1, 2)) }
        let totalWeight = weighted.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }

        return MapPosition(
            x: weighted.reduce(0) { $0 + $1.position.x * $1.weight } / totalWeight,
            y: weighted.reduce(0) { $0 + $1.position.y * $1.weight } / totalWeight
        )
    }

    /// RSSI の配列どうしのユークリッド距離。小さいほどパターンが似ている
    /// （メートル単位の距離ではない）
    private static func distance(_ a: [Int], _ b: [Int]) -> Double {
        let squaredSum = zip(a, b).reduce(0.0) { sum, pair in
            let difference = Double(pair.0 - pair.1)
            return sum + difference * difference
        }
        return squaredSum.squareRoot()
    }

    private static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }
}
