//
//  ARCaptureView.swift
//  ARApp
//

import SwiftUI

/// AR 捕獲画面。カメラ映像の上に状態メッセージと現在地を重ねる
struct ARCaptureView: View {
    @State private var viewModel = ARCaptureViewModel()
    @State private var locationViewModel = LocationViewModel(scanner: BLEBeaconScanner())

    var body: some View {
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
            .onAppear { locationViewModel.start() }
            .onDisappear { locationViewModel.stop() }
    }
}
