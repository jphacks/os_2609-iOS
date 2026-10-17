//
//  MonsterDetailView.swift
//  ARApp
//

import SwiftUI

/// 捕獲したモンスターの詳細画面。3D モデル・名前・大きさを出す
struct MonsterDetailView: View {
    let monster: Monster
    /// ×ボタンが押されたときに呼ぶ
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            MonsterModelComponent(monster: monster)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(monster.name)
                .font(.largeTitle.bold())
            Text("大きさ \(monster.size, format: .number.precision(.fractionLength(0...2)))m")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 32)
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title2.bold())
                    .padding(8)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .padding()
        }
    }
}

#Preview {
    MonsterDetailView(monster: Monster.all[0]) {}
}
