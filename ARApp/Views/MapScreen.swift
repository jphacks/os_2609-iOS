//
//  MapScreen.swift
//  ARApp
//

import SwiftUI

/// マップ画面。屋内マップと、現在地を切り替えるテスト用ボタンを表示する
/// 現在地はビーコンの RSSI から推定した場所 ID を使う
struct MapScreen: View {
    @State private var viewModel: MapViewModel
    @State private var locationViewModel: LocationViewModel

    init(scanner: any BeaconScanner = BLEBeaconScanner(), currentSpotID: String? = nil) {
        _viewModel = State(initialValue: MapViewModel(currentSpotID: currentSpotID))
        _locationViewModel = State(initialValue: LocationViewModel(scanner: scanner))
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(viewModel.currentSpot.map { "現在地：\($0.name)" } ?? "現在地を探しています…")
                .font(.headline)

            IndoorMapView(
                spots: viewModel.spots,
                monsterSpots: viewModel.monsterSpots,
                raidSpots: viewModel.raidSpots,
                currentSpot: viewModel.currentSpot
            )

            // テスト用：位置推定の代わりに、ボタンで現在地の場所 ID を切り替える
            // 推定結果が別の場所に変わると、そちらで上書きされる
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(viewModel.spots) { spot in
                        Button(spot.name) {
                            viewModel.updateCurrentSpot(id: spot.id)
                        }
                        .buttonStyle(.bordered)
                        .tint(spot.id == viewModel.currentSpotID ? .blue : .gray)
                    }
                }
            }
        }
        .padding()
        // 推定した場所 ID が変わったら、マップの現在地に反映する
        .onChange(of: locationViewModel.currentLocation?.id, initial: true) { _, id in
            guard let id else { return }
            viewModel.updateCurrentSpot(id: id)
        }
        .onAppear { locationViewModel.start() }
        .onDisappear { locationViewModel.stop() }
    }
}

#Preview("ダミーのビーコン") {
    // 「入口」のパターンを流すダミー。1 秒ほどで現在地が「入口」になる
    MapScreen(scanner: DummyBeaconScanner())
}

#Preview("ブースBから開始") {
    // ブースBのパターンを流す
    MapScreen(
        scanner: DummyBeaconScanner(rssiByBeacon: ["BeaconA": -80, "BeaconB": -66, "BeaconC": -45, "BeaconD": -72]),
        currentSpotID: "booth_b"
    )
}
