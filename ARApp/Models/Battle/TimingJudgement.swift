//
//  TimingJudgement.swift
//  ARApp
//

/// STOP を押したときの判定
/// rawValue は通信で相手に送るときの文字列
enum TimingJudgement: String {
    case perfect
    case good
    case miss

    /// 倍率をかける前のダメージ
    var baseDamage: Int {
        switch self {
        case .perfect: 100
        case .good: 50
        case .miss: 0
        }
    }
}
