//
//  BattleView.swift
//  ARApp
//

import SwiftUI

/// 対戦画面。「バトルする」で対戦相手を探し、見つかったら対戦が始まる
/// 画面の空いている所をタップして攻撃し、左右にスワイプしてよける（必殺技とフィーバーは自動）
/// 対戦中は、カメラに映る床の上でモンスター同士が戦う（AR）
/// 対戦前は BattleLobbyComponent、対戦中は BattleFightComponent を出す（どちらも同じフォルダにある）
struct BattleView: View {
    @State private var viewModel: BattleViewModel
    @Environment(\.scenePhase) private var scenePhase
    /// この画面が表示されているか
    /// TabView は別のタブに切り替えても画面を残すので、自分で ARView を外してカメラを止める
    @State private var isVisible = false

    init(service: any BattleService) {
        _viewModel = State(initialValue: BattleViewModel(service: service))
    }

    var body: some View {
        content
            .onAppear { isVisible = true }
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
                isVisible: isVisible
            )
        } else {
            BattleLobbyComponent(
                myMonster: viewModel.myMonster,
                isSearching: viewModel.phase == .searching || viewModel.phase == .cancellingSearch,
                isCancelling: viewModel.phase == .cancellingSearch,
                errorMessage: viewModel.errorMessage,
                onFind: { viewModel.findOpponent() },
                onCancel: { viewModel.cancelSearch() }
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
    BattleView(service: DummyBattleService())
}
