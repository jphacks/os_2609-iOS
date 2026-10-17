//
//  ARCaptureView.swift
//  ARApp
//

import SwiftUI
import ARKit

/// AR 捕獲画面。カメラ映像の上に状態メッセージと現在地を重ねる
struct ARCaptureView: View {
    let locationViewModel: LocationViewModel
    @State private var viewModel = ARCaptureViewModel()
    /// この画面が表示されているか
    /// TabView は別のタブに切り替えても画面を残すので、自分で ARView を外してカメラを止める
    @State private var isVisible = false

    var body: some View {
        // ワールドトラッキングは A9 以降のチップを搭載した実機でのみ動作する（シミュレータは非対応）
        if ARWorldTrackingConfiguration.isSupported {
            ZStack {
                Color.black
                if isVisible {
                    // 外すと ARViewContainer の dismantleUIView が呼ばれ、セッションが止まる
                    ARViewContainer(viewModel: viewModel)
                }
            }
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                if let statusMessage = viewModel.statusMessage {
                    Text(statusMessage)
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 8)
                }
            }
            .overlay {
                if let outcome = viewModel.captureOutcome {
                    CaptureResultComponent(outcome: outcome)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring, value: viewModel.captureOutcome != nil)
            .overlay(alignment: .bottom) {
                LocationStatusComponent(viewModel: locationViewModel)
                    .padding(.bottom, 8)
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
            // 詳細画面を開いている間は、全画面に見えるようタブバーも隠す
            .toolbarVisibility(viewModel.detailMonster == nil ? .automatic : .hidden, for: .tabBar)
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
}
