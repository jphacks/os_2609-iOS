//
//  LocationStatusView.swift
//  ARApp
//

import SwiftUI

/// 推定した現在地と、その元になった RSSI を表示する
struct LocationStatusView: View {
    let viewModel: LocationViewModel

    var body: some View {
        VStack(spacing: 4) {
            Text(viewModel.statusMessage)
                .font(.headline)
            if !viewModel.currentRSSI.isEmpty {
                // 地点を登録するときに控える値
                Text("RSSI \(viewModel.currentRSSI.map(String.init).joined(separator: ", "))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    let viewModel = LocationViewModel(scanner: DummyBeaconScanner())
    LocationStatusView(viewModel: viewModel)
        .onAppear { viewModel.start() }
}
