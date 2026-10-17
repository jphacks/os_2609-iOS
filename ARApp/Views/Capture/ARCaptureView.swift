//
//  ARCaptureView.swift
//  ARApp
//

import SwiftUI
import ARKit

/// AR 捕獲画面。カメラ映像の上に状態メッセージと現在地を重ねる
/// 歩き回るとモンスターが出て、AR で周りを歩く。タップするとバトル（BattleView）を重ねて出す
struct ARCaptureView: View {
    /// AR を使う画面のうち、どちらを出すか
    private enum ARScreen: Equatable {
        /// 捕獲の AR（ARViewContainer）
        case capture
        /// 野生のモンスターとのバトル（BattleView。対戦中はバトルの ARView を作る）
        case battle(WildMonster.ID)
    }

    /// 捕獲の AR とバトルを切り替えるとき、前の画面を外してから次の画面を置くまで待つ時間
    /// ARView が 2 つ同時にあったり、外した直後に次を作ったりすると、AR が真っ黒になったり床に置けなくなったりする
    static let arSwitchDelay: Duration = .seconds(0.5)

    /// 【開発用】locationViewModel は、下に重ねている LocationStatusComponent（RSSI の測定用）でしか使っていない
    let locationViewModel: LocationViewModel
    @State private var viewModel: ARCaptureViewModel
    /// この画面が表示されているか
    /// TabView は別のタブに切り替えても画面を残すので、自分で ARView を外してカメラを止める
    @State private var isVisible = false
    /// 今出している AR の画面。nil は切り替え中（前の画面を外して、arSwitchDelay だけ待っている間）
    /// ViewModel の battleMonster が変わったら、ここを切り替える。ARView を置くかどうかはこれだけで決める
    @State private var arScreen: ARScreen? = .capture

    init(locationViewModel: LocationViewModel, collection: any MonsterCollection) {
        self.locationViewModel = locationViewModel
        _viewModel = State(initialValue: ARCaptureViewModel(collection: collection))
    }

    var body: some View {
        // ワールドトラッキングは A9 以降のチップを搭載した実機でのみ動作する（シミュレータは非対応）
        if ARWorldTrackingConfiguration.isSupported {
            ZStack {
                Color.black
                if isVisible && arScreen == .capture {
                    // 外すと ARViewContainer の dismantleUIView が呼ばれ、セッションが止まる
                    ARViewContainer(viewModel: viewModel)
                }
            }
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                Text(viewModel.statusMessage)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
            }
            .overlay {
                if let outcome = viewModel.captureOutcome {
                    CaptureResultComponent(outcome: outcome)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring, value: viewModel.captureOutcome != nil)
            // モンスターが現れたら振動させ、画面を見ていなくても気づけるようにする
            .sensoryFeedback(.warning, trigger: viewModel.wildMonster?.id) { (_: UUID?, id: UUID?) -> Bool in
                id != nil
            }
            .overlay(alignment: .bottom) {
                LocationStatusComponent(viewModel: locationViewModel)
                    .padding(.bottom, 8)
            }
            // バトルも fullScreenCover で開かず、重ねる（理由は下の詳細画面と同じ）
            // 捕獲の ARView を外し終わってから出す。バトルが終わったら battleMonster が nil になり、すぐに外れる
            .overlay {
                if case .battle = arScreen, let wild = viewModel.battleMonster {
                    BattleView(
                        service: CPUBattleService(opponent: wild.monster),
                        wildBattle: BattleView.WildBattle(
                            monster: wild.monster,
                            onFinish: { viewModel.finishBattle(won: $0 == .won) },
                            onFlee: { viewModel.fleeBattle() }
                        )
                    )
                }
            }
            // 詳細画面は fullScreenCover で開かず、一番上に重ねる
            // fullScreenCover だと AR の画面が画面から外れ、ARView が AR を止めたまま戻らなくなる
            // （止まらないよう開くたびに ARView を作り直すと、固まったり床が見つからなくなったりした）
            // 重ねるだけなら ARView は後ろで動き続け、見つけた床も残るので、閉じたらすぐ次のモンスターを置ける
            .overlay {
                if let monster = viewModel.detailMonster {
                    MonsterDetailView(monster: monster) { viewModel.closeDetail() }
                        .background(Color(.systemBackground))
                        .transition(.move(edge: .bottom))
                }
            }
            .animation(.easeInOut, value: viewModel.detailMonster == nil)
            // バトル・詳細画面を開いている間と切り替え中は、全画面に見えるようタブバーも隠す
            // 切り替え中に別のタブへ移ると、ARView の順番が崩れるため
            .toolbarVisibility(isTabBarShown ? .automatic : .hidden, for: .tabBar)
            // バトルが始まったら捕獲の ARView を外し、少し待ってからバトルを出す
            // バトルが終わったら（バトルはすぐに外れる）、少し待ってから捕獲の ARView を作り直す
            // 作り直すと床は探し直しになるが、捕獲の結果や詳細画面を出している間に見つかる
            .task(id: viewModel.battleMonster?.id) {
                let next: ARScreen = viewModel.battleMonster.map { .battle($0.id) } ?? .capture
                // 別のタブから戻ってきたときなど、もう出している
                guard arScreen != next else { return }
                arScreen = nil
                try? await Task.sleep(for: Self.arSwitchDelay)
                guard !Task.isCancelled else { return }
                arScreen = next
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
        } else {
            ContentUnavailableView(
                "ARに対応していません",
                systemImage: "arkit",
                description: Text("このデバイスではARを利用できません。ARKit対応のiPhoneまたはiPadの実機で起動してください。")
            )
        }
    }

    private var isTabBarShown: Bool {
        arScreen == .capture && viewModel.battleMonster == nil && viewModel.detailMonster == nil
    }
}
