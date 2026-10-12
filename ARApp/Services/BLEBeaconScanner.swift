//
//  BLEBeaconScanner.swift
//  ARApp
//

import CoreBluetooth

/// CoreBluetooth で ESP32 のビーコンをスキャンする
/// 接続はせず、流れてくる広告パケットを受信するだけ
final class BLEBeaconScanner: NSObject, BeaconScanner, CBCentralManagerDelegate {
    /// ESP32 側の SERVICE_UUID と同じ値。この UUID を広告しているデバイスだけを受信する
    private static let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
    /// CoreBluetooth が RSSI を測れなかったときに返す値
    private static let unavailableRSSI = 127

    var onReceive: ((_ beaconName: String, _ rssi: Int) -> Void)?

    private var centralManager: CBCentralManager?

    func start() {
        guard centralManager == nil else { return }
        // 作成した時点で Bluetooth の許可ダイアログが出る
        // queue: nil にすると delegate はメインスレッドで呼ばれる
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func stop() {
        centralManager?.stopScan()
        centralManager = nil
    }

    /// Bluetooth の状態が変わったときに呼ばれる。スキャンは poweredOn になってからでないと始められない
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        // 通常は同じデバイスの通知が 1 回にまとめられる
        // RSSI を受信のたびに知りたいので、重複を許可する
        central.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    /// 広告パケットを受信するたびに呼ばれる
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
        guard let name, RSSI.intValue != Self.unavailableRSSI else { return }
        onReceive?(name, RSSI.intValue)
    }
}
