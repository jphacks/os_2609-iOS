//
//  MonsterCellComponent.swift
//  ARApp
//

import SwiftUI

/// 図鑑や編成のマス 1 つ。モンスターの画像と名前を出す
/// まだ捕まえていないモンスターは、画像をシルエットにして、名前を「？？？」にする
struct MonsterCellComponent: View {
    let monster: Monster
    let isCaptured: Bool
    /// 選ばれているか（上半分に出しているモンスター）。枠を黄色くする
    let isSelected: Bool

    @State private var image: UIImage?
    /// 画像を描けなかったか（USDZ を読み込めなかった）。描いている途中と分けて、読み込み中のまま回り続けないようにする
    @State private var isImageUnavailable = false

    var body: some View {
        VStack(spacing: 4) {
            thumbnail
                .aspectRatio(1, contentMode: .fit)
            Text(isCaptured ? monster.name : "？？？")
                .font(BattleStyle.display(16))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(isCaptured ? .white : .white.opacity(0.4))
        }
        .padding(8)
        .background(.white.opacity(isCaptured ? 0.08 : 0.03))
        .overlay {
            Rectangle()
                .stroke(isSelected ? BattleStyle.yellow : .white.opacity(0.2), lineWidth: isSelected ? 3 : 1)
        }
        .task(id: monster.modelName) {
            let loaded = await MonsterThumbnail.image(for: monster)
            // キャンセルされて nil が返ったときは、描けなかったことにしない
            guard !Task.isCancelled else { return }
            image = loaded
            isImageUnavailable = loaded == nil
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image {
            if isCaptured {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                // 透明でないところだけを 1 色で塗る
                Image(uiImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white.opacity(0.15))
            }
        } else if isImageUnavailable {
            Image(systemName: "questionmark.square.dashed")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    HStack {
        MonsterCellComponent(monster: Monster.all[0], isCaptured: true, isSelected: true)
        MonsterCellComponent(monster: Monster.all[1], isCaptured: true, isSelected: false)
        MonsterCellComponent(monster: Monster.all[2], isCaptured: false, isSelected: false)
    }
    .padding()
    .background(BattleStyle.ink)
}
