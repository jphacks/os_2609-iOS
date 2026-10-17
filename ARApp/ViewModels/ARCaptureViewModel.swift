//
//  ARCaptureViewModel.swift
//  ARApp
//

import Observation

/// AR 捕獲画面の状態。ARView には触らず、状態だけを持つ
@Observable
final class ARCaptureViewModel {
    /// AR に出しているモンスター。タップして消したら nil
    /// ARSceneController はこれが変わるたびに、AR のモンスターを消したり置き直したりする
    private(set) var encounter: Encounter? = .random()

    /// モンスターが床に配置されたか。変更は下のメソッド経由でのみ行う
    private(set) var isMonsterPlaced = false

    /// 画面の上に出す案内。モンスターを出していないときは nil
    var statusMessage: String? {
        guard let encounter else { return nil }
        return isMonsterPlaced
            ? "\(encounter.monster.name)が現れた！"
            : "床を映して、ゆっくり動かしてください"
    }

    /// モンスターのアンカーが床に固定された（または外れた）ときに ARSceneController から呼ばれる
    func monsterAnchorStateChanged(isAnchored: Bool) {
        isMonsterPlaced = isAnchored
    }

    /// AR のモンスターがタップされたときに ARSceneController から呼ばれる
    /// タップした時点でモンスターは AR から消す
    func monsterTapped() {
        guard encounter != nil else { return }
        encounter = nil
    }
}
