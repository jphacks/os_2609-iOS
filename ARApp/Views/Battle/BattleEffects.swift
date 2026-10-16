//
//  BattleEffects.swift
//  ARApp
//

import SwiftUI

/// バトル画面の演出（判定の色、振動、揺れ）

extension TimingJudgement {
    var color: Color {
        switch self {
        case .perfect: .orange
        case .good: .green
        case .miss: .gray
        }
    }
}

extension BattleViewModel.Event.Kind {
    /// 出来事ごとの振動
    var feedback: SensoryFeedback? {
        switch self {
        case .hit(.perfect, _, _): .impact(weight: .heavy, intensity: 1)
        case .hit(.good, _, _): .impact(weight: .light)
        case .hit(.miss, _, _): .error
        case .counterattack(let damage): damage > 0 ? .impact(flexibility: .rigid, intensity: 1) : .success
        case .capture(let succeeded): succeeded ? .success : .error
        }
    }
}

extension View {
    /// trigger が変わるたびに左右に揺れる
    func shake(trigger: Int) -> some View {
        keyframeAnimator(initialValue: 0.0, trigger: trigger) { content, offset in
            content.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(12, duration: 0.05)
                CubicKeyframe(-10, duration: 0.07)
                CubicKeyframe(6, duration: 0.07)
                CubicKeyframe(-3, duration: 0.06)
                CubicKeyframe(0, duration: 0.05)
            }
        }
    }
}
