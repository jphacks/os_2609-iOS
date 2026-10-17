//
//  SwiftDataMonsterCollection.swift
//  ARApp
//
//  ⚠️ 開発用のログあり：add(_:) の「保存している種類の数」を出す print
//  図鑑で保存した内容を見られるようになったら、その print と countForLog() を消す
//

import SwiftData

/// 【モック】捕まえたモンスターと、バトルに出すモンスターを SwiftData で端末の中に保存する
/// 捕まえたモンスターは種類（modelName）ごとに 1 件、バトルに出すモンスターは 1 件だけ持つ
final class SwiftDataMonsterCollection: MonsterCollection {
    private let context: ModelContext

    /// - Parameter inMemory: true ならメモリの中だけに保存し、アプリを閉じると消える（プレビュー用）
    init(inMemory: Bool = false) {
        context = ModelContext(Self.makeContainer(inMemory: inMemory))
    }

    func add(_ monster: Monster) {
        // modelName は一意なので、同じ種類を入れると新しく増えずに上書きになる
        context.insert(CapturedMonsterRecord(modelName: monster.modelName))
        save()
        print("【開発用】保存している種類の数: \(countForLog())")
    }

    var battleMonster: Monster? {
        let record = try? context.fetch(FetchDescriptor<BattleMonsterRecord>()).first
        return record.flatMap { Monster.named($0.modelName) }
    }

    func setBattleMonster(_ monster: Monster) {
        // 1 件だけ持つので、前に選んでいたものを消してから入れる
        try? context.delete(model: BattleMonsterRecord.self)
        context.insert(BattleMonsterRecord(modelName: monster.modelName))
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            print("モンスターを保存できませんでした: \(error)")
        }
    }

    /// 端末に保存できないとき（保存する形を変えて、前のデータを読めなくなったときなど）は、
    /// アプリが落ちないよう、メモリの中だけに保存する形に切り替える
    private static func makeContainer(inMemory: Bool) -> ModelContainer {
        let schema = Schema([CapturedMonsterRecord.self, BattleMonsterRecord.self])
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
        } catch {
            print("端末に保存できないので、メモリの中だけに保存します: \(error)")
            return try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
    }

    /// 【開発用】ファイル先頭の説明を参照
    private func countForLog() -> Int {
        (try? context.fetchCount(FetchDescriptor<CapturedMonsterRecord>())) ?? 0
    }
}

/// SwiftData に保存する、捕まえたモンスター 1 種類ぶん
/// 保存の都合だけで使う型なので、ほかの場所では Monster を使う
@Model
final class CapturedMonsterRecord {
    @Attribute(.unique) var modelName: String

    init(modelName: String) {
        self.modelName = modelName
    }
}

/// SwiftData に保存する、バトルに出すモンスター。1 件だけ持つ
/// 保存の都合だけで使う型なので、ほかの場所では Monster を使う
@Model
final class BattleMonsterRecord {
    var modelName: String

    init(modelName: String) {
        self.modelName = modelName
    }
}
