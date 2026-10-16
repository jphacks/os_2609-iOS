//
//  BattleService.swift
//  ARApp
//

import Foundation

/// 対戦相手とのやり取り
/// 本番は SupabaseBattleService、Supabase がないときは DummyBattleService を使う
protocol BattleService: AnyObject {
    /// 同じ地点で対戦相手を探す。誰も待っていなければ、自分が待つ側になって相手が来るまで待つ
    /// 待っている間に Task がキャンセルされたら、待つのをやめる
    func findOpponent(locationID: String, monster: Monster) async throws -> BattleMatch

    /// 自分の 1 ターンぶんの攻撃を送る
    func send(_ move: BattleMove, turn: Int) async throws

    /// 相手の 1 ターンぶんの攻撃を受け取る。相手がまだ送っていなければ届くまで待つ
    func opponentMove(turn: Int) async throws -> BattleMove

    /// 対戦や相手探しをやめる
    func leave() async
}
