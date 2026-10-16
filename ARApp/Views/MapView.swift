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

            IndoorMapView(
                locations: Location.registered,
                monsterSpots: MonsterSpot.samples,
                raidSpots: RaidSpot.samples,
                currentLocation: locationViewModel.currentLocation
            )
        }
        .padding()
    }
}

#Preview {
    // ブースBのパターンを流すダミー。1 秒ほどで現在地が「ブースB」になる
    let viewModel = LocationViewModel(
        scanner: DummyBeaconScanner(rssiByBeacon: ["BeaconA": -80, "BeaconB": -66, "BeaconC": -45, "BeaconD": -72])
    )
    MapView(locationViewModel: viewModel)
        .onAppear { viewModel.start() }
}
