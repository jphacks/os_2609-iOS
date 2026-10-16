//
//  RealtimeBattleEngine.swift
//  ARApp
//

import Foundation

/// リアルタイムバトルのルール（攻撃・ダメージ・勝敗）。状態を受け取って書き換えるだけで、タイマーや画面は持たない
/// 時刻は外から渡すので、同じ入力なら必ず同じ結果になる（将来サーバーで同じ判定をしやすくするため）
enum RealtimeBattleEngine {
    static let normalAttackDamage = 10
    /// 通常攻撃のクールダウン（秒）
    static let normalAttackCooldown: TimeInterval = 0.3
    static let enemyAttackDamage = 10
    /// 敵が攻撃する間隔（秒）
    static let enemyAttackInterval: TimeInterval = 2

    /// 通常攻撃。当たれば与えたダメージを返し、クールダウン中や決着後で攻撃できなければ nil を返す
    static func normalAttack(_ state: inout RealtimeBattleState, at now: Date) -> Int? {
        guard state.outcome == nil, state.enemyHP > 0, now >= state.nextNormalAttackAt else { return nil }

        let damage = min(normalAttackDamage, state.enemyHP)
        state.enemyHP -= damage
        state.nextNormalAttackAt = now.addingTimeInterval(normalAttackCooldown)
        return damage
    }

    /// 敵の攻撃。プレイヤーの HP が 0 になったら敗北にする。決着後は nil を返す
    static func enemyAttack(_ state: inout RealtimeBattleState) -> Int? {
        guard state.outcome == nil else { return nil }

        let damage = min(enemyAttackDamage, state.playerHP)
        state.playerHP -= damage
        if state.playerHP == 0 {
            state.outcome = .lost
        }
        return damage
    }
}
