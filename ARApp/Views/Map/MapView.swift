//
//  MapView.swift
//  ARApp
//

import SwiftUI

/// マップ画面。屋内マップの上に、推定した現在地を表示する
struct MapView: View {
    let locationViewModel: LocationViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text(locationViewModel.statusMessage)
                .font(.headline)

            IndoorMapComponent(
                locations: Location.registered,
                currentLocation: locationViewModel.currentLocation,
                currentPosition: locationViewModel.currentPosition,
                confidence: locationViewModel.confidence
            )

            LocationSignalComponent(viewModel: locationViewModel)
        }
        .padding()
    }
}

/// 最寄りビーコンと推定の確からしさを表示する
private struct LocationSignalComponent: View {
    let viewModel: LocationViewModel

    var body: some View {
        HStack {
            Label(viewModel.nearestBeacon ?? "ビーコン未検出", systemImage: "dot.radiowaves.left.and.right")
            Spacer()
            Text("信頼度：\(viewModel.confidence.label)")
                .foregroundStyle(confidenceColor)
        }
        .font(.subheadline)
    }

    private var confidenceColor: Color {
        switch viewModel.confidence {
        case .high: .blue
        case .medium: .orange
        case .low, .unavailable: .secondary
        }
    }
}

#Preview("地点2") {
    // 地点2のパターンを流すダミー。1 秒ほどで現在地が「2」になる
    let point2 = Location.registered.first { $0.id == "checkpoint_2" }!
    let viewModel = LocationViewModel(scanner: DummyBeaconScanner(location: point2))
    MapView(locationViewModel: viewModel)
        .onAppear { viewModel.start() }
}

#Preview("地点を巡る") {
    // 登録済みの地点を順に歩くダミー。プレイヤーが地点と地点の間を動く
    let viewModel = LocationViewModel(scanner: DummyBeaconScanner(walkingThrough: Location.registered))
    MapView(locationViewModel: viewModel)
        .onAppear { viewModel.start() }
}
