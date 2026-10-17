//
//  MonsterCollection.swift
//  ARApp
//

/// 捕まえたモンスターを保存する
/// 今は端末の中だけに保存するモック（SwiftDataMonsterCollection）を使う
/// 共有の DB に替えるときは、この protocol の実装を差し替える
protocol MonsterCollection {
    /// 捕まえたモンスターを保存する。同じ種類をすでに持っていれば、件数は増えない
    func add(_ monster: Monster)
}
