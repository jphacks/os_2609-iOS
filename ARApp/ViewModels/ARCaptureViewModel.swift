//
//  ARCaptureViewModel.swift
//  ARApp
//

import Foundation
import Observation

/// AR 捕獲画面の状態。ARView には触らず、状態だけを持つ
/// どのモンスターを AR に出すかはここで決め、3D での配置や動きは ARSceneController が担当する
@Observable
final class ARCaptureViewModel {
    /// 「捕まえた！」などのお知らせを表示しておく時間
    static let noticeDuration: Duration = .seconds(2)
    /// 捕まえられる距離（m）。床の上での、自分とモンスターの距離がこれより遠いと捕まえられない
    static let captureDistance: Float = 1.0

    /// モンスターを置く床が見つかったか
    private(set) var isFloorFound = false
    /// 「捕まえた！」などのお知らせ。表示し終わったら nil に戻る
    private(set) var notice: String?
    /// もう AR に置いたモンスター
    /// 現在地の推定がぶれて別の地点になっても、捕まえるか逃げるまでは出しておくために覚えておく
    private var placedIDs: Set<WildMonster.ID> = []

    private let wildMonsterViewModel: WildMonsterViewModel
    private let locationViewModel: LocationViewModel
    private var noticeTask: Task<Void, Never>?

    init(wildMonsterViewModel: WildMonsterViewModel, locationViewModel: LocationViewModel) {
        self.wildMonsterViewModel = wildMonsterViewModel
        self.locationViewModel = locationViewModel
    }

    /// AR に出すモンスター。今いる地点にいるモンスターと、もう置いたモンスター
    /// ARSceneController はこの一覧に合わせて 3D のモンスターを置いたり消したりする
    var shownMonsters: [WildMonster] {
        guard isFloorFound else { return [] }
        let locationID = locationViewModel.currentLocation?.id
        return wildMonsterViewModel.wildMonsters.filter {
            $0.locationID == locationID || placedIDs.contains($0.id)
        }
    }

    var statusMessage: String {
        if let notice {
            notice
        } else if !isFloorFound {
            "床を映して、ゆっくり動かしてください"
        } else if shownMonsters.isEmpty {
            "この辺りにはモンスターがいないようだ"
        } else {
            "モンスターに近づいて、タップで捕まえよう"
        }
    }

    /// 床のアンカーが固定された（または外れた）ときに ARSceneController から呼ばれる
    func floorStateChanged(isFound: Bool) {
        isFloorFound = isFound
        if !isFound {
            // 床がなくなると置いたモンスターも消えるので、次に床が見つかったときに出し直す
            placedIDs.removeAll()
            noticeTask?.cancel()
            noticeTask = nil
            notice = nil
        }
    }

    /// モンスターを床に置き終わったときに ARSceneController から呼ばれる
    func monsterPlaced(id: WildMonster.ID) {
        placedIDs.insert(id)
    }

    /// モンスターがタップされたときに ARSceneController から呼ばれる
    /// distance は床の上での、自分とモンスターの距離（m）
    func monsterTapped(id: WildMonster.ID, distance: Float) {
        guard let captured = shownMonsters.first(where: { $0.id == id }) else { return }
        guard distance <= Self.captureDistance else {
            showNotice("遠すぎる！もっと近づこう")
            return
        }
        wildMonsterViewModel.capture(id: id)
        placedIDs.remove(id)
        showNotice("\(captured.monster.name)を捕まえた！")
    }

    private func showNotice(_ message: String) {
        // 続けて表示するときは、前の表示を消すタイマーを止めて新しいお知らせに変える
        noticeTask?.cancel()
        notice = message
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: Self.noticeDuration)
            guard let self, !Task.isCancelled else { return }
            self.notice = nil
        }
    }
}
