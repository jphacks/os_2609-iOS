//
//  FeverLottery.swift
//  ARApp
//

import Foundation

/// フィーバーの抽選（パチンコのように、攻撃するたびに抽選して、ときどきリーチになる）
/// リーチになったら、スロットが「7 7 ？」と回り、3 つ目が 7 で止まればフィーバー
/// 赤いリーチ（激アツ）は当たりやすい
/// 抽選は攻撃した端末で行い、当たったら fever を相手に送る
enum FeverLottery {
    /// 通常攻撃 1 回でリーチになる確率
    static let reachChance = 0.1
    /// リーチが赤（激アツ）になる確率
    static let hotChance = 0.25
    /// リーチが当たる確率。青と赤
    static let normalWinChance = 0.35
    static let hotWinChance = 0.8

    /// 抽選した結果のリーチ。リーチになってから結果が出るまで、BattleViewModel が持つ
    struct Reach: Identifiable {
        let id = UUID()
        /// 赤いリーチ（激アツ）か
        let isHot: Bool
        /// 当たりか。View は、スロットを止めるときにだけ見る
        let willWin: Bool
    }

    /// 通常攻撃 1 回ぶん抽選する。リーチにならなければ nil
    static func draw() -> Reach? {
        guard Double.random(in: 0..<1) < reachChance else { return nil }
        let isHot = Double.random(in: 0..<1) < hotChance
        let willWin = Double.random(in: 0..<1) < (isHot ? hotWinChance : normalWinChance)
        return Reach(isHot: isHot, willWin: willWin)
    }
}
