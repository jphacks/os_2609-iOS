//
//  ARCaptureViewModel.swift
//  ARApp
//

import Foundation
import Observation

/// AR 捕獲画面の状態。ARView には触らず、状態だけを持つ
/// 歩いた距離に応じてモンスターを出し、3D での配置や動きは ARSceneController が担当する
/// モンスターをタップするとバトル（相手は CPU）になり、勝てば捕獲成功として保存する
/// モンスターはこの端末の中だけに出る（ほかのプレイヤーとは共有しない）
@Observable
final class ARCaptureViewModel {
    /// バトルの結果として出す、捕獲の結果
    enum CaptureOutcome {
        case success(Monster)
        case failure(Monster)
    }

    /// 「現れた！」などのお知らせを表示しておく時間
    static let noticeDuration: Duration = .seconds(2)
    /// 捕獲の結果を出しておく時間。過ぎたら次へ進む
    static let outcomeDisplayDuration: Duration = .seconds(2)
    /// 捕まえられる距離（m）。床の上での、自分とモンスターの距離がこれより遠いと捕まえられない
    static let captureDistance: Float = 1.0
    /// モンスターが出るまでに歩く距離（m）。出るたびにこの範囲から選び直す
    static let spawnWalkDistanceRange: ClosedRange<Float> = 5...10
    /// 出現してから逃げるまでの時間。床が見えていない間（別のタブにいる間も）は数えず、見つかり直したら数え直す
    static let escapeDuration: Duration = .seconds(60)

    /// モンスターを置く床が見つかったか
    private(set) var isFloorFound = false
    /// 「現れた！」などのお知らせ。表示し終わったら nil に戻る
    private(set) var notice: String?
    /// 画面に出している捕獲の結果。出していなければ nil
    private(set) var captureOutcome: CaptureOutcome?
    /// 詳細画面に出している、捕獲したモンスター。詳細画面を開いていなければ nil
    private(set) var detailMonster: Monster?
    /// 出現しているモンスター。一度に出るのは 1 体まで
    private(set) var wildMonster: WildMonster?
    /// バトルしている野生のモンスター。バトル中でなければ nil
    private(set) var battleMonster: WildMonster?
    /// 次のモンスターが出るまでに、あと何 m 歩くか
    /// 歩くたびに変わるが、画面には出さないので View の更新のきっかけにしない
    @ObservationIgnored private var remainingWalkDistance = Float.random(in: spawnWalkDistanceRange)
    private var noticeTask: Task<Void, Never>?
    private var escapeTask: Task<Void, Never>?
    /// 捕獲の結果を出してから次へ進むまで待つタスク
    private var outcomeTask: Task<Void, Never>?

    private let collection: any MonsterCollection

    init(collection: any MonsterCollection) {
        self.collection = collection
    }

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

    /// 床のアンカーを置いた（または外れた）ときに ARSceneController から呼ばれる
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
    /// 決まった距離を歩くと、モンスターが出る。出ている間と、バトル・捕獲の結果・詳細画面を出している間は数えない
    func walked(distance: Float) {
        guard isFloorFound, wildMonster == nil, battleMonster == nil, captureOutcome == nil, detailMonster == nil else { return }
        remainingWalkDistance -= distance
        guard remainingWalkDistance <= 0 else { return }

        remainingWalkDistance = .random(in: Self.spawnWalkDistanceRange)
        // `Monster.all` は空ではない
        let wild = WildMonster(monster: Monster.all.randomElement()!)
        wildMonster = wild
        showNotice("\(wild.monster.name)が現れた！")
        startEscapeTimer()
    }

    /// モンスターがタップされたときに ARSceneController から呼ばれる。近ければバトルを始める
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
        battleMonster = target
    }

    /// バトルが終わったときに呼ぶ。勝ったら捕獲成功、負けたら捕獲失敗を出す
    /// 勝ったときは、結果を少し出してから詳細画面を開く
    /// - Parameter won: 自分が勝ったか
    func finishBattle(won: Bool) {
        guard let opponent = battleMonster?.monster else { return }
        battleMonster = nil
        captureOutcome = won ? .success(opponent) : .failure(opponent)
        if won {
            collection.add(opponent)
        }

        outcomeTask?.cancel()
        outcomeTask = Task {
            try? await Task.sleep(for: Self.outcomeDisplayDuration)
            guard !Task.isCancelled else { return }
            captureOutcome = nil
            if won {
                detailMonster = opponent
            }
        }
    }

    /// バトルの前に「にげる」が押されたときに呼ぶ。モンスターは逃げたことにして、AR に戻る
    func fleeBattle() {
        guard let wild = battleMonster else { return }
        battleMonster = nil
        showNotice("\(wild.monster.name)は逃げてしまった…")
    }

    /// 詳細画面を閉じて AR に戻る。また歩くと次のモンスターが出る
    func closeDetail() {
        detailMonster = nil
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
