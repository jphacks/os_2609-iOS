//
//  WildMonsterViewModel.swift
//  ARApp
//

import Foundation
import Observation

/// 会場のどの地点に、どのモンスターがいるかを管理する
/// ときどきランダムな地点に 1 体出現し、しばらく捕まえられないと逃げる
/// マップ画面と捕獲画面で同じものを使うため、ContentView で 1 つだけ作る
@Observable
final class WildMonsterViewModel {
    /// 会場全体で同時に出現しているモンスターの最大数
    static let maxCount = 2
    /// 次の 1 体が出現するまでの間隔（秒）
    static let spawnIntervalRange: ClosedRange<Double> = 30...60
    /// 出現してから逃げるまでの時間
    static let escapeDelay: Duration = .seconds(180)

    /// 今出現しているモンスター。1 つの地点には 1 体まで
    private(set) var wildMonsters: [WildMonster] = []

    private var spawnTask: Task<Void, Never>?
    /// モンスターごとの、逃げるまでのタイマー
    private var escapeTasks: [WildMonster.ID: Task<Void, Never>] = [:]

    func start() {
        guard spawnTask == nil else { return }
        spawnTask = Task { [weak self] in
            // 最初の 1 体はすぐに出し、そのあとはランダムな間隔で出す
            while !Task.isCancelled {
                self?.spawn()
                try? await Task.sleep(for: .seconds(Double.random(in: Self.spawnIntervalRange)))
            }
        }
    }

    func stop() {
        spawnTask?.cancel()
        spawnTask = nil
        escapeTasks.values.forEach { $0.cancel() }
        escapeTasks.removeAll()
        wildMonsters.removeAll()
    }

    /// 捕まえたモンスターを会場からいなくする。捕獲画面の ARCaptureViewModel から呼ばれる
    func capture(id: WildMonster.ID) {
        escapeTasks.removeValue(forKey: id)?.cancel()
        wildMonsters.removeAll { $0.id == id }
    }

    private func spawn() {
        guard wildMonsters.count < Self.maxCount else { return }
        // まだモンスターがいない地点から選ぶ
        let emptyLocations = Location.registered.filter { location in
            !wildMonsters.contains { $0.locationID == location.id }
        }
        // `Monster.all` は空ではない
        guard let location = emptyLocations.randomElement() else { return }
        let wild = WildMonster(monster: Monster.all.randomElement()!, locationID: location.id)
        wildMonsters.append(wild)

        escapeTasks[wild.id] = Task { [weak self] in
            try? await Task.sleep(for: Self.escapeDelay)
            guard let self, !Task.isCancelled else { return }
            self.escapeTasks[wild.id] = nil
            self.wildMonsters.removeAll { $0.id == wild.id }
        }
    }
}
