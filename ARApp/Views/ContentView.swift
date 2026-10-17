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
    /// 捕まえたモンスターの保存先。図鑑や編成でも同じものを使うので、アプリ全体で 1 つだけ作る
    @State private var monsterCollection: SwiftDataMonsterCollection
    @State private var selectedTab = AppTab.map
    /// 最初にモンスターを選ぶ画面を出しているか。バトルに出すモンスターがまだ決まっていなければ、起動したときに出す
    @State private var isChoosingStarter: Bool

    init() {
        let collection = SwiftDataMonsterCollection()
        _monsterCollection = State(initialValue: collection)
        _isChoosingStarter = State(initialValue: collection.battleMonster == nil)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("マップ", systemImage: "map.fill", value: AppTab.map) {
                MapView(locationViewModel: locationViewModel)
            }
            Tab("捕獲", systemImage: "camera.viewfinder", value: AppTab.capture) {
                ARCaptureView(locationViewModel: locationViewModel, collection: monsterCollection)
            }
            Tab("バトル", systemImage: "bolt.fill", value: AppTab.battle) {
                BattleView(service: battleService)
            }
        }
        // 最初にモンスターを選ぶ画面は、タブの上に重ねて出す。決めたら捕獲タブ（AR）に移る
        // 出している間はマップタブのままなので、捕獲画面の ARView は作られない（RealityKit の画面は 1 つだけにする）
        .overlay {
            if isChoosingStarter {
                StarterMonsterView(collection: monsterCollection) {
                    isChoosingStarter = false
                    selectedTab = .capture
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: isChoosingStarter)
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
