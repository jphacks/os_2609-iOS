//
//  SupabaseBattleService.swift
//  ARApp
//

import Foundation
import Supabase

/// Supabase で対戦相手とやり取りする
/// テーブルと関数の定義は リポジトリ直下の supabase/schema.sql にある
/// - 相手探し：join_battle 関数を呼ぶ。待っている人がいれば入り、いなければ部屋を作って待つ
/// - 攻撃：battle_moves テーブルに 1 ターンぶんずつ書き込み、相手の書き込みを Realtime で受け取る
final class SupabaseBattleService: BattleService {
    enum ServiceError: Error {
        /// 部屋を作って待っても、相手が来なかった
        case noOpponent
        /// 相手の攻撃が一定時間届かない、または相手が対戦をやめた
        case opponentLeft
        /// 届いたモンスター名や判定が、アプリの知らない値だった
        case invalidData
        /// 参加中の対戦がないのに、攻撃を送ろうとした・受け取ろうとした
        case notInBattle
    }

    /// 部屋を作ってからこの時間待っても相手が来なければ、あきらめる（秒）
    /// join_battle は 2 分より古い部屋を使わないので、それより少し短くする
    private static let matchingTimeout: TimeInterval = 110
    /// 相手の攻撃をこの時間待っても届かなければ、相手がいなくなったとみなす（秒）
    private static let opponentTimeout: TimeInterval = 60
    /// 攻撃を送るのに失敗したとき、何回まで試すか
    private static let sendAttempts = 3
    /// Realtime を取りこぼしたときのために、データベースを直接見に行く間隔（秒）
    private static let fallbackFetchInterval: TimeInterval = 2

    private let client: SupabaseClient
    /// 自分を見分ける ID。ログインは使わず、アプリを起動するたびに作り直す
    private let playerID = UUID()

    /// 参加中の対戦の ID
    private var battleID: UUID?
    /// 参加中の対戦の変更を受け取る Realtime のチャンネル
    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    /// 受け取った相手の攻撃（ターン番号ごと）
    private var opponentMoves: [Int: BattleMove] = [:]
    /// 相手が入ってきたら入る、相手のモンスター名
    private var opponentMonsterName: String?
    /// 相手が対戦をやめたら true
    private var isOpponentGone = false

    init(url: URL, anonKey: String) {
        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }

    func findOpponent(locationID: String, monster: Monster) async throws -> BattleMatch {
        await leave()
        do {
            return try await joinAndWait(locationID: locationID, monster: monster)
        } catch {
            // キャンセルされたり失敗したりしたら、作った部屋が相手待ちのまま残らないように片付ける
            // キャンセルされた Task の中で通信すると通信まで取り消されるので、別の Task で片付けて終わるのを待つ
            await Task { await leave() }.value
            throw error
        }
    }

    /// join_battle で部屋に入り（または作り）、相手がそろうまで待つ
    private func joinAndWait(locationID: String, monster: Monster) async throws -> BattleMatch {
        // 途中でキャンセルされても通信は最後まで行い、部屋の ID を受け取ってから片付けられるようにする
        // （通信ごと取り消すと、サーバーには部屋ができたのに ID がわからず消せなくなる）
        let params = JoinBattleParams(locationID: locationID, playerID: playerID, monster: monster.modelName)
        let row: BattleRow = try await Task { [client] in
            try await client.rpc("join_battle", params: params).execute().value
        }.value
        battleID = row.id
        try Task.checkCancellation()

        let isPlayer1 = row.player1ID == playerID
        opponentMonsterName = isPlayer1 ? row.player2Monster : row.player1Monster
        try await startListening(battleID: row.id)

        // 自分が部屋を作った場合は、相手が入ってくるまで待つ
        // Realtime を取りこぼしたときのために、ときどきデータベースも直接見る（購読を始める前に入ってきた場合もここで気づく）
        let deadline = Date.now.addingTimeInterval(Self.matchingTimeout)
        var nextFetch = Date.now
        while opponentMonsterName == nil {
            guard Date.now < deadline else { throw ServiceError.noOpponent }
            if Date.now >= nextFetch {
                // 通信が一瞬切れても失敗にせず、次の確認を待つ
                if let battle = try? await fetchBattle(id: row.id), let name = battle.player2Monster {
                    opponentMonsterName = name
                }
                nextFetch = Date.now.addingTimeInterval(Self.fallbackFetchInterval)
            }
            try await Task.sleep(for: .milliseconds(200))
        }

        guard let name = opponentMonsterName, let opponent = Monster.named(name) else {
            throw ServiceError.invalidData
        }
        return BattleMatch(id: row.id.uuidString, myMonster: monster, opponentMonster: opponent)
    }

    func send(_ move: BattleMove, turn: Int) async throws {
        guard let battleID else { throw ServiceError.notInBattle }
        let row = MoveRow(
            battleID: battleID,
            playerID: playerID,
            turn: turn,
            attackType: move.attackType.rawValue,
            judgements: move.judgements.map(\.rawValue)
        )

        // 通信が一瞬切れても対戦が終わらないように、少し待ってやり直す
        // 書き込めたのに返事だけ届かなかった場合に備えて、同じターンの行がすでにあれば何もしない（ON CONFLICT DO NOTHING）
        var attempt = 1
        while true {
            do {
                try await client
                    .from("battle_moves")
                    .upsert(row, onConflict: "battle_id,player_id,turn", ignoreDuplicates: true)
                    .execute()
                return
            } catch {
                guard attempt < Self.sendAttempts, !Task.isCancelled else { throw error }
                attempt += 1
                try await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func opponentMove(turn: Int) async throws -> BattleMove {
        guard let battleID else { throw ServiceError.notInBattle }
        let deadline = Date.now.addingTimeInterval(Self.opponentTimeout)
        var nextFetch = Date.now.addingTimeInterval(Self.fallbackFetchInterval)

        while Date.now < deadline {
            if let move = opponentMoves[turn] { return move }
            if isOpponentGone {
                // 相手は攻撃を送ってからやめたかもしれない（最後のターンなど）
                // Realtime で取りこぼしていた場合に備えて、もう一度だけデータベースを見る
                try? await fetchOpponentMoves(battleID: battleID)
                if let move = opponentMoves[turn] { return move }
                throw ServiceError.opponentLeft
            }

            // Realtime で届かないままのときは、データベースを直接見る
            // 通信が一瞬切れても失敗にせず、次の確認を待つ（相手がいなくなったかはタイムアウトで判断する）
            if Date.now >= nextFetch {
                try? await fetchOpponentMoves(battleID: battleID)
                if let battle = try? await fetchBattle(id: battleID), battle.status == "finished" {
                    isOpponentGone = true
                }
                nextFetch = Date.now.addingTimeInterval(Self.fallbackFetchInterval)
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw ServiceError.opponentLeft
    }

    func leave() async {
        // 先に状態を空にしてから通信する。通信を待っている間に次の相手探しが始まっても、新しい対戦に触れないようにする
        let leavingBattleID = battleID
        let leavingChannel = channel
        listenTask?.cancel()
        listenTask = nil
        channel = nil
        battleID = nil
        opponentMoves = [:]
        opponentMonsterName = nil
        isOpponentGone = false

        if let leavingChannel {
            await client.removeChannel(leavingChannel)
        }
        // 相手待ちの部屋が残らないように、対戦を終わったことにする。対戦中なら相手にも伝わる
        if let leavingBattleID {
            _ = try? await client
                .from("battles")
                .update(["status": "finished"])
                .eq("id", value: leavingBattleID)
                .execute()
        }
    }

    /// 対戦の変更（相手が入った・終わった）と、相手の攻撃を Realtime で受け取り始める
    private func startListening(battleID: UUID) async throws {
        let channel = client.channel("battle-\(battleID.uuidString)")
        // 受け取りたい変更は、購読を始める前に登録しておく
        let battleUpdates = channel.postgresChange(
            UpdateAction.self, table: "battles", filter: .eq("id", value: battleID)
        )
        let moveInserts = channel.postgresChange(
            InsertAction.self, table: "battle_moves", filter: .eq("battle_id", value: battleID)
        )
        // 購読に失敗したりキャンセルされたりしても leave() で閉じられるよう、先に持っておく
        self.channel = channel
        try await channel.subscribeWithError()

        listenTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in
                    for await update in battleUpdates {
                        guard let row = try? update.decodeRecord(as: BattleRow.self, decoder: JSONDecoder()) else { continue }
                        self?.receive(row)
                    }
                }
                group.addTask { @MainActor in
                    for await insert in moveInserts {
                        guard let row = try? insert.decodeRecord(as: MoveRow.self, decoder: JSONDecoder()) else { continue }
                        self?.receive(row)
                    }
                }
            }
        }
    }

    private func receive(_ row: BattleRow) {
        if row.player1ID == playerID, let name = row.player2Monster {
            opponentMonsterName = name
        }
        if row.status == "finished" {
            isOpponentGone = true
        }
    }

    private func receive(_ row: MoveRow) {
        guard row.playerID != playerID,
              let attackType = AttackType(rawValue: row.attackType) else { return }
        let judgements = row.judgements.compactMap(TimingJudgement.init(rawValue:))
        opponentMoves[row.turn] = BattleMove(attackType: attackType, judgements: judgements)
    }

    private func fetchBattle(id: UUID) async throws -> BattleRow {
        try await client.from("battles").select().eq("id", value: id).single().execute().value
    }

    private func fetchOpponentMoves(battleID: UUID) async throws {
        let rows: [MoveRow] = try await client
            .from("battle_moves")
            .select()
            .eq("battle_id", value: battleID)
            .neq("player_id", value: playerID)
            .execute()
            .value
        rows.forEach(receive)
    }
}

// MARK: - テーブルの行（supabase/schema.sql の列と対応する）

nonisolated private struct BattleRow: Codable, Sendable {
    let id: UUID
    let status: String
    let player1ID: UUID
    let player1Monster: String
    let player2ID: UUID?
    let player2Monster: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case player1ID = "player1_id"
        case player1Monster = "player1_monster"
        case player2ID = "player2_id"
        case player2Monster = "player2_monster"
    }
}

nonisolated private struct MoveRow: Codable, Sendable {
    let battleID: UUID
    let playerID: UUID
    let turn: Int
    let attackType: String
    let judgements: [String]

    enum CodingKeys: String, CodingKey {
        case battleID = "battle_id"
        case playerID = "player_id"
        case turn
        case attackType = "attack_type"
        case judgements
    }
}

nonisolated private struct JoinBattleParams: Encodable, Sendable {
    let locationID: String
    let playerID: UUID
    let monster: String

    enum CodingKeys: String, CodingKey {
        case locationID = "p_location_id"
        case playerID = "p_player_id"
        case monster = "p_monster"
    }
}
