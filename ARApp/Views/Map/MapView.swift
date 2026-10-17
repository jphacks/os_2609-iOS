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
                currentPosition: locationViewModel.currentPosition
            )
        }
        .padding()
    }
}

#Preview("地点2") {
    // 地点2のパターンを流すダミー。1 秒ほどで現在地が「2」になる
    let point2 = Location.registered.first { $0.id == "point_2" }!
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
