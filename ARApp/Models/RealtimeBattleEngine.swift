//
//  RealtimeBattleEngine.swift
//  ARApp
//

import Foundation

/// リアルタイムバトルのルール（攻撃・ダメージ）。状態を受け取って書き換えるだけで、タイマーや画面は持たない
/// 時刻は外から渡すので、同じ入力なら必ず同じ結果になる（将来サーバーで同じ判定をしやすくするため）
enum RealtimeBattleEngine {
    static let normalAttackDamage = 10
    /// 通常攻撃のクールダウン（秒）
    static let normalAttackCooldown: TimeInterval = 0.3

    /// 通常攻撃。当たれば与えたダメージを返し、クールダウン中などで攻撃できなければ nil を返す
    static func normalAttack(_ state: inout RealtimeBattleState, at now: Date) -> Int? {
        guard state.enemyHP > 0, now >= state.nextNormalAttackAt else { return nil }

        let damage = min(normalAttackDamage, state.enemyHP)
        state.enemyHP -= damage
        state.nextNormalAttackAt = now.addingTimeInterval(normalAttackCooldown)
        return damage
    }
}
