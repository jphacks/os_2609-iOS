//
//  StarterMonsterViewModel.swift
//  ARApp
//

import Observation

/// 最初にモンスターを選ぶ画面の状態
/// 手前に出ているモンスターが選ばれた状態で、決めたモンスターは捕まえたものとして保存し、バトルに出すモンスターにもする
@Observable
final class StarterMonsterViewModel {
    /// 最初に選べるモンスター（バニー、フロッグ、バード）
    /// どれも Monster.all にあるので、candidates は空にならない
    private static let candidateModelNames = ["monster-bunny", "monster-frog", "monster-birb"]

    let candidates = candidateModelNames.compactMap(Monster.named)

    /// 手前に出ている（選ばれている）モンスターの番号
    private(set) var selectedIndex = 0

    var selected: Monster { candidates[selectedIndex] }

    private let collection: any MonsterCollection

    init(collection: any MonsterCollection) {
        self.collection = collection
    }

    /// 次のモンスターを手前に出す。最後まで行ったら最初に戻る
    func showNext() {
        selectedIndex = (selectedIndex + 1) % candidates.count
    }

    /// 前のモンスターを手前に出す。最初より前は最後に戻る
    func showPrevious() {
        selectedIndex = (selectedIndex - 1 + candidates.count) % candidates.count
    }

    /// 手前に出ているモンスターに決める
    func confirm() {
        collection.add(selected)
        collection.setBattleMonster(selected)
    }
}
