//
//  LocationViewModel.swift
//  ARApp
//

import Foundation
import Observation
import CoreMotion

/// BLE によるチェックポイント推定の信頼度
enum LocationConfidence {
    case unavailable
    case low
    case medium
    case high

    var label: String {
        switch self {
        case .unavailable: "未測定"
        case .low: "低"
        case .medium: "中"
        case .high: "高"
        }
    }
}

/// ビーコンの RSSI から、最寄りのチェックポイントを推定する
/// RSSI は正確な座標には使わず、会場内の粗いエリア判定にだけ使う
@Observable
final class LocationViewModel {
    /// RSSI の中央値を取る時間窓（秒）
    static let smoothingWindow: TimeInterval = 3
    /// 画面上の推定を更新する間隔（秒）
    static let updateInterval: TimeInterval = 0.5
    /// この時間窓で受信できなかったビーコンの比較用 RSSI
    static let missingRSSI = -100
    /// 停止後、歩行中に採取した RSSI を使わずに再測定する時間（秒）
    static let stationaryMeasurementDuration: TimeInterval = 3
    /// 最後に動きを検出してから「停止」と見なすまでの時間（秒）
    static let stationaryDelay: TimeInterval = 1.5
    /// userAcceleration の大きさ（G）がこの値以上なら移動と判定する
    static let movementAccelerationThreshold = 0.06
    /// この回数だけ連続で動きを検出してから移動中に切り替える。手ぶれを除外する
    static let consecutiveMotionSamplesRequired = 5
    /// 現在地を確定後、多少の動きや電波の揺れで地点を切り替えない保持時間（秒）
    static let locationHoldDuration: TimeInterval = 5
    /// 推定した最寄りチェックポイント
    private(set) var currentLocation: Location?
    /// チェックポイントのアイコン座標。位置を補間しない
    private(set) var currentPosition: MapPosition?
    /// 平滑化後のビーコン名ごとの RSSI
    /// 【開発用】LocationStatusComponent でフィンガープリントを測るために使う
    private(set) var currentRSSI: [String: Int] = [:]
    /// もっとも強く受信したビーコン
    private(set) var nearestBeacon: String?
    /// 現在のチェックポイント推定の信頼度
    private(set) var confidence: LocationConfidence = .unavailable
    /// 加速度センサーから、現在ユーザーが移動中と判断されているか
    private(set) var isMoving = false
    /// 停止後の RSSI 平滑化を行っている途中か
    private(set) var isPreparingEstimate = false

    var statusMessage: String {
        if isMoving {
            return "移動中です。現在地を知る場合は止まってください"
        }
        if isPreparingEstimate, !currentRSSI.isEmpty {
            return "停止を確認しました。現在地を測定中…"
        }
        guard let currentLocation else { return "ビーコンを探しています…" }
        return "推定地点：\(currentLocation.name)（信頼度：\(confidence.label)）"
    }

    private let scanner: any BeaconScanner
    private let motionManager = CMMotionManager()
    private let motionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.arapp.location-motion"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private var samples: [String: [RSSISample]] = [:]
    private var updateTask: Task<Void, Never>?
    private var lastMotionDetectedAt: Date?
    private var stationaryMeasurementStartedAt: Date?
    private var consecutiveMotionSampleCount = 0
    private var locationConfirmedAt: Date?

    init(scanner: any BeaconScanner) {
        self.scanner = scanner
    }

    func start() {
        guard updateTask == nil else { return }
        beginStationaryMeasurement()
        scanner.onReceive = { [weak self] beaconName, rssi in
            self?.record(beaconName: beaconName, rssi: rssi)
        }
        scanner.start()
        startMotionDetection()

        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.updateInterval))
                guard let self, !Task.isCancelled else { return }
                self.updateEstimate()
            }
        }
    }

    func stop() {
        scanner.stop()
        scanner.onReceive = nil
        motionManager.stopDeviceMotionUpdates()
        updateTask?.cancel()
        updateTask = nil
        samples = [:]
        lastMotionDetectedAt = nil
        stationaryMeasurementStartedAt = nil
        consecutiveMotionSampleCount = 0
        locationConfirmedAt = nil
        isMoving = false
        isPreparingEstimate = false
        resetEstimate()
    }

    /// ビーコンを受信するたびに、時間付きで記録する
    private func record(beaconName: String, rssi: Int) {
        // 歩行中の電波強度は推定に混ぜない。停止後に新たに採取した値だけを使う
        guard !isMoving, Location.beaconIDs.contains(beaconName) else { return }
        samples[beaconName, default: []].append(RSSISample(value: rssi, receivedAt: .now))
    }

    /// 時間窓に残る RSSI の中央値から、最寄りチェックポイントと信頼度を更新する
    private func updateEstimate() {
        updateMovementState()
        guard !isMoving else { return }

        let now = Date.now
        let cutoff = now.addingTimeInterval(-Self.smoothingWindow)
        samples = samples.reduce(into: [:]) { kept, entry in
            let recent = entry.value.filter { $0.receivedAt >= cutoff }
            if !recent.isEmpty {
                kept[entry.key] = recent
            }
        }

        currentRSSI = Dictionary(uniqueKeysWithValues: samples.compactMap { beaconName, values in
            Self.median(values.map(\.value)).map { (beaconName, $0) }
        })

        guard let stationaryMeasurementStartedAt,
              now.timeIntervalSince(stationaryMeasurementStartedAt) >= Self.stationaryMeasurementDuration
        else {
            return
        }
        isPreparingEstimate = false

        guard !currentRSSI.isEmpty else {
            resetEstimate()
            return
        }

        nearestBeacon = currentRSSI.max { $0.value < $1.value }?.key

        let candidates = Location.registered.compactMap { checkpoint -> Candidate? in
            let errors = checkpoint.fingerprint.compactMap { beaconName, expectedRSSI -> Double? in
                guard Location.beaconIDs.contains(beaconName) else { return nil }
                let observedRSSI = currentRSSI[beaconName] ?? Self.missingRSSI
                return abs(Double(expectedRSSI - observedRSSI))
            }
            guard !errors.isEmpty else { return nil }
            return Candidate(location: checkpoint, meanAbsoluteError: errors.reduce(0, +) / Double(errors.count))
        }
        .sorted { $0.meanAbsoluteError < $1.meanAbsoluteError }

        guard let best = candidates.first else {
            resetEstimate()
            return
        }

        let nextBestError = candidates.dropFirst().first?.meanAbsoluteError ?? .infinity
        // 現在地を表示した直後は、RSSIの小さな揺れで別の地点へ飛ばさない
        if currentLocation?.id != best.location.id, isHoldingCurrentLocation {
            return
        }

        let locationChanged = currentLocation?.id != best.location.id
        currentLocation = best.location
        currentPosition = best.location.iconPosition
        if locationChanged {
            locationConfirmedAt = now
        }
        confidence = Self.confidence(
            meanAbsoluteError: best.meanAbsoluteError,
            margin: nextBestError - best.meanAbsoluteError,
            receivedBeaconCount: currentRSSI.count
        )
    }

    /// 端末の加速度から歩行・端末移動を検出する
    private func startMotionDetection() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            guard error == nil, let acceleration = motion?.userAcceleration else { return }
            let magnitude = sqrt(
                acceleration.x * acceleration.x
                    + acceleration.y * acceleration.y
                    + acceleration.z * acceleration.z
            )

            Task { @MainActor [weak self] in
                self?.recordMotionAcceleration(magnitude)
            }
        }
    }

    /// 連続した加速度を受け取った時点で推定を無効化する。単発の手ぶれは無視する
    private func recordMotionAcceleration(_ magnitude: Double) {
        guard magnitude >= Self.movementAccelerationThreshold else {
            consecutiveMotionSampleCount = 0
            return
        }

        consecutiveMotionSampleCount += 1
        guard consecutiveMotionSampleCount >= Self.consecutiveMotionSamplesRequired else { return }

        // 現在地を確定した直後は、少し端末が動いても表示を保持する
        guard !isHoldingCurrentLocation else { return }
        lastMotionDetectedAt = .now
        guard !isMoving else { return }

        isMoving = true
        stationaryMeasurementStartedAt = nil
        isPreparingEstimate = false
        locationConfirmedAt = nil
        samples = [:]
        resetEstimate()
    }

    /// 一定時間動きがなければ、停止後の RSSI を改めて集め始める
    private func updateMovementState() {
        guard isMoving,
              let lastMotionDetectedAt,
              Date.now.timeIntervalSince(lastMotionDetectedAt) >= Self.stationaryDelay
        else {
            return
        }

        isMoving = false
        consecutiveMotionSampleCount = 0
        beginStationaryMeasurement()
    }

    private func beginStationaryMeasurement() {
        samples = [:]
        stationaryMeasurementStartedAt = .now
        isPreparingEstimate = true
        resetEstimate()
    }

    private func resetEstimate() {
        currentRSSI = [:]
        currentLocation = nil
        currentPosition = nil
        nearestBeacon = nil
        confidence = .unavailable
        locationConfirmedAt = nil
    }

    private var isHoldingCurrentLocation: Bool {
        guard let locationConfirmedAt else { return false }
        return Date.now.timeIntervalSince(locationConfirmedAt) < Self.locationHoldDuration
    }

    /// 誤差が小さく、次点との差が大きく、2台以上を受信できているほど信頼度を上げる
    private static func confidence(
        meanAbsoluteError: Double,
        margin: Double,
        receivedBeaconCount: Int
    ) -> LocationConfidence {
        guard receivedBeaconCount >= 2 else { return .low }
        if meanAbsoluteError <= 8, margin >= 4 { return .high }
        if meanAbsoluteError <= 15, margin >= 2 { return .medium }
        return .low
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

private struct RSSISample {
    let value: Int
    let receivedAt: Date
}

private struct Candidate {
    let location: Location
    let meanAbsoluteError: Double
}
