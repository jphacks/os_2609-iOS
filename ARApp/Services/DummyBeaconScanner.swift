//
//  DummyBeaconScanner.swift
//  ARApp
//

import Foundation

/// ESP32 がなくても動かせるダミー実装
/// 指定した地点の RSSI のパターンに少し揺れを加えて、本物のビーコンのように流し続ける
final class DummyBeaconScanner: BeaconScanner {
    var onReceive: ((_ beaconName: String, _ rssi: Int) -> Void)?

    private let rssiByBeacon: [String: Int]
    private var emitTask: Task<Void, Never>?

    /// 初期値は登録済みの最初の地点（入口）に立っているときのパターン
    init(location: Location = Location.registered[0]) {
        rssiByBeacon = Dictionary(uniqueKeysWithValues: zip(Location.beaconNames, location.fingerprint))
    }

    func start() {
        guard emitTask == nil else { return }
        emitTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                for (name, rssi) in self.rssiByBeacon {
                    self.onReceive?(name, rssi + Int.random(in: -3...3))
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    func stop() {
        emitTask?.cancel()
        emitTask = nil
    }
}
