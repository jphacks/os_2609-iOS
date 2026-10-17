//
//  BattleAction.swift
//  ARApp
//

/// バトル中に取れる行動。オンライン対戦では、この rawValue を相手に送る（battle_actions テーブルの action 列）
/// フィーバーの時間（5 秒）は行動した端末で数えるので、フィーバー中の通常攻撃は別の行動（feverAttack）として送る
/// 受け取った側は時間を数えずに、届いた行動のとおりにダメージを計算する。正しく送られているかはサーバーが確かめる（supabase/schema.sql）
enum BattleAction: String {
    case normalAttack
    case specialAttack
    /// フィーバーを始める（ダメージは与えない）
    case fever
    /// フィーバー中の通常攻撃（ダメージ 2 倍）
    case feverAttack

    /// 相手にダメージを与える行動か
    var isAttack: Bool { self != .fever }
}
