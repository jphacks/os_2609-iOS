//
//  RealtimeBattleState.swift
//  ARApp
//

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

    /// ゲージが満タンなら必殺技を使える
    var canUseSpecial: Bool { specialGauge >= RealtimeBattleState.specialGaugeMax }
}
