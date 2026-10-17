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
    /// 「捕まえた！」を表示しておく時間
    static let capturedMessageDuration: Duration = .seconds(2)

    /// モンスターを置く床が見つかったか
    private(set) var isFloorFound = false
    /// 今出現しているモンスター。ARSceneController はこの一覧に合わせて 3D のモンスターを置いたり消したりする
    private(set) var wildMonsters: [WildMonster] = []
    /// 直前に捕まえたモンスターの名前。表示し終わったら nil に戻る
    private(set) var capturedName: String?

    private var respawnTasks: [Task<Void, Never>] = []
    private var messageTask: Task<Void, Never>?

    var statusMessage: String {
        if let capturedName {
            "\(capturedName)を捕まえた！"
        } else if isFloorFound {
            "モンスターをタップして捕まえよう"
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
            messageTask?.cancel()
            messageTask = nil
            wildMonsters.removeAll()
            capturedName = nil
        }
    }

    /// モンスターがタップされたときに ARSceneController から呼ばれる
    func capture(id: WildMonster.ID) {
        guard let index = wildMonsters.firstIndex(where: { $0.id == id }) else { return }
        let captured = wildMonsters.remove(at: index)
        showCapturedMessage(name: captured.monster.name)

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

    private func showCapturedMessage(name: String) {
        // 続けて捕まえたときは、前の表示を消すタイマーを止めて新しい名前に変える
        messageTask?.cancel()
        capturedName = name
        messageTask = Task { [weak self] in
            try? await Task.sleep(for: Self.capturedMessageDuration)
            guard let self, !Task.isCancelled else { return }
            self.capturedName = nil
        }
    }
}
