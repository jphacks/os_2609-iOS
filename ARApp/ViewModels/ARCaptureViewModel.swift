//
//  ARCaptureViewModel.swift
//  ARApp
//

import Observation

/// AR 捕獲画面の状態。ARView には触らず、状態だけを持つ
@Observable
final class ARCaptureViewModel {
    /// 出現させるモンスター（Step 2 では固定の 1 体）
    let monster = Monster(name: "スライム", size: 0.2)

    /// モンスターが床に配置されたか（ARViewContainer の Coordinator が更新する）
    var isMonsterPlaced = false

    var statusMessage: String {
        isMonsterPlaced
            ? "\(monster.name)が現れた！"
            : "床を映して、ゆっくり動かしてください"
    }
}
