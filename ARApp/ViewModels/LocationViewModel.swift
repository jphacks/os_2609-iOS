//
//  LocationViewModel.swift
//  ARApp
//

import Foundation
import Observation

/// ビーコンの RSSI から現在地を推定する
/// 直近の数秒ぶんの RSSI を使って、一定間隔で推定し直す（スライディングウィンドウ）
@Observable
final class LocationViewModel {
    /// 推定に使う RSSI の期間（秒）。短いと反応が速く、長いと安定する
    static let windowSeconds: TimeInterval = 3
    /// 推定し直す間隔（秒）
    static let updateInterval: TimeInterval = 1
    /// 期間内に 1 回も受信できなかったビーコンの RSSI（とても遠い扱い）
    static let missingRSSI = -100

    /// 推定した現在地。ビーコンを 1 台も受信できていない間は nil
    private(set) var currentLocation: Location?
    /// 推定に使った各ビーコンの RSSI。並びは `Location.beaconNames` と同じ
    /// 地点を登録するときは、その場所でこの値を控えて `Location.registered` に書く
    /// 【開発用】LocationStatusView でしか使っていない。あの View を消すときに一緒に消す
    private(set) var currentRSSI: [Int] = []

    var statusMessage: String {
        if let currentLocation {
            "現在地：\(currentLocation.name)"
        } else {
            "ビーコンを探しています…"
        }
    }

    private struct Sample {
        let time: Date
        let rssi: Int
    }

    private let scanner: any BeaconScanner
    private let locations: [Location]
    /// ビーコンごとの、直近の受信記録
    private var samples: [String: [Sample]] = [:]
    private var updateTask: Task<Void, Never>?

    init(scanner: any BeaconScanner, locations: [Location] = Location.registered) {
        self.scanner = scanner
        self.locations = locations
    }

    func start() {
        guard updateTask == nil else { return }
        scanner.onReceive = { [weak self] beaconName, rssi in
            self?.record(beaconName: beaconName, rssi: rssi, at: .now)
        }
        scanner.start()

        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.updateInterval))
                guard let self, !Task.isCancelled else { return }
                self.updateEstimate(now: .now)
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
    private func record(beaconName: String, rssi: Int, at time: Date) {
        guard Location.beaconNames.contains(beaconName) else { return }
        samples[beaconName, default: []].append(Sample(time: time, rssi: rssi))
    }

    /// 直近 `windowSeconds` 秒の RSSI から現在地を推定し直す
    private func updateEstimate(now: Date) {
        // 期間より古い記録を捨てる
        let oldest = now.addingTimeInterval(-Self.windowSeconds)
        for beaconName in samples.keys {
            samples[beaconName]?.removeAll { $0.time < oldest }
        }

        // 1 台も受信できていないときは、どの地点とも言えない
        guard samples.values.contains(where: { !$0.isEmpty }) else {
            currentRSSI = []
            currentLocation = nil
            return
        }

        // ビーコンごとに中央値を取る。RSSI は揺れが大きいので、外れ値に強い中央値を使う
        let rssi = Location.beaconNames.map { beaconName in
            Self.median((samples[beaconName] ?? []).map(\.rssi)) ?? Self.missingRSSI
        }
        currentRSSI = rssi

        // RSSI のパターンが一番似ている（距離が一番小さい）地点を現在地とする
        currentLocation = locations.min {
            Self.distance($0.fingerprint, rssi) < Self.distance($1.fingerprint, rssi)
        }
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
