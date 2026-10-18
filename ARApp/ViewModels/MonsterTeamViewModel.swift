//
//  MonsterTeamViewModel.swift
//  ARApp
//

import Observation

/// 編成の画面の状態
/// 捕まえたモンスターから 1 体選び、バトルに出すモンスターとして保存する
@Observable
final class MonsterTeamViewModel {
    /// 選べるモンスター（捕まえたもの。Monster.all の順）
    let capturedMonsters: [Monster]
    /// バトルに出すモンスター。まだ決まっていなければ nil
    private(set) var battleMonster: Monster?

    private let collection: any MonsterCollection

    init(collection: any MonsterCollection) {
        self.collection = collection
        capturedMonsters = collection.capturedMonsters
        battleMonster = collection.battleMonster
    }

    /// バトルに出すモンスターを決めて、すぐに保存する
    func choose(_ monster: Monster) {
        guard monster.modelName != battleMonster?.modelName else { return }
        collection.setBattleMonster(monster)
        // 保存できなかったときに画面と保存先が食い違わないよう、保存先から読み直す
        battleMonster = collection.battleMonster
    }
}
