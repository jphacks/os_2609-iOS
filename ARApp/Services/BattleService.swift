//
//  BattleService.swift
//  ARApp
//

import Foundation

/// 対戦相手とのやり取り
/// 本番は SupabaseBattleService、Supabase がないときは DummyBattleService（CPU が相手）を使う
protocol BattleService: AnyObject {
    /// 対戦相手を探す。pairingToken を渡した場合は、BLE で相互認識した同じ相手だけと対戦する
    /// 誰も待っていなければ、自分が待つ側になって相手が来るまで待ち続ける
    /// 待っている間に Task がキャンセルされたら、待つのをやめる
    /// 見つかった相手のモンスターを返す
    func findOpponent(monster: Monster, pairingToken: UUID?) async throws -> Monster

    /// 相手の行動が、相手が行った順に流れてくる。for try await で受け取る
    /// 決着がつくと終わり、相手が対戦をやめたり通信できなくなったりするとエラーで終わる
    func opponentActions() -> AsyncThrowingStream<BattleAction, Error>

    /// 自分の行動を相手に送る。待たずに戻り、送るのは裏で順番に行う
    func send(_ action: BattleAction)

    /// 決着を伝え、確定した結果（自分が勝ったか）を返す
    /// 2 人がほぼ同時にとどめを刺すと、端末ごとに自分の勝ちと計算してしまうので、先に伝えた方の結果にそろえる
    func finish(iWon: Bool) async throws -> Bool

    /// 対戦や相手探しをやめる
    func leave() async
}
