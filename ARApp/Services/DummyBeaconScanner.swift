//
//  DummyBeaconScanner.swift
//  ARApp
//
//  ⚠️⚠️⚠️ 開発用のコード ⚠️⚠️⚠️
//  ESP32 がないとき（シミュレータ・プレビュー）に、本物のビーコンの代わりに使う。
//  本番では使わないが、シミュレータとプレビューが動かなくなるので削除しない。
//  使っている場所：ContentView の makeScanner()（シミュレータのとき）と、各 View の #Preview
//  init(walkingThrough:) は MapView の #Preview で使っている。実機で試すときは、手元だけ makeScanner() をこれに差し替える（コミットしない）
//

import Foundation

/// 【開発用】ESP32 がなくても動かせるダミー実装
/// 指定した地点の RSSI のパターンに少し揺れを加えて、本物のビーコンのように流し続ける
final class DummyBeaconScanner: BeaconScanner {
    var onReceive: ((_ beaconName: String, _ rssi: Int) -> Void)?

    /// 巡る地点の RSSI のパターン。1 つだけならそこに立ち続ける
    private let route: [[Int]]
    /// 1 つの地点に立ち止まる時間（秒）
    private let stayDuration: TimeInterval
    /// 次の地点まで歩く時間（秒）
    private let walkDuration: TimeInterval
    private var emitTask: Task<Void, Never>?

    /// 初期値は登録済みの最初の地点（地点1）に立っているときのパターン
    init(location: Location = Location.registered[0]) {
        route = [location.fingerprint]
        stayDuration = 0
        walkDuration = 0
    }

    /// 地点を順番に巡り続ける。最後の地点の次は最初の地点へ戻る
    /// 歩いている間は、2 地点のパターンを歩いた割合で混ぜて流す（地点と地点の間にいる状態を作る）
    init(walkingThrough locations: [Location], stayDuration: TimeInterval = 4, walkDuration: TimeInterval = 6) {
        route = locations.map(\.fingerprint)
        self.stayDuration = stayDuration
        self.walkDuration = walkDuration
    }

    func start() {
        guard emitTask == nil else { return }
        let startedAt = Date.now
        emitTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let fingerprint = self.fingerprint(elapsed: Date.now.timeIntervalSince(startedAt))
                for (name, rssi) in zip(Location.beaconNames, fingerprint) {
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

    /// 流し始めてからの経過時間に対する RSSI のパターン
    private func fingerprint(elapsed: TimeInterval) -> [Int] {
        guard route.count > 1 else { return route[0] }

        // 「立ち止まる → 次の地点へ歩く」を 1 区間として、全区間を繰り返す
        let legDuration = stayDuration + walkDuration
        let time = elapsed.truncatingRemainder(dividingBy: legDuration * Double(route.count))
        let leg = Int(time / legDuration)
        let from = route[leg]
        let to = route[(leg + 1) % route.count]

        let walked = time - Double(leg) * legDuration - stayDuration
        guard walked > 0 else { return from }
        let ratio = walked / walkDuration
        return zip(from, to).map { Int((Double($0) + Double($1 - $0) * ratio).rounded()) }
    }
}
