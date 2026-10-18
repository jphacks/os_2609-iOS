//
//  ARAppApp.swift
//  ARApp
//
//  Created by Sakurai Erika on 2026/10/08.
//

import SwiftUI

@main
struct ARAppApp: App {
    /// 捕まえたモンスターの保存先。同じ保存先を何度も開くと SwiftData がぶつかるので、アプリ全体で 1 つだけ作る
    @State private var monsterCollection = SwiftDataMonsterCollection()

    var body: some Scene {
        WindowGroup {
            ContentView(monsterCollection: monsterCollection)
        }
    }
}
