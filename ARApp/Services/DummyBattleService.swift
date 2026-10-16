//
//  DummyBattleService.swift
//  ARApp
//

import Foundation

/// ⚠️ 開発用：Supabase がなくても対戦を試せるダミー実装
/// すぐに相手が見つかり、相手はランダムに攻撃してくる（CPU）
/// 削除するときは、ContentView の makeBattleService でこのクラスを使っている箇所も消す
final class DummyBattleService: BattleService {
    private var opponentMonster: Monster?

    func findOpponent(locationID: String, monster: Monster) async throws -> BattleMatch {
        try await Task.sleep(for: .seconds(1.5))
        let opponent = Monster.all.randomElement()!
        opponentMonster = opponent
        return BattleMatch(id: UUID().uuidString, myMonster: monster, opponentMonster: opponent)
    }

    func send(_ move: BattleMove, turn: Int) async throws {}

    func opponentMove(turn: Int) async throws -> BattleMove {
        // 相手も考えたり STOP を押したりしているように、少し待ってから返す
        try await Task.sleep(for: .seconds(Double.random(in: 0.5...2)))
        let zoneCount = opponentMonster.map { BattleProfile.of($0).zoneCount } ?? 3
        let judgements: [TimingJudgement] = (0..<zoneCount).map { _ in
            [.perfect, .good, .good, .miss].randomElement()!
        }
        return BattleMove(attackType: Bool.random() ? .normal : .strong, judgements: judgements)
    }

    func leave() async {
        opponentMonster = nil
    }
}
