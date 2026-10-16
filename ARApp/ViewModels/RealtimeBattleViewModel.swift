//
//  RealtimeBattleViewModel.swift
//  ARApp
//

import Foundation
import Observation

/// リアルタイムバトル画面の状態と、バトルの進行
@Observable
final class RealtimeBattleViewModel {
    /// 画面の演出（ダメージ表示、揺れ）のきっかけになる出来事
    struct Event: Identifiable {
        enum Kind {
            case playerAttack(damage: Int)
        }

        let id = UUID()
        let kind: Kind
    }

    private(set) var state = RealtimeBattleState(playerName: "ナイト", enemyName: "ドラゴン")
    /// 最後に起きた出来事。View はこれが変わるたびに演出を流す
    private(set) var lastEvent: Event?

    /// 画面がタップされたときに呼ぶ。クールダウン中は何も起きない
    func attack() {
        guard let damage = RealtimeBattleEngine.normalAttack(&state, at: .now) else { return }
        lastEvent = Event(kind: .playerAttack(damage: damage))
    }
}
