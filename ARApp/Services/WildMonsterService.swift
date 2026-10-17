//
//  WildMonsterService.swift
//  ARApp
//

import Foundation

/// 会場に出現しているモンスターを、プレイヤー全員で共有する
/// 本番は SupabaseWildMonsterService、Supabase がないときは DummyWildMonsterService（端末の中だけ）を使う
protocol WildMonsterService: AnyObject {
    /// 今会場にいるモンスター（まだ捕まっておらず、逃げていない）を取得する
    func fetchWildMonsters() async throws -> [WildMonster]

    /// 地点にモンスターを出すよう頼む
    /// 前の出現から間がない・会場がいっぱい・その地点にもういるときは、何も起きない
    func spawn(locationID: Location.ID, monster: Monster) async throws

    /// モンスターを捕まえる。早い者勝ちで、先に誰かが捕まえていたり逃げていたりしたら false を返す
    func capture(id: WildMonster.ID) async throws -> Bool
}
