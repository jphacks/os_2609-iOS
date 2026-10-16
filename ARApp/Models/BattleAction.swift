//
//  BattleAction.swift
//  ARApp
//

/// バトル中に取れる行動。オンライン対戦では、この値を相手に送る
enum BattleAction: String, Codable {
    case normalAttack
    case specialAttack
}
