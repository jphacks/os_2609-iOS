//
//  ARCaptureView.swift
//  ARApp
//

import SwiftUI
import ARKit

/// AR 捕獲画面。カメラ映像の上に状態メッセージと現在地を重ねる
/// 歩き回るとモンスターが出て、AR で周りを歩く
struct ARCaptureView: View {
    /// 【開発用】locationViewModel は、下に重ねている LocationStatusComponent（RSSI の測定用）でしか使っていない
    let locationViewModel: LocationViewModel
    /// この画面が表示されているか
    /// TabView は別のタブに切り替えても画面を残すので、自分で ARView を外してカメラを止める
    @State private var isVisible = false

    @State private var viewModel = ARCaptureViewModel()

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
                Text(viewModel.statusMessage)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
            }
            .overlay(alignment: .bottom) {
                LocationStatusComponent(viewModel: locationViewModel)
                    .padding(.bottom, 8)
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
}
