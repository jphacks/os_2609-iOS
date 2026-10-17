//
//  DummyBattleService.swift
//  ARApp
//
//  ⚠️⚠️⚠️ 開発用のコード ⚠️⚠️⚠️
//  Supabase がないとき（接続先の plist がない・プレビュー）に、本物の対戦相手の代わりに使う。
//  本番では使わないが、プレビューと鍵を持っていないメンバーの環境で対戦画面が動かなくなるので削除しない。
//  使っている場所：ContentView の makeBattleService()（plist がないとき）と、BattleView の #Preview
//

import Foundation

/// 【開発用】Supabase がなくても対戦を試せるダミー実装
/// すぐに相手が見つかり、相手（CPU）は一定の間隔で通常攻撃してくる。必殺技ゲージが溜まったら必殺技を撃つ
/// こちらの必殺技は、ときどきよける
final class DummyBattleService: BattleService {
    /// CPU が攻撃する間隔（秒）
    private static let attackInterval: Double = 1
    /// CPU がこちらの必殺技をよける確率
    private static let dodgeChance = 0.3
    /// 必殺技ゲージが満タンになるまでの通常攻撃の回数
    private static let attacksBeforeSpecial = Fighter.specialGaugeMax / BattleEngine.specialGaugeGain

    /// CPU の行動を流す先。こちらの必殺技に、受けたかよけたかを返すのに使う
    private var continuation: AsyncThrowingStream<BattleAction, Error>.Continuation?

    func findOpponent(monster: Monster) async throws -> Monster {
        try await Task.sleep(for: .seconds(1.5))
        return Monster.all.randomElement()!
    }

    func opponentActions() -> AsyncThrowingStream<BattleAction, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
            let task = Task {
                var attackCount = 0
                while true {
                    do {
                        try await Task.sleep(for: .seconds(Self.attackInterval))
                    } catch {
                        break // キャンセルされた
                    }
                    if attackCount == Self.attacksBeforeSpecial {
                        attackCount = 0
                        continuation.yield(.specialAttack)
                    } else {
                        attackCount += 1
                        continuation.yield(.normalAttack)
                    }
                }
                continuation.finish()
            }
            // 受け取る側が止まったら（決着した、対戦をやめた）攻撃も止める
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func send(_ action: BattleAction) {
        // CPU が気にするのは必殺技だけ。本物の相手と同じく、予告の時間がたってから結果を返す
        guard action == .specialAttack else { return }
        Task {
            try? await Task.sleep(for: .seconds(BattleViewModel.dangerDuration))
            continuation?.yield(Double.random(in: 0..<1) < Self.dodgeChance ? .dodgeSpecial : .takeSpecial)
        }
    }

    func finish(iWon: Bool) async throws -> Bool {
        iWon
    }

    func leave() async {}
}
