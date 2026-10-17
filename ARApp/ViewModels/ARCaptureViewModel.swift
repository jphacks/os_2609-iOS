//
//  ARCaptureViewModel.swift
//  ARApp
//

import Foundation
import Observation

/// AR 捕獲画面の状態。ARView には触らず、状態だけを持つ
/// どのモンスターが出ているかはここで決め、3D での配置や動きは ARSceneController が担当する
@Observable
final class ARCaptureViewModel {
    /// 同時に出現しているモンスターの最大数
    static let maxCount = 3

    /// モンスターを置く床が見つかったか
    private(set) var isFloorFound = false
    /// 今出現しているモンスター。ARSceneController はこの一覧に合わせて 3D のモンスターを置く
    private(set) var wildMonsters: [WildMonster] = []

    var statusMessage: String {
        if isFloorFound {
            "モンスターが現れた！"
        } else {
            "床を映して、ゆっくり動かしてください"
        }
    }

    /// 床のアンカーが固定された（または外れた）ときに ARSceneController から呼ばれる
    func floorStateChanged(isFound: Bool) {
        isFloorFound = isFound
        if isFound {
            while wildMonsters.count < Self.maxCount {
                spawn()
            }
        } else {
            // 床がなくなったら全部片付けて、次に床が見つかったときに出し直す
            wildMonsters.removeAll()
        }
    }

    private func spawn() {
        // `Monster.all` は空ではない
        wildMonsters.append(WildMonster(monster: Monster.all.randomElement()!))
    }
}
