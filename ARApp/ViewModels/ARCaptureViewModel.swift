//
//  ARCaptureViewModel.swift
//  ARApp
//

import Observation

/// AR 捕獲画面の状態。ARView には触らず、状態だけを持つ
@Observable
final class ARCaptureViewModel {
    /// 出現させるモンスター（今は固定の 1 体）
    let monster = Monster(name: "スライム", size: 0.2)

    /// モンスターが床に配置されたか。変更は下のメソッド経由でのみ行う
    private(set) var isMonsterPlaced = false

    var statusMessage: String {
        isMonsterPlaced
            ? "\(monster.name)が現れた！"
            : "床を映して、ゆっくり動かしてください"
    }

    /// モンスターのアンカーが床に固定された（または外れた）ときに ARSceneController から呼ばれる
    func monsterAnchorStateChanged(isAnchored: Bool) {
        isMonsterPlaced = isAnchored
    }
}
