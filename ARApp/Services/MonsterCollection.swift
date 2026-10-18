//
//  MonsterCollection.swift
//  ARApp
//

/// 捕まえたモンスターと、バトルに出すモンスターを保存する
/// 今は端末の中だけに保存するモック（SwiftDataMonsterCollection）を使う
/// 共有の DB に替えるときは、この protocol の実装を差し替える
protocol MonsterCollection {
    /// 捕まえたモンスターを保存する。同じ種類をすでに持っていれば、件数は増えない
    func add(_ monster: Monster)

    /// 捕まえたモンスター。Monster.all と同じ順に並べる（図鑑や編成のマスの順）
    var capturedMonsters: [Monster] { get }

    /// バトルに出すモンスター。まだ選んでいなければ nil
    var battleMonster: Monster? { get }

    /// バトルに出すモンスターを決める（最初にモンスターを選んだとき、編成で選び直したとき）
    /// - Returns: 保存できたか。保存できなかったときは、前に選んでいたモンスターのまま
    @discardableResult
    func setBattleMonster(_ monster: Monster) -> Bool
}
