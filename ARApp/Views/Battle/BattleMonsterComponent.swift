//
//  BattleMonsterComponent.swift
//  ARApp
//

import SwiftUI

/// BLE マッチング後の待機画面に出すモンスター。
/// SceneKit で静止表示し、AR セッションは作らない。
struct BattleMonsterComponent: View {
    let monster: Monster
    /// Y 軸まわりの向き（ラジアン）
    let facing: Float

    var body: some View {
        MonsterModelComponent(monster: monster, height: 2.4, facing: .radians(Double(facing)))
    }
}
