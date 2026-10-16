//
//  BattleOpponent.swift
//  ARApp
//

/// バトルの対戦相手。ローカルの AI でも、将来のオンライン相手（Supabase / Firebase）でも、同じ形で ViewModel に行動を届ける
protocol BattleOpponent {
    /// 相手の名前や HP
    var fighter: RealtimeFighter { get }

    /// 相手の行動が届くたびに流れてくる。for await で受け取り、Task がキャンセルされると止まる
    /// バトルを始める（やり直す）たびに呼ぶ
    func actions() -> AsyncStream<BattleAction>

    /// 自分の行動を相手に伝える
    func send(_ action: BattleAction)
}
