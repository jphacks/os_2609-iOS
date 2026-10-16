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
                currentLocation: locationViewModel.currentLocation
            )
        }
        .padding()
    }
}

#Preview {
    // ブースBのパターンを流すダミー。1 秒ほどで現在地が「ブースB」になる
    let boothB = Location.registered.first { $0.id == "booth_b" }!
    let viewModel = LocationViewModel(scanner: DummyBeaconScanner(location: boothB))
    MapView(locationViewModel: viewModel)
        .onAppear { viewModel.start() }
}
