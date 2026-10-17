//
//  NearbyBattleDiscovery.swift
//  ARApp
//

import CoreBluetooth
import CryptoKit
import Foundation
import Observation

/// 近くで対戦受付中の端末と、1 回だけ使う対戦トークンを共有する。
/// 対戦内容は BLE では送らず、既存の Supabase 通信を使う。
@Observable
final class NearbyBattleDiscovery: NSObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate {
    /// このアプリの近距離対戦専用 GATT サービス。RSSI ビーコンの UUID とは別物。
    private static let serviceUUID = CBUUID(string: "7D6A7624-49E5-4A5B-A250-268076174520")
    private static let handshakeCharacteristicUUID = CBUUID(string: "DDF82268-6904-4CE5-9F1E-C59CB09E7BC4")
    /// 周囲の端末を短時間集めてから、最も強い RSSI を接続候補にする時間
    private static let candidateCollectionDuration: Duration = .milliseconds(750)

    /// スライドボタンが ON か。ON のときだけ広告・スキャンする。
    private(set) var isAccepting = false
    /// Bluetooth を使える状態か
    private(set) var isBluetoothReady = false
    /// 相互認識済みで、ユーザー確認を待っている相手
    private(set) var pendingCandidate: NearbyBattleCandidate?

    /// 端末固定 ID は使わず、アプリを起動するたびに作るランダム値
    private let sessionID = UUID()
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var isPublishingService = false
    private var hasPublishedService = false
    /// 周囲に多数の受付端末がいても、GATT 接続は常に 1 台ずつにする。
    /// RSSI が強い（近い可能性が高い）順に、失敗時だけ次の端末を試す。
    private var discoveredPeripherals: [UUID: DiscoveredPeripheral] = [:]
    private var activePeripheral: CBPeripheral?
    private var selectionTask: Task<Void, Never>?
    private var writableCharacteristics: [UUID: CBCharacteristic] = [:]
    private var pendingResponseCentral: CBCentral?

    @ObservationIgnored private lazy var handshakeCharacteristic = CBMutableCharacteristic(
        type: Self.handshakeCharacteristicUUID,
        properties: [.write, .notify, .notifyEncryptionRequired],
        value: nil,
        // セッション ID の書込みと通知は、暗号化済みの接続だけに限定する
        permissions: [.writeEncryptionRequired]
    )
    @ObservationIgnored private lazy var battleService: CBMutableService = {
        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [handshakeCharacteristic]
        return service
    }()

    override init() {
        super.init()
        // queue: nil にし、UI と同じメインスレッドで状態を更新する
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func setAccepting(_ accepting: Bool) {
        isAccepting = accepting
        pendingCandidate = nil
        if accepting {
            startDiscoveryIfPossible()
        } else {
            stopTransport()
        }
    }

    /// マップ画面が前面から外れたときに呼ぶ。バックグラウンドでは広告・スキャンしない。
    func stopForInactiveMap() {
        setAccepting(false)
    }

    /// 確認ポップアップで「対戦する」を選んだとき、同じ相手だけに一致するトークンを返す。
    func confirmCandidate() -> UUID? {
        let token = pendingCandidate?.pairingToken
        setAccepting(false)
        return token
    }

    func dismissCandidate() {
        pendingCandidate = nil
        stopTransport()
        startDiscoveryIfPossible()
    }

    // MARK: - Peripheral / advertising

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        updateBluetoothReadiness()
        startDiscoveryIfPossible()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        isPublishingService = false
        hasPublishedService = error == nil
        startDiscoveryIfPossible()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard isAccepting else {
            requests.forEach { peripheral.respond(to: $0, withResult: .requestNotSupported) }
            return
        }

        for request in requests {
            // 複数端末が同時に書き込んできても、最初の 1 台以外は受理しない。
            guard pendingCandidate == nil,
                  request.characteristic.uuid == Self.handshakeCharacteristicUUID,
                  request.offset == 0,
                  let value = request.value,
                  let remoteSessionID = UUID(uuidString: String(decoding: value, as: UTF8.self))
            else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
                continue
            }

            peripheral.respond(to: request, withResult: .success)
            receive(remoteSessionID: remoteSessionID)
            sendSessionID(to: request.central)
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        guard let central = pendingResponseCentral else { return }
        pendingResponseCentral = nil
        sendSessionID(to: central)
    }

    private func startDiscoveryIfPossible() {
        guard isAccepting,
              pendingCandidate == nil,
              centralManager.state == .poweredOn,
              peripheralManager.state == .poweredOn
        else { return }

        if !hasPublishedService {
            guard !isPublishingService else { return }
            isPublishingService = true
            peripheralManager.add(battleService)
            return
        }

        if !peripheralManager.isAdvertising {
            // UUID 以外のデータを広告しない。個人名・端末名・固定 ID は送らない。
            peripheralManager.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID]
            ])
        }
        centralManager.scanForPeripherals(
            withServices: [Self.serviceUUID],
            // 受付中だけの短時間スキャンなので、RSSI のより新しい値を候補選択に使う
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    private func stopTransport() {
        centralManager.stopScan()
        peripheralManager.stopAdvertising()
        pendingResponseCentral = nil
        selectionTask?.cancel()
        selectionTask = nil
        writableCharacteristics = [:]
        if let activePeripheral {
            centralManager.cancelPeripheralConnection(activePeripheral)
        }
        activePeripheral = nil
        discoveredPeripherals = [:]
    }

    private func sendSessionID(to central: CBCentral) {
        let data = Data(sessionID.uuidString.utf8)
        guard peripheralManager.updateValue(data, for: handshakeCharacteristic, onSubscribedCentrals: [central]) else {
            pendingResponseCentral = central
            return
        }
    }

    // MARK: - Central / discovery

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        updateBluetoothReadiness()
        startDiscoveryIfPossible()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard isAccepting,
              pendingCandidate == nil
        else { return }

        discoveredPeripherals[peripheral.identifier] = DiscoveredPeripheral(
            peripheral: peripheral,
            rssi: RSSI.intValue
        )
        scheduleCandidateSelectionIfNeeded()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        finishActiveConnection(for: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        finishActiveConnection(for: peripheral)
        writableCharacteristics[peripheral.identifier] = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID })
        else {
            abandon(peripheral)
            return
        }
        peripheral.discoverCharacteristics([Self.handshakeCharacteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil,
              let characteristic = service.characteristics?.first(where: { $0.uuid == Self.handshakeCharacteristicUUID })
        else {
            abandon(peripheral)
            return
        }
        writableCharacteristics[peripheral.identifier] = characteristic
        // 暗号化済みの通知購読が成立してから、セッション ID を書き込む
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              characteristic.uuid == Self.handshakeCharacteristicUUID,
              characteristic.isNotifying
        else {
            abandon(peripheral)
            return
        }
        peripheral.writeValue(Data(sessionID.uuidString.utf8), for: characteristic, type: .withResponse)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.handshakeCharacteristicUUID, error != nil else { return }
        abandon(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              characteristic.uuid == Self.handshakeCharacteristicUUID,
              let value = characteristic.value,
              let remoteSessionID = UUID(uuidString: String(decoding: value, as: UTF8.self))
        else { return }
        receive(remoteSessionID: remoteSessionID)
    }

    private func receive(remoteSessionID: UUID) {
        guard remoteSessionID != sessionID, pendingCandidate == nil else { return }
        let token = Self.pairingToken(between: sessionID, and: remoteSessionID)
        pendingCandidate = NearbyBattleCandidate(pairingToken: token)
        // 1 人を見つけたら他の端末と同時に対戦候補にならないよう止める
        selectionTask?.cancel()
        selectionTask = nil
        centralManager.stopScan()
        peripheralManager.stopAdvertising()
    }

    /// RSSI が強い 1 台だけに接続する。6〜7 台を同時に見つけても接続競合を起こさない。
    private func connectToNextPeripheralIfPossible() {
        guard isAccepting,
              pendingCandidate == nil,
              activePeripheral == nil,
              let next = discoveredPeripherals.values.max(by: { $0.rssi < $1.rssi })
        else { return }

        discoveredPeripherals[next.peripheral.identifier] = nil
        activePeripheral = next.peripheral
        centralManager.connect(next.peripheral)
    }

    private func scheduleCandidateSelectionIfNeeded() {
        guard activePeripheral == nil, selectionTask == nil else { return }
        selectionTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.candidateCollectionDuration)
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            selectionTask = nil
            connectToNextPeripheralIfPossible()
        }
    }

    private func abandon(_ peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }

    private func finishActiveConnection(for peripheral: CBPeripheral) {
        guard activePeripheral?.identifier == peripheral.identifier else { return }
        activePeripheral = nil
        connectToNextPeripheralIfPossible()
    }

    private func updateBluetoothReadiness() {
        isBluetoothReady = centralManager.state == .poweredOn && peripheralManager.state == .poweredOn
    }

    private static func pairingToken(between first: UUID, and second: UUID) -> UUID {
        let data = Data([first.uuidString, second.uuidString].sorted().joined(separator: ":").utf8)
        let digest = Array(SHA256.hash(data: data))
        return UUID(uuid: (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15]
        ))
    }
}

/// 同じ BLE ハンドシェイクから、両端末で同じ値になる対戦候補
struct NearbyBattleCandidate: Identifiable {
    let pairingToken: UUID
    var id: UUID { pairingToken }
}

private struct DiscoveredPeripheral {
    let peripheral: CBPeripheral
    let rssi: Int
}
