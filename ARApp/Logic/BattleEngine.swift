//
//  BattleEngine.swift
//  ARApp
//

/// バトルのルール（攻撃・ダメージ・勝敗）。状態を受け取って書き換えるだけで、タイマーや画面、通信は持たない
/// 自分の行動も相手の行動も同じ apply を通すので、どちらの端末で計算しても同じ結果になる
/// それぞれの人の HP を減らすのは、どちらか一方の人の行動だけ（通常攻撃は攻撃した人、必殺技は撃たれた人の結果）なので、
/// 2 人の行動が届く順番が端末ごとに違っても、HP は食い違わない
enum BattleEngine {
    /// 2 人とも同じ HP で始める
    static let maxHP = 200
    static let normalAttackDamage = 10
    /// 通常攻撃のクールダウン（秒）。連打の制限は入力した端末で行うので、状態には持たない（スタミナも同じ）
    static let normalAttackCooldown: Double = 0.3
    /// 通常攻撃が当たるたびに溜まる必殺技ゲージ
    static let specialGaugeGain = 10
    static let specialAttackDamage = 60
    /// 必殺技をよけたときのダメージ（ポケモン GO と同じく 4 分の 1）
    static let dodgedSpecialDamage = 15
    /// フィーバーが終わってから、次のフィーバーの抽選を始めるまでに必要な通常攻撃の回数
    /// ⚠️ 変えるときは supabase/schema.sql の check_battle_action も合わせる
    static let feverMinAttacks = 5
    /// フィーバーが続く時間（秒）。時間は行動した端末で数える（BattleViewModel）
    /// ⚠️ 変えるときは supabase/schema.sql の check_battle_action も合わせる
    static let feverDuration: Double = 5
    /// フィーバー中の通常攻撃のダメージの倍率
    static let feverDamageMultiplier = 2

    /// actor が action を行う。行えたらダメージを返す（ダメージを受けたのが誰かは action で決まる。BattleAction の hitsOpponent / resolvesSpecial）
    /// ダメージのない行動（必殺技を撃つ、フィーバーを始める）は 0 を返す
    /// 決着後やゲージ不足などで行えなければ nil を返す
    static func apply(_ action: BattleAction, by actor: FighterID, to state: inout BattleState) -> Int? {
        guard state.winner == nil,
              var me = state.fighters[actor],
              let opponentID = state.opponentID(of: actor),
              var opponent = state.fighters[opponentID]
        else { return nil }

        let damage: Int
        switch action {
        case .normalAttack:
            damage = min(normalAttackDamage, opponent.hp)
            opponent.hp -= damage
            me.specialGauge = min(me.specialGauge + specialGaugeGain, Fighter.specialGaugeMax)
            me.normalAttacksSinceFever += 1
        case .feverAttack:
            // フィーバー中の攻撃は、次のフィーバーまでの回数に数えない（続けてフィーバーにならないようにする）
            damage = min(normalAttackDamage * feverDamageMultiplier, opponent.hp)
            opponent.hp -= damage
            me.specialGauge = min(me.specialGauge + specialGaugeGain, Fighter.specialGaugeMax)
        case .specialAttack:
            guard me.canUseSpecial else { return nil }
            damage = 0
            me.specialGauge = 0
            opponent.incomingSpecials += 1
        case .fever:
            guard me.canUseFever else { return nil }
            damage = 0
            me.normalAttacksSinceFever = 0
        case .takeSpecial, .dodgeSpecial:
            guard me.incomingSpecials > 0 else { return nil }
            damage = min(action == .takeSpecial ? specialAttackDamage : dodgedSpecialDamage, me.hp)
            me.hp -= damage
            me.incomingSpecials -= 1
        }

        state.fighters[actor] = me
        state.fighters[opponentID] = opponent
        if opponent.hp == 0 {
            state.winner = actor
        } else if me.hp == 0 {
            state.winner = opponentID
        }
        return damage
    }
}
