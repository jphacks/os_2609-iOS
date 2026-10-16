//
//  RealtimeBattleState.swift
//  ARApp
//

import Foundation

/// リアルタイムバトルの決着
enum RealtimeBattleOutcome {
    /// 敵の HP を 0 にした
    case won
    /// プレイヤーの HP が 0 になった
    case lost
}

/// リアルタイムバトルの HP やゲージ。将来サーバーと同期するときは、この値をやり取りする想定
/// （タイミングバトルの BattleState とは別物）
struct RealtimeBattleState {
    static let playerMaxHP = 100
    static let enemyMaxHP = 300
    static let specialGaugeMax = 100

    let playerName: String
    let enemyName: String
    var playerHP = RealtimeBattleState.playerMaxHP
    var enemyHP = RealtimeBattleState.enemyMaxHP
    /// 必殺技ゲージ（0〜specialGaugeMax）
    var specialGauge = 0
    /// この時刻になるまで次の通常攻撃はできない（クールダウン）
    var nextNormalAttackAt = Date.distantPast
    /// 決着がついていなければ nil
    var outcome: RealtimeBattleOutcome?

    /// ゲージが満タンなら必殺技を使える
    var canUseSpecial: Bool { specialGauge >= RealtimeBattleState.specialGaugeMax }
}
