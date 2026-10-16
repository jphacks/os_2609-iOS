//
//  DummyBeaconScanner.swift
//  ARApp
//

import Foundation

/// ESP32 がなくても動かせるダミー実装
/// 決まった RSSI に少し揺れを加えて、本物のビーコンのように流し続ける
final class DummyBeaconScanner: BeaconScanner {
    var onReceive: ((_ beaconName: String, _ rssi: Int) -> Void)?

    private let rssiByBeacon: [String: Int]
    private var emitTask: Task<Void, Never>?

    /// 初期値は「入口」に立っているときのパターン
    init(rssiByBeacon: [String: Int] = ["BeaconA": -52, "BeaconB": -67, "BeaconC": -81, "BeaconD": -73]) {
        self.rssiByBeacon = rssiByBeacon
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
