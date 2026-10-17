//
//  StarterMonsterViewModel.swift
//  ARApp
//

import Observation

/// 最初にモンスターを選ぶ画面の状態
/// 決めたモンスターは、捕まえたものとして保存し、バトルに出すモンスターにもする
@Observable
final class StarterMonsterViewModel {
    /// 最初に選べるモンスター（バニー、フロッグ、バード）
    private static let candidateModelNames = ["monster-bunny", "monster-frog", "monster-birb"]

    let candidates = candidateModelNames.compactMap(Monster.named)

    /// タップして選んでいるモンスター。まだ選んでいなければ nil
    private(set) var selected: Monster?

    private let collection: any MonsterCollection

    init(collection: any MonsterCollection) {
        self.collection = collection
    }

    /// モンスターを選ぶ。ほかのモンスターを選べば選び直しになる
    func select(_ monster: Monster) {
        selected = monster
    }

    /// 選んでいるモンスターに決める
    func confirm() {
        guard let selected else { return }
        collection.add(selected)
        collection.setBattleMonster(selected)
    }
}
