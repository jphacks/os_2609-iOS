//
//  FeverLottery.swift
//  ARApp
//

import Foundation

/// フィーバーの抽選（パチンコのように、攻撃するたびに抽選して、ときどきチャンスになる）
/// チャンスになったら、画面を横切る帯の色が 青 → 緑 → 赤 → 金 と上がっていき、金まで上がればフィーバー
/// どこまで上がるかは、チャンスになった時点で決める
/// 抽選は攻撃した端末で行い、当たったら fever を相手に送る
enum FeverLottery {
    /// 帯の色。上の段階ほど、当たり（金）に近い
    enum Level: Int, CaseIterable {
        case blue
        case green
        case red
        case gold
    }

    /// 通常攻撃 1 回でチャンスになる確率
    static let chanceRate = 0.2
    /// チャンスになったとき、帯がどの色まで上がるかの確率（足すと 1）
    /// 赤まで上がったら、3 回に 2 回は金になる（赤が出たら期待できる）
    static let finalLevelRates: [(level: Level, rate: Double)] = [
        (.blue, 0.2),
        (.green, 0.2),
        (.red, 0.2),
        (.gold, 0.4),
    ]

    /// 抽選した結果のチャンス。チャンスになってから結果が出るまで、BattleViewModel が持つ
    struct Chance: Identifiable {
        let id = UUID()
        /// 帯がこの色まで上がって止まる
        let finalLevel: Level
        /// 当たり（金まで上がる）か
        var willWin: Bool { finalLevel == .gold }
    }

    /// 通常攻撃 1 回ぶん抽選する。チャンスにならなければ nil
    static func draw() -> Chance? {
        guard Double.random(in: 0..<1) < chanceRate else { return nil }
        var roll = Double.random(in: 0..<1)
        for (level, rate) in finalLevelRates {
            if roll < rate { return Chance(finalLevel: level) }
            roll -= rate
        }
        return Chance(finalLevel: .gold)
    }
}
