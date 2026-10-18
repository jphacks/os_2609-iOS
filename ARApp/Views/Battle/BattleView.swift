//
//  BattleView.swift
//  ARApp
//

import SwiftUI

/// 対戦画面。「バトルする」で対戦相手を探し、見つかったら対戦が始まる
/// 画面の空いている所をタップして攻撃し、左右にスワイプしてよける（必殺技とフィーバーは自動）
/// 対戦中は、カメラに映る床の上でモンスター同士が戦う（AR）
/// 対戦前は BattleLobbyComponent、対戦中は BattleFightComponent を出す（どちらも同じフォルダにある）
/// マルチバトルのタブではほかのプレイヤーと、捕獲画面では野生のモンスター（CPU）と戦う
struct BattleView: View {
    /// 野生のモンスターとのバトル（捕獲画面から開いたとき）の相手と、終わったときに呼ぶ処理
    struct WildBattle {
        /// 相手の野生のモンスター。対戦前の画面に、自分のモンスターと並べて出す
        let monster: Monster
        /// 捕獲画面から引き継ぐ AR。対戦中は、捕獲画面と同じ AR セッションで、野生のモンスターがいた場所に相手を置く
        let arHandoff: ARHandoff
        /// 決着して、勝ち負けの演出を見せ終わったときに呼ぶ。勝敗の結果の画面は出さない（勝てば捕獲画面が詳細画面を出し、負ければ「捕獲失敗…」を見せ終わってから呼ぶ）
        let onFinish: (BattleViewModel.Outcome) -> Void
        /// 対戦前に「にげる」が押されたときに呼ぶ
        let onFlee: () -> Void
    }

    @State private var viewModel: BattleViewModel
    /// 野生のモンスターとのバトルなら、その相手と終わったときに呼ぶ処理。ほかのプレイヤーとの対戦なら nil
    private let wildBattle: WildBattle?
    @Environment(\.scenePhase) private var scenePhase
    /// この画面が表示されているか
    /// TabView は別のタブに切り替えても画面を残すので、自分で ARView を外してカメラを止める
    @State private var isVisible = false

    /// - Parameters:
    ///   - service: 対戦相手とのやり取り。野生のモンスターと戦うときは、そのモンスターを渡した CPUBattleService
    ///   - collection: 自分のモンスター（バトルに出すモンスター）を読む保存先
    ///   - wildBattle: 野生のモンスターとのバトルなら、その相手と終わったときに呼ぶ処理
    init(service: any BattleService, collection: any MonsterCollection, wildBattle: WildBattle? = nil) {
        _viewModel = State(initialValue: BattleViewModel(service: service, collection: collection))
        self.wildBattle = wildBattle
    }

    /// マルチ対戦では、マップ画面と同じ ViewModel を受け取る。
    init(viewModel: BattleViewModel) {
        _viewModel = State(initialValue: viewModel)
        wildBattle = nil
    }

    var body: some View {
        content
            // 対戦中はタブバーを隠し、全画面で戦う（途中で別のタブに移れないようにもなる）
            // 野生のモンスターとのバトルは捕獲画面が隠しているので、ここでも隠したままにする（出すと食い違う）
            .toolbarVisibility(wildBattle == nil && viewModel.me == nil ? .automatic : .hidden, for: .tabBar)
            .onAppear {
                isVisible = true
                // マルチバトルのタブは画面が残り続けるので、ほかの画面で選び直したモンスターをここで反映する
                viewModel.reloadMyMonster()
            }
            .onDisappear {
                isVisible = false
                // 別のタブに移ったら、相手を待つのをやめる（対戦中ならそのまま続ける）
                viewModel.cancelSearch()
            }
            // アプリが閉じられたとき（ホームに戻った、画面を消した）も、相手を待つのをやめて部屋を片付ける
            // 待ったままにすると、終了しても部屋がしばらく残り、ほかの人がいない相手とつながってしまう
            .onChange(of: scenePhase) {
                if scenePhase == .background {
                    viewModel.cancelSearch()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let me = viewModel.me, let opponent = viewModel.opponent, let opponentMonster = viewModel.opponentMonster {
            BattleFightComponent(
                viewModel: viewModel,
                me: me,
                opponent: opponent,
                myMonster: viewModel.myMonster,
                opponentMonster: opponentMonster,
                isVisible: isVisible,
                arHandoff: wildBattle?.arHandoff,
                onFinish: wildBattle?.onFinish
            )
        } else {
            BattleLobbyComponent(
                myMonster: viewModel.myMonster,
                isSearching: viewModel.phase == .searching || viewModel.phase == .cancellingSearch,
                isCancelling: viewModel.phase == .cancellingSearch,
                errorMessage: viewModel.errorMessage,
                onFind: wildBattle == nil ? nil : { viewModel.findOpponent() },
                onCancel: { viewModel.cancelSearch() },
                wildMonster: wildBattle?.monster,
                onFlee: wildBattle?.onFlee
            )
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 対戦中の画面と同じく、暗い背景にビビッドな色の文字にする
            .background(BattleStyle.ink)
            .environment(\.colorScheme, .dark)
        }
    }
}

#Preview {
    // ダミーの相手。「バトルする」を押すと、少し待ってから CPU との対戦が始まる
    // 保存先はメモリの中だけ。バトルに出すモンスターが決まっていないので、自分のモンスターはランダムになる
    BattleView(service: CPUBattleService(), collection: SwiftDataMonsterCollection(inMemory: true))
}
