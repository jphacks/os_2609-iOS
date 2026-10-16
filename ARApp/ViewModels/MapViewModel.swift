//
//  MapViewModel.swift
//  ARApp
//

import Foundation
import Observation

/// マップ画面の状態。現在地の場所 ID と、マップに出すモンスター・レイド地点を管理する
@Observable
final class MapViewModel {
    let spots: [MapSpot]
    /// 今は固定データ。サーバーから受け取るようになったら private(set) の var にして、更新用のメソッドを足す
    let monsterSpots: [MonsterSpot]
    let raidSpots: [RaidSpot]
    /// 現在地の場所 ID。まだ分からない間は nil
    private(set) var currentSpotID: String?

    /// 現在地の場所。ID が `spots` にないときは nil
    var currentSpot: MapSpot? {
        spots.first { $0.id == currentSpotID }
    }

    init(
        spots: [MapSpot] = MapSpot.all,
        monsterSpots: [MonsterSpot] = MonsterSpot.samples,
        raidSpots: [RaidSpot] = RaidSpot.samples,
        currentSpotID: String? = nil
    ) {
        self.spots = spots
        self.monsterSpots = monsterSpots
        self.raidSpots = raidSpots
        self.currentSpotID = currentSpotID
    }

    /// 位置推定の結果を反映する。知らない ID は無視して、今の位置のままにする
    func updateCurrentSpot(id: String) {
        guard spots.contains(where: { $0.id == id }) else { return }
        currentSpotID = id
    }
}
