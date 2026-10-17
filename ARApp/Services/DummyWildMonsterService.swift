//
//  DummyWildMonsterService.swift
//  ARApp
//
//  ⚠️⚠️⚠️ 開発用のコード ⚠️⚠️⚠️
//  Supabase がないとき（接続先の plist がない）に、本物の共有の代わりに使う。
//  ほかのプレイヤーとは共有せず、この端末の中だけでモンスターを出す。
//  本番では使わないが、鍵を持っていないメンバーの環境で捕獲画面が動かなくなるので削除しない。
//  使っている場所：ContentView の makeWildMonsterService()（plist がないとき）
//

import Foundation

/// 【開発用】Supabase がなくても捕獲を試せるダミー実装
/// 出現のルール（会場全体で 2 体まで、1 つの地点に 1 体まで、3 分で逃げる）は Supabase 版と同じにする（前の出現からの間隔は WildMonsterViewModel のタイマーに任せる）
final class DummyWildMonsterService: WildMonsterService {
    /// 会場全体で同時に出現しているモンスターの最大数
    private static let maxCount = 2
    /// 出現してから逃げるまでの時間（秒）
    private static let escapeDelay: TimeInterval = 180

    private var wildMonsters: [WildMonster] = []

    func fetchWildMonsters() async throws -> [WildMonster] {
        removeEscaped()
        return wildMonsters
    }

    func spawn(locationID: Location.ID, monster: Monster) async throws {
        removeEscaped()
        guard wildMonsters.count < Self.maxCount,
              !wildMonsters.contains(where: { $0.locationID == locationID }) else { return }
        wildMonsters.append(WildMonster(
            id: UUID(),
            monster: monster,
            locationID: locationID,
            escapesAt: .now.addingTimeInterval(Self.escapeDelay)
        ))
    }

    func capture(id: WildMonster.ID) async throws -> Bool {
        removeEscaped()
        guard wildMonsters.contains(where: { $0.id == id }) else { return false }
        wildMonsters.removeAll { $0.id == id }
        return true
    }

    private func removeEscaped() {
        wildMonsters.removeAll { $0.escapesAt <= .now }
    }
}
