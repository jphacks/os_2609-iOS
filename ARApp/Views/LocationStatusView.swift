//
//  LocationStatusView.swift
//  ARApp
//
//  ⚠️⚠️⚠️ 開発用の View ⚠️⚠️⚠️
//  会場で各地点の RSSI を測り、`Location.registered` の fingerprint に書き写すためのもの。
//  RSSI の測定が終わったら、このファイルごと削除してよい。
//  削除するときは次もあわせて消す：
//    1. ARCaptureView の `.overlay(alignment: .bottom) { LocationStatusView(...) }`
//    2. ARCaptureView の `locationViewModel` プロパティと、ContentView で渡している引数
//    3. LocationViewModel の `currentRSSI`（この View でしか使っていない）
//

import SwiftUI

/// 【開発用】推定した現在地と、その元になった RSSI を表示する
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
