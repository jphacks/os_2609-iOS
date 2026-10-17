//
//  RealtimeBattleState.swift
//  ARApp
//

/// リアルタイムバトル全体の状態。誰から見ても同じ内容になるよう、「自分」「敵」ではなく ID で持つ
/// 将来サーバーと同期するときは、この値（または中の RealtimeFighter）をやり取りする想定
/// （タイミングバトルの BattleState とは別物）
struct RealtimeBattleState: Codable {
    var fighters: [FighterID: RealtimeFighter]
    /// 勝った人の ID。決着がついていなければ nil
    var winner: FighterID?

    /// 1 対 1 のバトルを始める
    init(_ first: RealtimeFighter, _ second: RealtimeFighter) {
        fighters = [first.id: first, second.id: second]
    }

    /// id の人の対戦相手の ID
    func opponentID(of id: FighterID) -> FighterID? {
        fighters.keys.first { $0 != id }
    }
}
