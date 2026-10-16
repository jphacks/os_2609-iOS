//
//  ContentView.swift
//  ARApp
//
//  Created by Sakurai Erika on 2026/10/08.
//

import SwiftUI
import ARKit

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("マップ", systemImage: "map.fill") {
                MapScreen()
            }
            Tab("捕獲", systemImage: "camera.viewfinder") {
                captureView
            }
        }
    }

    @ViewBuilder
    private var captureView: some View {
        // ワールドトラッキングは A9 以降のチップを搭載した実機でのみ動作する（シミュレータは非対応）
        if ARWorldTrackingConfiguration.isSupported {
            ARCaptureView()
        } else {
            ContentUnavailableView(
                "ARに対応していません",
                systemImage: "arkit",
                description: Text("このデバイスではARを利用できません。ARKit対応のiPhoneまたはiPadの実機で起動してください。")
            )
        }
    }
}

#Preview {
    ContentView()
}
