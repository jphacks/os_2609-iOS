//
//  BattleAction.swift
//  ARApp
//

/// バトル中に取れる行動。オンライン対戦では、この rawValue を相手に送る（battle_actions テーブルの action 列）
/// フィーバーの時間（5 秒）は行動した端末で数えるので、フィーバー中の通常攻撃は別の行動（feverAttack）として送る
/// 受け取った側は時間を数えずに、届いた行動のとおりにダメージを計算する。正しく送られているかはサーバーが確かめる（supabase/schema.sql）
enum BattleAction: String {
    case normalAttack
    /// 必殺技を撃つ（ダメージはまだ与えない）
    /// よけたかどうかは撃たれた側の端末にしかわからないので、撃たれた側が結果（takeSpecial / dodgeSpecial）を送り返し、そこでダメージが決まる
    case specialAttack
    /// フィーバーを始める（ダメージは与えない）
    case fever
    /// フィーバー中の通常攻撃（ダメージ 2 倍）
    case feverAttack
    /// 相手の必殺技をよけられずに受けた（行動した本人がダメージを受ける）
    case takeSpecial
    /// 相手の必殺技をよけた（行動した本人が、少しだけダメージを受ける）
    case dodgeSpecial

    /// 相手にダメージを与える行動か
    var hitsOpponent: Bool { self == .normalAttack || self == .feverAttack }
    /// 相手の必殺技の結果か（行動した本人がダメージを受ける）
    var resolvesSpecial: Bool { self == .takeSpecial || self == .dodgeSpecial }
}
