//
//  RealtimeBattleViewModel.swift
//  ARApp
//

import Foundation
import Observation

/// リアルタイムバトル画面の状態と、バトルの進行
@Observable
final class RealtimeBattleViewModel {
    /// 攻撃が当たった出来事。画面の演出（ダメージ表示、揺れ）のきっかけになる
    struct Hit: Identifiable {
        let id = UUID()
        let damage: Int
    }

    private(set) var state = RealtimeBattleState(playerName: "ナイト", enemyName: "ドラゴン")
    /// 最後に敵へ当たった攻撃。View はこれが変わるたびに演出を流す
    private(set) var lastHitOnEnemy: Hit?
    /// 最後に自分へ当たった攻撃
    private(set) var lastHitOnPlayer: Hit?

    /// 画面がタップされたときに呼ぶ。クールダウン中は何も起きない
    func attack() {
        guard let damage = RealtimeBattleEngine.normalAttack(&state, at: .now) else { return }
        lastHitOnEnemy = Hit(damage: damage)
    }

    /// 決着がつくまで、一定間隔で敵に攻撃させる
    /// View の .task から呼ぶ。画面が消えると Task ごとキャンセルされるので、再表示しても重複して動かない
    func runEnemyAttacks() async {
        while state.outcome == nil {
            do {
                try await Task.sleep(for: .seconds(RealtimeBattleEngine.enemyAttackInterval))
            } catch {
                return // キャンセルされた
            }
            guard let damage = RealtimeBattleEngine.enemyAttack(&state) else { return }
            lastHitOnPlayer = Hit(damage: damage)
        }
    }
}
