//
//  MonsterPreviewComponent.swift
//  ARApp
//

import SwiftUI

/// 図鑑や編成の上半分。選んでいるモンスターの 3D（指で回せる）と、名前・大きさを出す
struct MonsterPreviewComponent: View {
    let monster: Monster

    var body: some View {
        VStack(spacing: 8) {
            // RealityKit ではなく SceneKit で表示する。理由は MonsterModelComponent に書いてある
            // 小さいモンスターも大きく見えるよう、どれも同じ高さにそろえる（大きさは下に文字で出す）
            // モンスターが変わったら作り直す（指で回した向きも正面に戻る）
            MonsterModelComponent(monster: monster, height: 2.4)
                .id(monster.modelName)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(monster.name)
                .font(BattleStyle.display(32))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.black)
                .onBand(BattleStyle.cyan)
            Text("大きさ \(monster.size, format: .number.precision(.fractionLength(0...2)))m")
                .font(BattleStyle.display(18))
                .foregroundStyle(BattleStyle.lime)
        }
    }
}

#Preview {
    MonsterPreviewComponent(monster: Monster.all[0])
        .padding()
        .background(BattleStyle.ink)
}
