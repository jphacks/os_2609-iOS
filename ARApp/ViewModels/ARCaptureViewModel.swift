//
//  ARCaptureViewModel.swift
//  ARApp
//

import Observation

/// AR 捕獲画面の状態。ARView には触らず、状態だけを持つ
@Observable
final class ARCaptureViewModel {
    /// バトルの結果として出す、捕獲の結果
    enum CaptureOutcome {
        case success(Monster)
        case failure(Monster)
    }

    /// 捕獲の結果を出しておく時間。過ぎたら次へ進む
    private static let outcomeDisplayDuration = Duration.seconds(2)

    /// AR に出しているモンスター。タップして消したら nil
    /// ARSceneController はこれが変わるたびに、AR のモンスターを消したり置き直したりする
    private(set) var encounter: Encounter? = .random()

    /// モンスターが床に配置されたか。変更は下のメソッド経由でのみ行う
    private(set) var isMonsterPlaced = false

    /// 画面に出している捕獲の結果。出していなければ nil
    private(set) var captureOutcome: CaptureOutcome?

    /// 詳細画面に出している、捕獲したモンスター。詳細画面を開いていなければ nil
    private(set) var detailMonster: Monster?

    /// 捕獲の結果を出してから次へ進むまで待つタスク
    private var outcomeTask: Task<Void, Never>?

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
        guard let tapped = encounter else { return }
        encounter = nil
        // 【仮】バトル画面ができるまでは、タップしたら勝ったことにする
        // バトル画面ができたら、ここでバトルを始め、終わったときにバトル側から finishBattle を呼んでもらう
        finishBattle(won: true, opponentModelName: tapped.monster.modelName)
    }

    /// バトルが終わったときに呼ぶ。勝ったら捕獲成功、負けたら捕獲失敗を出し、少し待ってから次へ進む
    /// - Parameters:
    ///   - won: 自分が勝ったか
    ///   - opponentModelName: 戦った相手のモンスターの `modelName`
    func finishBattle(won: Bool, opponentModelName: String) {
        // 一覧にないモンスターは結果を出せないので、次のモンスターを出すだけにする
        guard let opponent = Monster.named(opponentModelName) else {
            encounter = .random()
            return
        }
        captureOutcome = won ? .success(opponent) : .failure(opponent)

        outcomeTask?.cancel()
        outcomeTask = Task {
            try? await Task.sleep(for: Self.outcomeDisplayDuration)
            guard !Task.isCancelled else { return }
            captureOutcome = nil
            if won {
                // 次のモンスターは、詳細画面を閉じたときに出す
                detailMonster = opponent
            } else {
                encounter = .random()
            }
        }
    }

    /// 詳細画面を閉じて AR に戻り、次のモンスターを出す
    func closeDetail() {
        guard detailMonster != nil else { return }
        detailMonster = nil
        encounter = .random()
    }
}

/// 詳細画面を fullScreenCover(item:) で開くために必要。モンスターは modelName で見分ける
extension Monster: Identifiable {
    var id: String { modelName }
}
