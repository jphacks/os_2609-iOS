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
    /// 会場のどこにモンスターがいるかも、マップ画面と捕獲画面で共有する
    @State private var wildMonsterViewModel = WildMonsterViewModel(service: Self.makeWildMonsterService())
    @State private var battleService = Self.makeBattleService()

    var body: some View {
        TabView {
            Tab("マップ", systemImage: "map.fill") {
                MapView(locationViewModel: locationViewModel)
            }
            Tab("捕獲", systemImage: "camera.viewfinder") {
                ARCaptureView(locationViewModel: locationViewModel, wildMonsterViewModel: wildMonsterViewModel)
            }
            Tab("バトル", systemImage: "bolt.fill") {
                BattleView(locationViewModel: locationViewModel, service: battleService)
            }
        }
        .onAppear {
            locationViewModel.start()
            wildMonsterViewModel.start()
        }
        .onDisappear {
            locationViewModel.stop()
            wildMonsterViewModel.stop()
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

    /// SupabaseConfig に接続先が書いてあればプレイヤー全員でモンスターを共有し、なければこの端末の中だけで出すダミーを使う
    /// 【開発用】ここで DummyWildMonsterService を使うのは開発中だけ。リリースするときは SupabaseWildMonsterService だけにする
    private static func makeWildMonsterService() -> any WildMonsterService {
        if SupabaseConfig.isConfigured, let url = URL(string: SupabaseConfig.url) {
            SupabaseWildMonsterService(url: url, anonKey: SupabaseConfig.anonKey)
        } else {
            DummyWildMonsterService()
        }
    }
}

#Preview {
    ContentView()
}
