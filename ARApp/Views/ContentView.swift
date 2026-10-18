//
//  ContentView.swift
//  ARApp
//
//  Created by Sakurai Erika on 2026/10/08.
//

import SwiftUI

struct ContentView: View {
    /// アプリのタブ
    private enum AppTab {
        case map, capture, battle
    }

    /// 現在地の推定はアプリ全体で 1 つだけ動かし、各画面で共有する
    @State private var locationViewModel = LocationViewModel(scanner: Self.makeScanner())
    @State private var battleService = Self.makeBattleService()
    @State private var selectedTab = AppTab.map
    /// 捕まえたモンスターの保存先（ARAppApp で 1 つだけ作ったもの）
    let monsterCollection: any MonsterCollection

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("マップ", systemImage: "map.fill", value: AppTab.map) {
                MapView(locationViewModel: locationViewModel)
            }
            Tab("捕獲", systemImage: "camera.viewfinder", value: AppTab.capture) {
                ARCaptureView(locationViewModel: locationViewModel, collection: monsterCollection)
            }
            Tab("マルチバトル", systemImage: "bolt.fill", value: AppTab.battle) {
                BattleView(service: battleService)
            }
        }
        // 最初にモンスターを選ぶ画面を出している間はマップタブのままなので、捕獲画面の ARView は作られない
        .starterMonsterSelection(collection: monsterCollection) {
            selectedTab = .capture
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

    /// SupabaseConfig に接続先が書いてあれば Supabase で対戦し、なければ CPU が相手になる
    /// 【開発用】ここで CPUBattleService を使うのは開発中だけ。リリースするときは SupabaseBattleService だけにする
    /// （CPUBattleService のクラス自体は、捕獲画面の野生のモンスターとのバトルで使うので残す）
    private static func makeBattleService() -> any BattleService {
        if SupabaseConfig.isConfigured, let url = URL(string: SupabaseConfig.url) {
            SupabaseBattleService(url: url, anonKey: SupabaseConfig.anonKey)
        } else {
            CPUBattleService()
        }
    }
}

#Preview {
    ContentView(monsterCollection: SwiftDataMonsterCollection(inMemory: true))
}
