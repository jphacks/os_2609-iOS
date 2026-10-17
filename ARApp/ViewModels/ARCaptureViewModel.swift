//
//  ARCaptureViewModel.swift
//  ARApp
//

import Foundation
import Observation

/// AR 捕獲画面の状態。ARView には触らず、状態だけを持つ
/// 歩いた距離に応じてモンスターを出し、3D での配置や動きは ARSceneController が担当する
/// モンスターはこの端末の中だけに出る（ほかのプレイヤーとは共有しない）
@Observable
final class ARCaptureViewModel {
    /// 「捕まえた！」などのお知らせを表示しておく時間
    static let noticeDuration: Duration = .seconds(2)
    /// 捕まえられる距離（m）。床の上での、自分とモンスターの距離がこれより遠いと捕まえられない
    static let captureDistance: Float = 1.0
    /// モンスターが出るまでに歩く距離（m）。出るたびにこの範囲から選び直す
    static let spawnWalkDistanceRange: ClosedRange<Float> = 5...10
    /// 出現してから逃げるまでの時間。床が見えていない間（別のタブにいる間も）は数えず、見つかり直したら数え直す
    static let escapeDuration: Duration = .seconds(60)

    /// モンスターを置く床が見つかったか
    private(set) var isFloorFound = false
    /// 「捕まえた！」などのお知らせ。表示し終わったら nil に戻る
    private(set) var notice: String?
    /// 出現しているモンスター。一度に出るのは 1 体まで
    private(set) var wildMonster: WildMonster?
    /// 次のモンスターが出るまでに、あと何 m 歩くか
    /// 歩くたびに変わるが、画面には出さないので View の更新のきっかけにしない
    @ObservationIgnored private var remainingWalkDistance = Float.random(in: spawnWalkDistanceRange)
    private var noticeTask: Task<Void, Never>?
    private var escapeTask: Task<Void, Never>?

    /// AR に出すモンスター。ARSceneController はこの一覧に合わせて 3D のモンスターを置いたり消したりする
    /// 床が見つかっていない間は出さない（床が見つかり直したら、その近くに出し直す）
    var shownMonsters: [WildMonster] {
        guard isFloorFound, let wildMonster else { return [] }
        return [wildMonster]
    }

    var statusMessage: String {
        if let notice {
            notice
        } else if !isFloorFound {
            "床を映して、ゆっくり動かしてください"
        } else if wildMonster == nil {
            "歩き回ってモンスターを探そう"
        } else {
            "モンスターに近づいて、タップで捕まえよう"
        }
    }

    /// 床のアンカーが固定された（または外れた）ときに ARSceneController から呼ばれる
    func floorStateChanged(isFound: Bool) {
        isFloorFound = isFound
        if isFound {
            if wildMonster != nil {
                startEscapeTimer()
            }
        } else {
            noticeTask?.cancel()
            noticeTask = nil
            notice = nil
            // 見えていないうちに逃げると、戻ってきたときに知らせが出ず、いなくなった理由がわからない
            escapeTask?.cancel()
            escapeTask = nil
        }
    }

    /// 自分が床の上を歩いたときに ARSceneController から呼ばれる。distance は歩いた距離（m）
    /// 決まった距離を歩くと、モンスターが出る。出ている間は数えない
    func walked(distance: Float) {
        guard isFloorFound, wildMonster == nil else { return }
        remainingWalkDistance -= distance
        guard remainingWalkDistance <= 0 else { return }

        remainingWalkDistance = .random(in: Self.spawnWalkDistanceRange)
        // `Monster.all` は空ではない
        let wild = WildMonster(monster: Monster.all.randomElement()!)
        wildMonster = wild
        showNotice("\(wild.monster.name)が現れた！")
        startEscapeTimer()
    }

    /// モンスターがタップされたときに ARSceneController から呼ばれる
    /// distance は床の上での、自分とモンスターの距離（m）
    func monsterTapped(id: WildMonster.ID, distance: Float) {
        guard let target = wildMonster, target.id == id else { return }
        guard distance <= Self.captureDistance else {
            showNotice("遠すぎる！もっと近づこう")
            return
        }
        escapeTask?.cancel()
        escapeTask = nil
        wildMonster = nil
        showNotice("\(target.monster.name)を捕まえた！")
    }

    /// 出現しているモンスターが、escapeDuration たつと逃げるようにする
    private func startEscapeTimer() {
        guard let wild = wildMonster else { return }
        escapeTask?.cancel()
        escapeTask = Task { [weak self] in
            try? await Task.sleep(for: Self.escapeDuration)
            guard let self, !Task.isCancelled, self.wildMonster?.id == wild.id else { return }
            self.wildMonster = nil
            self.escapeTask = nil
            self.showNotice("\(wild.monster.name)は逃げてしまった…")
        }
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
