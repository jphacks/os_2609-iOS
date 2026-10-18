//
//  SwiftDataMonsterCollection.swift
//  ARApp
//
//  ⚠️ 開発用のログあり：add(_:) の「保存している種類の数」を出す print
//  図鑑で保存した内容を見られるようになったら、その print と countForLog() を消す
//

import Foundation
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
        // 1 件だけ持つので、前に選んでいたものを消してから入れる。消せなかったときに入れると 2 件になり、どちらが読まれるかわからなくなる
        do {
            try context.delete(model: BattleMonsterRecord.self)
        } catch {
            print("前に選んだモンスターを消せなかったので、選び直しを保存しません: \(error)")
            return
        }
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

    /// 端末の保存先を開けないとき（保存する形を変えて、前のデータを読めなくなったときなど）は、保存先を消して作り直す
    /// モックなので前のデータは消えてよい。メモリだけの保存のままにすると、起動のたびに最初のモンスター選びからになるため
    /// 作り直しても開けないときだけ、アプリが落ちないよう、メモリの中だけに保存する形に切り替える
    private static func makeContainer(inMemory: Bool) -> ModelContainer {
        let schema = Schema([CapturedMonsterRecord.self, BattleMonsterRecord.self])
        let inMemoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        if inMemory {
            return try! ModelContainer(for: schema, configurations: inMemoryConfiguration)
        }

        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            print("端末の保存先を開けないので、消して作り直します: \(error)")
        }
        removeStore(at: configuration.url)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            print("端末に保存できないので、メモリの中だけに保存します: \(error)")
            return try! ModelContainer(for: schema, configurations: inMemoryConfiguration)
        }
    }

    /// SwiftData（SQLite）の保存ファイルを消す。本体のほかに -wal と -shm のファイルがある
    private static func removeStore(at url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
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
