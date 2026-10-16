//
//  TimingJudgement.swift
//  ARApp
//

/// STOP を押したときの判定
enum TimingJudgement {
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
