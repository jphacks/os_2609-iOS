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
    /// 捕まえてから次の 1 体が出るまでの時間
    static let respawnDelay: Duration = .seconds(5)
    /// 「捕まえた！」などのお知らせを表示しておく時間
    static let noticeDuration: Duration = .seconds(2)
    /// 捕まえられる距離（m）。床の上での、自分とモンスターの距離がこれより遠いと捕まえられない
    static let captureDistance: Float = 1.0

    /// モンスターを置く床が見つかったか
    private(set) var isFloorFound = false
    /// 今出現しているモンスター。ARSceneController はこの一覧に合わせて 3D のモンスターを置いたり消したりする
    private(set) var wildMonsters: [WildMonster] = []
    /// 「捕まえた！」などのお知らせ。表示し終わったら nil に戻る
    private(set) var notice: String?

    private var respawnTasks: [Task<Void, Never>] = []
    private var noticeTask: Task<Void, Never>?

    var statusMessage: String {
        if let notice {
            notice
        } else if isFloorFound {
            "モンスターに近づいて、タップで捕まえよう"
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
            respawnTasks.forEach { $0.cancel() }
            respawnTasks.removeAll()
            noticeTask?.cancel()
            noticeTask = nil
            wildMonsters.removeAll()
            notice = nil
        }
    }

    /// モンスターがタップされたときに ARSceneController から呼ばれる
    /// distance は床の上での、自分とモンスターの距離（m）
    func monsterTapped(id: WildMonster.ID, distance: Float) {
        guard let index = wildMonsters.firstIndex(where: { $0.id == id }) else { return }
        guard distance <= Self.captureDistance else {
            showNotice("遠すぎる！もっと近づこう")
            return
        }
        let captured = wildMonsters.remove(at: index)
        showNotice("\(captured.monster.name)を捕まえた！")

        respawnTasks.append(Task { [weak self] in
            try? await Task.sleep(for: Self.respawnDelay)
            guard let self, !Task.isCancelled, self.isFloorFound,
                  self.wildMonsters.count < Self.maxCount else { return }
            self.spawn()
        })
    }

    private func spawn() {
        // `Monster.all` は空ではない
        wildMonsters.append(WildMonster(monster: Monster.all.randomElement()!))
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
