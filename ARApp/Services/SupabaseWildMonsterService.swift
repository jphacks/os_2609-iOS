//
//  SupabaseWildMonsterService.swift
//  ARApp
//

import Foundation
import Supabase

/// Supabase で、会場に出現しているモンスターをプレイヤー全員で共有する
/// テーブルと関数の定義は リポジトリ直下の supabase/wild_monsters.sql にある
/// - 一覧：list_wild_monsters 関数で取得する。Realtime は使わず、WildMonsterViewModel が数秒ごとに取り直す
/// - 出現：spawn_wild_monster 関数に頼む。出してよいか（間隔、数、地点の空き）は関数の中で決まる
/// - 捕獲：capture_wild_monster 関数を呼ぶ。早い者勝ちで、捕まえられたのは 1 人だけになる
final class SupabaseWildMonsterService: WildMonsterService {
    private let client: SupabaseClient
    /// 捕まえた人として記録する ID。ログインは使わず、アプリを起動するたびに作り直す
    private let playerID = UUID()

    init(url: URL, anonKey: String) {
        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }

    func fetchWildMonsters() async throws -> [WildMonster] {
        let rows: [WildMonsterRow] = try await client.rpc("list_wild_monsters").execute().value
        // アプリの知らないモンスター（新しいバージョンで増えたものなど）は出さない
        return rows.compactMap { row in
            guard let monster = Monster.named(row.monster) else { return nil }
            return WildMonster(
                id: row.id,
                monster: monster,
                locationID: row.locationID,
                escapesAt: .now.addingTimeInterval(row.secondsLeft)
            )
        }
    }

    func spawn(locationID: Location.ID, monster: Monster) async throws {
        let params = SpawnParams(locationID: locationID, monster: monster.modelName)
        try await client.rpc("spawn_wild_monster", params: params).execute()
    }

    func capture(id: WildMonster.ID) async throws -> Bool {
        let params = CaptureParams(id: id, playerID: playerID)
        return try await client.rpc("capture_wild_monster", params: params).execute().value
    }
}

// MARK: - 関数の戻り値と引数（supabase/wild_monsters.sql と対応する）

nonisolated private struct WildMonsterRow: Decodable, Sendable {
    let id: UUID
    let locationID: String
    let monster: String
    /// 逃げるまでの残り秒数
    let secondsLeft: Double

    enum CodingKeys: String, CodingKey {
        case id, monster
        case locationID = "location_id"
        case secondsLeft = "seconds_left"
    }
}

nonisolated private struct SpawnParams: Encodable, Sendable {
    let locationID: String
    let monster: String

    enum CodingKeys: String, CodingKey {
        case locationID = "p_location_id"
        case monster = "p_monster"
    }
}

nonisolated private struct CaptureParams: Encodable, Sendable {
    let id: UUID
    let playerID: UUID

    enum CodingKeys: String, CodingKey {
        case id = "p_id"
        case playerID = "p_player_id"
    }
}
