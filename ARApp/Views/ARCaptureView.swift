//
//  ARCaptureView.swift
//  ARApp
//

import SwiftUI

/// AR 捕獲画面。カメラ映像の上に状態メッセージを重ねる
struct ARCaptureView: View {
    @State private var viewModel = ARCaptureViewModel()

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
    }
}
