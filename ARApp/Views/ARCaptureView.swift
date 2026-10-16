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

    var body: some View {
        // ワールドトラッキングは A9 以降のチップを搭載した実機でのみ動作する（シミュレータは非対応）
        if ARWorldTrackingConfiguration.isSupported {
            ARViewContainer(viewModel: viewModel)
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
                    LocationStatusView(viewModel: locationViewModel)
                        .padding(.bottom, 8)
                }
        } else {
            ContentUnavailableView(
                "ARに対応していません",
                systemImage: "arkit",
                description: Text("このデバイスではARを利用できません。ARKit対応のiPhoneまたはiPadの実機で起動してください。")
            )
        }
    }
}
