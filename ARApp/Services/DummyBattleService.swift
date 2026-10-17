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
final class DummyBattleService: BattleService {
    /// CPU が攻撃する間隔（秒）
    private static let attackInterval: Double = 1
    /// 必殺技ゲージが満タンになるまでの通常攻撃の回数
    private static let attacksBeforeSpecial = Fighter.specialGaugeMax / BattleEngine.specialGaugeGain

    func findOpponent(monster: Monster, pairingToken: UUID?) async throws -> Monster {
        try await Task.sleep(for: .seconds(1.5))
        return Monster.all.randomElement()!
    }

    func opponentActions() -> AsyncThrowingStream<BattleAction, Error> {
        AsyncThrowingStream { continuation in
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
        // CPU はこちらの行動を受け取る必要がない
    }

    func finish(iWon: Bool) async throws -> Bool {
        iWon
    }

    func leave() async {}
}
