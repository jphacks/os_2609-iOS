//
//  RealtimeBattleViewModel.swift
//  ARApp
//

import Observation

/// リアルタイムバトル画面の状態と、バトルの進行
@Observable
final class RealtimeBattleViewModel {
    private(set) var state = RealtimeBattleState(playerName: "ナイト", enemyName: "ドラゴン")
}
