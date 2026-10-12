//
//  BeaconScanner.swift
//  ARApp
//

import Foundation

/// ビーコンの電波を受信して、名前と RSSI を知らせる
/// 実機では BLEBeaconScanner、ESP32 がないときは DummyBeaconScanner を使う
protocol BeaconScanner: AnyObject {
    /// ビーコンの広告パケットを受信するたびに呼ばれる
    var onReceive: ((_ beaconName: String, _ rssi: Int) -> Void)? { get set }

    func start()
    func stop()
}
