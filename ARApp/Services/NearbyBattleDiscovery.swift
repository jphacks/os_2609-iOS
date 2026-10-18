//
//  NearbyBattleDiscovery.swift
//  ARApp
//

import CoreBluetooth
import Foundation
import Observation
import Supabase

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

    /// 端末固定 ID は使わず、受付を開始するたびに作るランダム値
    private var sessionID = UUID()
    private(set) var readyToken: UUID?
    private(set) var isWaitingForConsent = false
    private(set) var statusMessage: String?
    var isPairingConfigured: Bool { pairingClient != nil }
    private var reservedToken: UUID?
    private var wantsToAccept = false
    private var remoteSessions: Set<UUID> = []
    private var pairingTask: Task<Void, Never>?
    @ObservationIgnored private let pairingClient: SupabaseClient? = {
        guard SupabaseConfig.isConfigured, let url = URL(string: SupabaseConfig.url) else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: SupabaseConfig.anonKey)
    }()
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
        guard accepting != isAccepting else { return }
        isAccepting = accepting
        pendingCandidate = nil
        reservedToken = nil
        wantsToAccept = false
        isWaitingForConsent = false
        remoteSessions = []
        if accepting {
            guard let client = pairingClient else {
                isAccepting = false
                statusMessage = "対戦の接続設定がありません"
                return
            }
            sessionID = UUID() // 受付の世代を分け、以前の通知・通信結果を引き継がない
            readyToken = nil
            statusMessage = nil
            startPairing(client: client, session: sessionID)
            startDiscoveryIfPossible()
        } else {
            pairingTask?.cancel()
            pairingTask = nil
            stopTransport()
        }
    }

    func stopForInactiveMap() {
        setAccepting(false)
    }

    /// 自分の承諾だけでは開始しない。双方の承諾をサーバーで確認する。
    func confirmCandidate() {
        guard pendingCandidate != nil else { return }
        pendingCandidate = nil
        wantsToAccept = true
        isWaitingForConsent = true
    }

    func dismissCandidate() {
        statusMessage = "対戦を辞退しました。受付をオンにすると再び探します"
        setAccepting(false)
    }

    private func startPairing(client: SupabaseClient, session: UUID) {
        pairingTask = Task { [weak self] in
            // RPC 完了後にも停止を送る。停止と処理中の offer が前後しても予約を残さない。
            defer {
                Task {
                    _ = try? await Self.pair(client: client, session: session, action: "stop")
                }
            }
            do {
                while !Task.isCancelled {
                    guard let self, isAccepting, sessionID == session else { return }
                    let peer = reservedToken == nil ? remoteSessions.first : nil
                    if let peer { remoteSessions.remove(peer) }
                    let action = wantsToAccept ? "accept" : (peer == nil ? "poll" : "offer")
                    let token = reservedToken
                    // キャンセルで予約の応答を失わないよう、通信自体は最後まで待つ。
                    let rows = try await Task {
                        try await Self.pair(client: client, session: session, action: action, peer: peer, token: token)
                    }.value
                    guard !Task.isCancelled, isAccepting, sessionID == session else { return }
                    if let row = rows.first {
                        reservedToken = row.id
                        stopTransport()
                        switch row.status {
                        case "pending":
                            if !isWaitingForConsent {
                                pendingCandidate = NearbyBattleCandidate(pairingToken: row.id)
                            }
                        case "ready":
                            readyToken = row.id
                            setAccepting(false)
                            return
                        default:
                            statusMessage = row.status == "expired"
                                ? "確認の時間が切れました。受付をオンにして再度お試しください"
                                : "相手が対戦を辞退したか、受付を終了しました"
                            setAccepting(false)
                            return
                        }
                    }
                    try await Task.sleep(for: .milliseconds(500))
                }
            } catch {
                guard !Task.isCancelled, let self, sessionID == session else { return }
                statusMessage = "対戦相手との確認に失敗しました。受付をオンにして再度お試しください"
                setAccepting(false)
            }
        }
    }

    private static func pair(client: SupabaseClient, session: UUID, action: String,
                             peer: UUID? = nil, token: UUID? = nil) async throws -> [NearbyPairRow] {
        try await client.rpc("nearby_pair", params: NearbyPairParams(
            session: session, action: action, peer: peer, token: token
        )).execute().value
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
            // 確保前は候補 ID を収集する。複数候補の競合はサーバーで解決する。
            guard reservedToken == nil,
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
              reservedToken == nil,
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
            activePeripheral.delegate = nil
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
              reservedToken == nil
        else { return }

        discoveredPeripherals[peripheral.identifier] = DiscoveredPeripheral(
            peripheral: peripheral,
            rssi: RSSI.intValue
        )
        scheduleCandidateSelectionIfNeeded()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard isCurrent(peripheral) else { abandon(peripheral); return }
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
        guard isCurrent(peripheral), error == nil,
              let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID })
        else {
            abandon(peripheral)
            return
        }
        peripheral.discoverCharacteristics([Self.handshakeCharacteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard isCurrent(peripheral), error == nil,
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
        guard isCurrent(peripheral), error == nil,
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
        guard isCurrent(peripheral), error == nil,
              characteristic.uuid == Self.handshakeCharacteristicUUID,
              writableCharacteristics[peripheral.identifier] === characteristic,
              let value = characteristic.value,
              let remoteSessionID = UUID(uuidString: String(decoding: value, as: UTF8.self))
        else { return }
        receive(remoteSessionID: remoteSessionID)
    }

    private func isCurrent(_ peripheral: CBPeripheral) -> Bool {
        isAccepting && reservedToken == nil && activePeripheral === peripheral
    }

    private func receive(remoteSessionID: UUID) {
        guard isAccepting, reservedToken == nil, remoteSessionID != sessionID else { return }
        // BLE の受信だけでは確定しない。サーバーが両端末を排他的に確保する。
        remoteSessions.insert(remoteSessionID)
    }

    /// RSSI が強い 1 台だけに接続する。6〜7 台を同時に見つけても接続競合を起こさない。
    private func connectToNextPeripheralIfPossible() {
        guard isAccepting,
              reservedToken == nil,
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
}

/// サーバーが両端末を確保して発行した対戦候補
struct NearbyBattleCandidate: Identifiable {
    let pairingToken: UUID
    var id: UUID { pairingToken }
}

private struct DiscoveredPeripheral {
    let peripheral: CBPeripheral
    let rssi: Int
}

nonisolated private struct NearbyPairRow: Decodable, Sendable {
    let id: UUID
    let status: String
}

nonisolated private struct NearbyPairParams: Encodable, Sendable {
    let session: UUID
    let action: String
    let peer: UUID?
    let token: UUID?

    enum CodingKeys: String, CodingKey {
        case session = "p_session"
        case action = "p_action"
        case peer = "p_peer"
        case token = "p_token"
    }
}
