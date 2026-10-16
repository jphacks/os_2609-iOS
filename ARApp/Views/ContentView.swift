//
//  ContentView.swift
//  ARApp
//
//  Created by Sakurai Erika on 2026/10/08.
//

import SwiftUI

struct ContentView: View {
    /// 現在地の推定はアプリ全体で 1 つだけ動かし、各画面で共有する
    @State private var locationViewModel = LocationViewModel(scanner: Self.makeScanner())

    var body: some View {
        TabView {
            Tab("マップ", systemImage: "map.fill") {
                MapView(locationViewModel: locationViewModel)
            }
            Tab("捕獲", systemImage: "camera.viewfinder") {
                ARCaptureView(locationViewModel: locationViewModel)
            }
            Tab("バトル", systemImage: "bolt.fill") {
                BattleView()
            }
        }
        .onAppear { locationViewModel.start() }
        .onDisappear { locationViewModel.stop() }
    }

    /// シミュレータには Bluetooth がないので、ダミーのビーコンで「入口」にいることにする
    private static func makeScanner() -> any BeaconScanner {
        #if targetEnvironment(simulator)
        DummyBeaconScanner()
        #else
        BLEBeaconScanner()
        #endif
    }
}

#Preview {
    ContentView()
}
