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
    @State private var battleViewModel = BattleViewModel(service: Self.makeBattleService())
    @State private var nearbyBattleDiscovery = NearbyBattleDiscovery()
    @State private var selectedTab = "map"
    /// 捕まえたモンスターの保存先。図鑑や編成でも同じものを使うので、アプリ全体で 1 つだけ作る
    @State private var monsterCollection = SwiftDataMonsterCollection()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("マップ", systemImage: "map.fill", value: "map") {
                MapView(
                    locationViewModel: locationViewModel,
                    nearbyBattleDiscovery: nearbyBattleDiscovery,
                    onStartBattle: { pairingToken in
                        battleViewModel.findOpponent(pairingToken: pairingToken)
                        selectedTab = "battle"
                    }
                )
            }
            Tab("捕獲", systemImage: "camera.viewfinder", value: "capture") {
                ARCaptureView(locationViewModel: locationViewModel, collection: monsterCollection)
            }
            Tab("バトル", systemImage: "bolt.fill", value: "battle") {
                BattleView(viewModel: battleViewModel)
            }
        }
        .onAppear {
            locationViewModel.start()
        }
        .onDisappear {
            locationViewModel.stop()
        }
    }

    /// シミュレータには Bluetooth がないので、ダミーのビーコンで「入口」にいることにする
    private static func makeScanner() -> any BeaconScanner {
        #if targetEnvironment(simulator)
        DummyBeaconScanner()
        #else
        BLEBeaconScanner()
        #endif
    }

    /// SupabaseConfig に接続先が書いてあれば Supabase で対戦し、なければ CPU が相手になるダミーを使う
    /// 【開発用】ここで DummyBattleService を使うのは開発中だけ。リリースするときは SupabaseBattleService だけにする
    /// （DummyBattleService のクラス自体は BattleView の #Preview で使うので残す）
    private static func makeBattleService() -> any BattleService {
        if SupabaseConfig.isConfigured, let url = URL(string: SupabaseConfig.url) {
            SupabaseBattleService(url: url, anonKey: SupabaseConfig.anonKey)
        } else {
            DummyBattleService()
        }
    }
}

#Preview {
    ContentView()
}
