//
//  AttackType.swift
//  ARApp
//

/// ターンの初めに選ぶ攻撃の種類
enum AttackType {
    /// ふつうの攻撃
    case normal
    /// 判定エリアが狭いかわりにダメージが 2 倍
    case strong

    var damageMultiplier: Double {
        switch self {
        case .normal: 1
        case .strong: 2
        }
    }

    /// 判定エリアの幅にかける倍率
    var zoneWidthMultiplier: Double {
        switch self {
        case .normal: 1
        case .strong: 0.6
        }
    }
}
