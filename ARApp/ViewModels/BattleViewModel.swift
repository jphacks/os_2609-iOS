//
//  BattleViewModel.swift
//  ARApp
//

import Foundation
import Observation

/// 対戦画面の状態と、バトルの進行
/// 「バトルする」を押した人どうしをマッチングし（場所は問わない）、お互いにタップで攻撃し合う
/// 通常攻撃はスタミナを使い、使い切ると休憩になる。攻撃するたびにフィーバーの抽選をし、ときどきチャンスになる
/// 必殺技はゲージが満タンになると自動で撃つ。相手の必殺技は、予告している間にスワイプするとよけられる
/// 自分の行動はすぐに反映して相手に送り、相手の行動は届いた順に反映する（どちらも BattleEngine で計算する）
@Observable
final class BattleViewModel {
    enum Phase {
        /// 対戦相手を待っていない（「バトルする」を押す前）
        case lobby
        /// 対戦相手を待っている
        case searching
        /// 相手探しをやめて、片付けが終わるのを待っている
        case cancellingSearch
        /// 対戦中（決着がついて結果を出している間も含む）
        case fighting
    }

    /// 自分から見た決着
    enum Outcome {
        case won
        case lost
    }

    /// 攻撃が当たった出来事。画面の演出（ダメージ表示、揺れ）のきっかけになる
    struct Hit: Identifiable {
        let id = UUID()
        let damage: Int
        /// 必殺技による攻撃か（演出を派手にする）
        let isSpecial: Bool
        /// よけられた必殺技か（のけぞらず、横にかわす）
        let isDodged: Bool
        /// フィーバー中の通常攻撃か（演出を派手にする）
        let isFever: Bool
        /// この攻撃で HP が 0 になったか（とどめの演出を出す）
        /// この端末で計算した結果なので、勝敗が確定したわけではない（確定した勝敗は outcome）
        let isFinishing: Bool

        init(action: BattleAction, damage: Int, isFinishing: Bool) {
            self.damage = damage
            isSpecial = action.resolvesSpecial
            isDodged = action == .dodgeSpecial
            isFever = action == .feverAttack
            self.isFinishing = isFinishing
        }
    }

    /// 相手の必殺技の予告。相手の必殺技が届いてから、受けたかよけたかを決めるまでの間だけある
    struct Danger: Identifiable {
        let id = UUID()
    }

    /// よけるためにスワイプした出来事。予告の外でスワイプしても、スタミナを使って横に動く（よけたことにはならない）
    struct Dodge: Identifiable {
        let id = UUID()
        /// 右へスワイプしたか。モンスターがかわす向きに使う
        let toRight: Bool
    }

    /// 相手の必殺技の予告中にスワイプしたが、休憩中やスタミナが足りなくてよけられなかった出来事
    struct FailedDodge: Identifiable {
        let id = UUID()
        /// よけられなかった予告の id
        let dangerID: UUID
    }

    /// チャンスの帯が、色を 1 段階上げるまでの時間（秒）
    static let chanceStepDuration = 0.7
    /// 帯の色が止まってから、結果（砕ける・金に光る）を見せる時間（秒）
    static let chanceResultDuration = 0.9

    /// チャンスになってから結果が出るまでの時間（秒）。上の色まで上がるほど長くなる
    /// ChanceComponent はこの時間に合わせて色を上げる
    static func chanceDuration(of chance: FeverLottery.Chance) -> Double {
        chanceStepDuration * Double(chance.finalLevel.rawValue + 1) + chanceResultDuration
    }

    /// 相手の必殺技が届いてから、受けたかよけたかを決めるまでの時間（秒）。この間、画面に「DANGER!」を出し、スワイプするとよけられる
    static let dangerDuration = 1.0

    /// 状態の中で自分と相手を見分ける ID。どちらの端末でも、自分が myID になる
    private static let myID: FighterID = "me"
    private static let opponentID: FighterID = "opponent"

    /// 次の対戦で使う自分のモンスター。保存先の「バトルに出すモンスター」（最初の選択画面や編成で決めたもの）
    private(set) var myMonster: Monster
    /// 対戦中の相手のモンスター。マッチングするまでは nil
    private(set) var opponentMonster: Monster?
    private(set) var phase = Phase.lobby
    /// 対戦中の状態。マッチングするまでは nil
    private(set) var state: BattleState?
    /// 確定した決着。決着がついていない、またはまだ確定していなければ nil
    private(set) var outcome: Outcome?
    /// 対戦できなかったとき（通信の失敗、相手が抜けた）に出すメッセージ
    private(set) var errorMessage: String?
    /// 最後に相手へ当たった攻撃。View はこれが変わるたびに演出を流す
    private(set) var lastHitOnOpponent: Hit?
    /// 最後に自分へ当たった攻撃
    private(set) var lastHitOnMe: Hit?
    /// 予告している相手の必殺技。予告していなければ nil
    private(set) var incomingDanger: Danger?
    /// 最後によけるためにスワイプした出来事
    private(set) var lastDodge: Dodge?
    /// スワイプしてよけた予告の id。予告が終わったときにこれと同じなら、よけたことになる
    private var dodgedDangerID: UUID?
    /// 最後によけられなかった出来事。変わるたびに振動させ、予告の文字を「よけられない」に変える
    private(set) var lastFailedDodge: FailedDodge?
    /// 自分のスタミナ。値は時間とともに変わるので、表示するときは value(at:) で求める
    private(set) var stamina = Stamina()
    /// 休憩が終わる時刻に、終わったことを stamina に記録するタスク
    private var restTask: Task<Void, Never>?
    /// 見せているチャンス。チャンスでなければ nil
    private(set) var chance: FeverLottery.Chance?
    private var chanceTask: Task<Void, Never>?
    /// 自分のフィーバーが終わる時刻。フィーバー中でなければ nil
    /// 時刻で持つので、アプリがバックグラウンドにある間も時間は進む（戻ってきたときに残り時間が増えない）
    private(set) var feverEndsAt: Date?
    /// フィーバーを終わらせるタスク
    private var feverTask: Task<Void, Never>?
    /// この時刻になるまで次の通常攻撃はできない（クールダウン）
    private var nextNormalAttackAt = ContinuousClock.now

    private let service: any BattleService
    private let collection: any MonsterCollection
    private var searchTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var finishTask: Task<Void, Never>?
    /// 対戦をやめたときの片付け。次の相手探しは、これが終わってから始める
    private var leaveTask: Task<Void, Never>?

    /// - Parameters:
    ///   - service: 対戦相手とのやり取り
    ///   - collection: 自分のモンスター（バトルに出すモンスター）を読む保存先
    init(service: any BattleService, collection: any MonsterCollection) {
        self.service = service
        self.collection = collection
        myMonster = Self.loadMyMonster(from: collection)
    }

    var me: Fighter? { state?.fighters[Self.myID] }
    var opponent: Fighter? { state?.fighters[Self.opponentID] }
    /// フィーバー中か。終わる時刻を過ぎていたら、終わらせるタスクがまだ動いていなくてもフィーバーではない
    var isFeverActive: Bool { feverEndsAt.map { Date.now < $0 } ?? false }
    /// へとへとで休憩中か。休憩しているかは stamina だけが持つ（攻撃できるかの判断と画面の表示で食い違わないように）
    var isResting: Bool { stamina.isResting(at: .now) }

    /// 「バトルする」が押されたときに呼ぶ。対戦相手を探し、誰も待っていなければ相手が来るまで待つ
    func findOpponent() {
        guard phase == .lobby else { return }
        phase = .searching
        errorMessage = nil
        searchTask = Task { [leaveTask] in
            // 前の対戦の片付けが終わる前に始めると、片付けが新しい相手探しの状態まで消してしまう
            await leaveTask?.value
            // 片付けを待っている間に「やめる」が押されていたら、相手を探さない
            guard !Task.isCancelled else { return }
            do {
                let opponentMonster = try await service.findOpponent(monster: myMonster)
                guard !Task.isCancelled else { return }
                startBattle(against: opponentMonster)
            } catch {
                // 自分でやめたとき（cancelSearch）はエラーにしない
                // キャンセルされると、CancellationError 以外のエラーが投げられることもある
                guard !Task.isCancelled else { return }
                fail(error)
            }
        }
    }

    /// 「やめる」が押されたとき、またはバトルの画面が隠れたときに呼ぶ。対戦相手を探すのをやめる
    /// 片付けが終わってからロビーに戻る
    /// 終わる前に次の相手探しを始めると、前の片付けが新しい相手探しの状態まで消してしまうため
    /// 相手を探していなければ（対戦中など）何もしない
    func cancelSearch() {
        guard phase == .searching, let searchTask else { return }
        phase = .cancellingSearch
        searchTask.cancel()
        Task {
            await searchTask.value
            // キャンセルと同時にマッチングが終わっていた場合に備えて、対戦からも抜ける
            await service.leave()
            phase = .lobby
            // 片付けの間に画面が表示されると、そのときは読み直せない（ロビーではないため）ので、ここで読み直す
            reloadMyMonster()
        }
    }

    /// 画面がタップされたときに呼ぶ。クールダウン中や休憩中は何も起きない
    /// スタミナを使い切ったら、休憩を始める
    func attack() {
        let now = ContinuousClock.now
        guard now >= nextNormalAttackAt, phase == .fighting, finishTask == nil, !isResting else { return }
        let action: BattleAction = isFeverActive ? .feverAttack : .normalAttack
        guard perform(action) else { return }
        nextNormalAttackAt = now + .seconds(BattleEngine.normalAttackCooldown)
        stamina.spendForAttack(at: .now)
        if isResting {
            startRest()
        }
        // ゲージが満タンになったら、自動で必殺技を撃つ
        if me?.canUseSpecial == true {
            perform(.specialAttack)
        }
        if action == .normalAttack, chance == nil, me?.canUseFever == true, let drawn = FeverLottery.draw() {
            startChance(drawn)
        }
    }

    /// 画面が左右にスワイプされたときに呼ぶ。休憩中やスタミナが足りないときはよけられない
    /// 相手の必殺技を予告している間なら、よけたことになる（よけられなかったら、そのことを知らせる）
    func dodge(toRight: Bool) {
        guard phase == .fighting, finishTask == nil else { return }
        guard stamina.spendForDodge(at: .now) else {
            if let incomingDanger {
                lastFailedDodge = FailedDodge(dangerID: incomingDanger.id)
            }
            return
        }
        lastDodge = Dodge(toRight: toRight)
        if let incomingDanger {
            dodgedDangerID = incomingDanger.id
        }
    }

    /// 結果を見終わったときに呼ぶ。ロビーに戻る
    func leaveBattle() {
        reset()
        reloadMyMonster()
    }

    /// 画面が表示されたときに呼ぶ。編成でバトルに出すモンスターが変わっていたら、それに替える
    /// 相手を探している間や対戦中は替えない（相手に送ったモンスターと食い違うため）
    func reloadMyMonster() {
        guard phase == .lobby else { return }
        myMonster = Self.loadMyMonster(from: collection)
    }

    /// まだ決まっていなければ（最初の選択画面の前、プレビュー）ランダムに選ぶ
    private static func loadMyMonster(from collection: any MonsterCollection) -> Monster {
        collection.battleMonster ?? Monster.all.randomElement()!
    }

    /// チャンスを見せ、結果が出たら消す。当たりならフィーバーを始める
    /// チャンスの間も攻撃はできるが、次の抽選はしない
    private func startChance(_ drawn: FeverLottery.Chance) {
        chance = drawn
        chanceTask = Task {
            do {
                try await Task.sleep(for: .seconds(Self.chanceDuration(of: drawn)))
            } catch {
                return // 対戦が終わった
            }
            chance = nil
            if drawn.willWin {
                startFever()
            }
        }
    }

    /// feverDuration 秒の間、通常攻撃のダメージが 2 倍になる
    private func startFever() {
        guard !isFeverActive, perform(.fever) else { return }
        feverEndsAt = .now + BattleEngine.feverDuration
        feverTask?.cancel()
        feverTask = Task {
            do {
                try await Task.sleep(for: .seconds(BattleEngine.feverDuration))
            } catch {
                return // 対戦が終わった
            }
            feverEndsAt = nil
        }
    }

    /// 対戦や相手探しをやめて、ロビーの状態に戻す
    /// 自分のモンスターはここでは選び直さない（対戦できなかったときは、同じモンスターでやり直す）
    private func reset() {
        searchTask?.cancel()
        receiveTask?.cancel()
        finishTask?.cancel()
        finishTask = nil
        endFever()
        endRest()
        leaveTask = Task { await service.leave() }
        state = nil
        opponentMonster = nil
        outcome = nil
        lastHitOnOpponent = nil
        lastHitOnMe = nil
        incomingDanger = nil
        lastDodge = nil
        dodgedDangerID = nil
        lastFailedDodge = nil
        phase = .lobby
    }

    private func startBattle(against opponentMonster: Monster) {
        self.opponentMonster = opponentMonster
        state = BattleState(
            Fighter(id: Self.myID, name: myMonster.name, maxHP: BattleEngine.maxHP),
            Fighter(id: Self.opponentID, name: opponentMonster.name, maxHP: BattleEngine.maxHP)
        )
        nextNormalAttackAt = .now
        stamina = Stamina()
        phase = .fighting
        receiveOpponentActions()
    }

    /// 決着がつくまで相手の行動を受け取って反映する
    private func receiveOpponentActions() {
        receiveTask = Task {
            do {
                for try await action in service.opponentActions() {
                    guard var state,
                          let damage = BattleEngine.apply(action, by: Self.opponentID, to: &state)
                    else { continue }
                    self.state = state
                    recordHit(of: action, by: Self.opponentID, damage: damage)
                    if state.winner != nil { break }
                    // 相手が必殺技を撃ったら予告し、その間にスワイプしたかどうかで、受けたかよけたかを送り返す
                    // 予告している間に届いた相手の行動は、そのあとに順番に反映する
                    if action == .specialAttack {
                        let danger = Danger()
                        incomingDanger = danger
                        try await Task.sleep(for: .seconds(Self.dangerDuration))
                        incomingDanger = nil
                        perform(dodgedDangerID == danger.id ? .dodgeSpecial : .takeSpecial)
                        if self.state?.winner != nil { break }
                    }
                }
                // 自分の端末で決着がついた、または相手の端末で決着がついて受け取りが終わった
                guard !Task.isCancelled else { return }
                confirmOutcome()
            } catch {
                // 自分でやめたとき（leaveBattle）や、自分の攻撃で決着がついたときはエラーにしない
                guard !Task.isCancelled else { return }
                fail(error)
            }
        }
    }

    /// 自分の行動を反映して相手に伝える。行えたら true
    @discardableResult
    private func perform(_ action: BattleAction) -> Bool {
        guard phase == .fighting, finishTask == nil, var state,
              let damage = BattleEngine.apply(action, by: Self.myID, to: &state)
        else { return false }
        self.state = state
        recordHit(of: action, by: Self.myID, damage: damage)
        service.send(action)
        if state.winner != nil {
            confirmOutcome()
        }
        return true
    }

    /// ダメージを与えた行動なら、受けた側への攻撃として記録する（画面の演出のきっかけになる）
    /// 通常攻撃は行動した人の相手が、必殺技の結果は行動した本人がダメージを受ける
    private func recordHit(of action: BattleAction, by actor: FighterID, damage: Int) {
        let target: FighterID
        if action.hitsOpponent {
            target = actor == Self.myID ? Self.opponentID : Self.myID
        } else if action.resolvesSpecial {
            target = actor
        } else {
            return
        }
        let hit = Hit(action: action, damage: damage, isFinishing: state?.winner != nil)
        if target == Self.myID {
            lastHitOnMe = hit
        } else {
            lastHitOnOpponent = hit
        }
    }

    /// 相手の行動の受け取りをやめて、決着を確定させる
    private func confirmOutcome() {
        guard finishTask == nil else { return }
        receiveTask?.cancel()
        incomingDanger = nil
        endFever()
        endRest()
        let iWon = state?.winner == Self.myID
        finishTask = Task {
            do {
                let confirmed = try await service.finish(iWon: iWon)
                guard !Task.isCancelled else { return }
                outcome = confirmed ? .won : .lost
            } catch {
                guard !Task.isCancelled else { return }
                fail(error)
            }
        }
    }

    private func endFever() {
        chanceTask?.cancel()
        chanceTask = nil
        chance = nil
        feverTask?.cancel()
        feverTask = nil
        feverEndsAt = nil
    }

    /// へとへとになったときに呼ぶ。休憩が終わる時刻まで待って、終わったことを stamina に記録する
    /// 待つ時間は stamina の休憩が終わる時刻から求める（別に数えると、少しずれて食い違う）
    private func startRest() {
        guard let restEndsAt = stamina.restEndsAt else { return }
        restTask?.cancel()
        restTask = Task {
            do {
                try await Task.sleep(for: .seconds(restEndsAt.timeIntervalSinceNow))
            } catch {
                return // 対戦が終わった
            }
            stamina.finishRest()
        }
    }

    private func endRest() {
        restTask?.cancel()
        restTask = nil
        stamina.finishRest()
    }

    /// 相手がいなくなった・通信に失敗したときは、対戦をやめてロビーに戻る
    private func fail(_ error: Error) {
        // 【開発用】原因を調べるためのログ。リリースするときに消してよい
        print("対戦の通信に失敗しました: \(error)")
        reset()
        errorMessage = "対戦できませんでした。もう一度お試しください"
    }
}
