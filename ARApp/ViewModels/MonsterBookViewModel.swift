//
//  MonsterBookViewModel.swift
//  ARApp
//

import Observation

/// 図鑑の画面の状態
/// 全種類のモンスターを並べ、捕まえたものだけ選んで上半分に出せる
@Observable
final class MonsterBookViewModel {
    /// 図鑑の 1 マスぶん
    struct Entry: Identifiable {
        let monster: Monster
        let isCaptured: Bool

        var id: String { monster.modelName }
    }

    /// 全種類のモンスター（Monster.all の順）
    let entries: [Entry]
    /// 捕まえた種類の数
    let capturedCount: Int
    /// 上半分に出しているモンスター。最初はバトルに出すモンスター。何も捕まえていなければ nil
    private(set) var selected: Monster?

    init(collection: any MonsterCollection) {
        let captured = collection.capturedMonsters
        let capturedNames = Set(captured.map(\.modelName))
        entries = Monster.all.map { Entry(monster: $0, isCaptured: capturedNames.contains($0.modelName)) }
        capturedCount = captured.count
        selected = collection.battleMonster ?? captured.first
    }

    /// 上半分に出すモンスターを変える。まだ捕まえていないモンスターは選べない
    func select(_ entry: Entry) {
        guard entry.isCaptured else { return }
        selected = entry.monster
    }
}
