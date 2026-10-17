//
//  BLEBeaconScanner.swift
//  ARApp
//

import CoreBluetooth

/// CoreBluetooth で ESP32 のビーコンをスキャンする
/// 接続はせず、流れてくる広告パケットを受信するだけ
final class BLEBeaconScanner: NSObject, BeaconScanner, CBCentralManagerDelegate {
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
            withServices: nil,
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
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
        guard
            let advertisedName,
            let beaconName = Self.beaconName(for: advertisedName),
            RSSI.intValue != Self.unavailableRSSI
        else { return }
        onReceive?(beaconName, RSSI.intValue)
    }

    /// 広告名の前後の空白や大文字・小文字の違いを吸収して、登録済みの正式なビーコン名を返す
    private static func beaconName(for advertisedName: String) -> String? {
        let normalized = advertisedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return Location.beaconNames.first {
            $0.compare(normalized, options: .caseInsensitive) == .orderedSame
        }
    }
}
