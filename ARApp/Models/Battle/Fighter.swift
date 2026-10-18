//
//  Fighter.swift
//  ARApp
//

/// バトルの状態の中で、戦う人を見分ける ID
typealias FighterID = String

/// バトルで戦う 1 人ぶんの状態。自分も相手も同じ形で持つ
struct Fighter {
    static let specialGaugeMax = 100

    let id: FighterID
    let name: String
    let maxHP: Int
    var hp: Int
    /// 必殺技ゲージ（0〜specialGaugeMax）。満タンになると、自動で必殺技を撃つ
    var specialGauge = 0
    /// 前のフィーバーのあとに、フィーバーでない通常攻撃をした回数。少ないうちはフィーバーの抽選をしない
    var normalAttacksSinceFever = 0
    /// 撃たれたのに、まだ結果（受けた・よけた）を送っていない相手の必殺技の数
    var incomingSpecials = 0

    init(id: FighterID, name: String, maxHP: Int) {
        self.id = id
        self.name = name
        self.maxHP = maxHP
        hp = maxHP
    }

    /// ゲージが満タンなら必殺技を使える
    var canUseSpecial: Bool { specialGauge >= Fighter.specialGaugeMax }
    /// フィーバーを始められるか（続けてフィーバーにならないよう、間に通常攻撃を挟む）
    var canUseFever: Bool { normalAttacksSinceFever >= BattleEngine.feverMinAttacks }
}
