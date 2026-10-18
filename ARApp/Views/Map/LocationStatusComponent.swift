//
//  LocationStatusComponent.swift
//  ARApp
//
//  ⚠️⚠️⚠️ 開発用の View ⚠️⚠️⚠️
//  会場で各地点の RSSI を測り、`Location.registered` の fingerprint に書き写すためのもの。
//  RSSI の測定が終わったら、このファイルごと削除してよい。
//  削除するときは次もあわせて消す：
//    1. ARCaptureView の `.overlay(alignment: .bottom) { LocationStatusComponent(...) }`
//    2. ARCaptureView の `locationViewModel` プロパティと、ContentView で渡している引数
//    3. LocationViewModel の `currentRSSI`（この View でしか使っていない）
//

import SwiftUI

/// 【開発用】推定した現在地と、その元になった RSSI を表示する
struct LocationStatusComponent: View {
    let viewModel: LocationViewModel

    var body: some View {
        VStack(spacing: 4) {
            Text(viewModel.statusMessage)
                .font(.headline)
            // 地点を登録するときに控える、6台すべての RSSI。未受信は -100 と表示する
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 2),
                alignment: .leading,
                spacing: 4
            ) {
                ForEach(Location.beaconIDs, id: \.self) { beaconName in
                    Text("\(beaconName) \(rssi(for: beaconName)) dBm")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(rssiColor(for: beaconName))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func rssi(for beaconName: String) -> Int {
        viewModel.currentRSSI[beaconName] ?? LocationViewModel.missingRSSI
    }

    private func rssiColor(for beaconName: String) -> Color {
        rssi(for: beaconName) == LocationViewModel.missingRSSI ? .secondary : .primary
    }
}

#Preview {
    let viewModel = LocationViewModel(scanner: DummyBeaconScanner())
    LocationStatusComponent(viewModel: viewModel)
        .onAppear { viewModel.start() }
}
