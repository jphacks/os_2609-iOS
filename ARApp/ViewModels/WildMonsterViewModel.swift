//
//  WildMonsterViewModel.swift
//  ARApp
//

import Foundation
import Observation

/// 会場のどの地点に、どのモンスターがいるかを管理する
/// モンスターはプレイヤー全員で共有する（WildMonsterService 経由）。誰かが捕まえると、全員の一覧から消える
/// マップ画面と捕獲画面で同じものを使うため、ContentView で 1 つだけ作る
@Observable
final class WildMonsterViewModel {
    /// モンスターを出すよう頼む間隔（秒）
    /// 実際に出るかは Service 側で決まる（前の出現から間がない・会場がいっぱいなら出ない）
    static let spawnIntervalRange: ClosedRange<Double> = 30...60
    /// 一覧を取り直す間隔。ほかの人の捕獲や、新しい出現に気づくまでの時間になる
    static let refreshInterval: Duration = .seconds(3)

    /// 今会場にいるモンスター
    private(set) var wildMonsters: [WildMonster] = []

    private let service: any WildMonsterService
    /// この端末で一覧から外したモンスター
    /// 外す前に取得を始めていた一覧が遅れて届いても、もう一度出てこないようにする
    private var removedIDs: Set<WildMonster.ID> = []
    private var refreshTask: Task<Void, Never>?
    private var spawnTask: Task<Void, Never>?

    init(service: any WildMonsterService) {
        self.service = service
    }

    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }
        spawnTask = Task { [weak self] in
            // 最初はすぐに頼み、そのあとはランダムな間隔で頼む
            while !Task.isCancelled {
                await self?.requestSpawn()
                try? await Task.sleep(for: .seconds(Double.random(in: Self.spawnIntervalRange)))
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        spawnTask?.cancel()
        spawnTask = nil
        wildMonsters.removeAll()
    }

    /// モンスターを捕まえる。捕獲画面の ARCaptureViewModel から呼ばれる
    /// 先に誰かが捕まえていたり、逃げていたりしたら false を返す
    func capture(id: WildMonster.ID) async throws -> Bool {
        let captured = try await service.capture(id: id)
        // 捕まえられなかったときも、もう誰かに捕まったか逃げたあとなので一覧から外す
        removedIDs.insert(id)
        wildMonsters.removeAll { $0.id == id }
        return captured
    }

    private func refresh() async {
        // 通信が一瞬切れても一覧は消さず、次の取得を待つ
        guard let monsters = try? await service.fetchWildMonsters() else { return }
        wildMonsters = monsters.filter { !removedIDs.contains($0.id) && $0.escapesAt > .now }
    }

    private func requestSpawn() async {
        // まだモンスターがいない地点から選ぶ（一覧が古くても、Service 側でもう一度確かめる）
        let emptyLocations = Location.registered.filter { location in
            !wildMonsters.contains { $0.locationID == location.id }
        }
        guard let location = emptyLocations.randomElement() else { return }
        // `Monster.all` は空ではない
        try? await service.spawn(locationID: location.id, monster: Monster.all.randomElement()!)
        await refresh()
    }
}
