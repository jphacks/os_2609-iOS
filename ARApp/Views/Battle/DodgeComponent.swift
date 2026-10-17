//
//  DodgeComponent.swift
//  ARApp
//

import SwiftUI

/// 必殺技をよけた・よけられたときに出す文字。自分がよけたら「よけた！」、相手によけられたら「よけられた…」
/// よけるたびに id を変えて置き直す。置かれると弾んで出て、少しすると消える
struct DodgeComponent: View {
    /// 自分がよけたか
    let isMine: Bool
    @State private var phase = 0

    /// 文字を出しておく時間（秒）
    private static let duration = 0.9

    var body: some View {
        Text(isMine ? "よけた！" : "よけられた…")
            .font(BattleStyle.display(56))
            .foregroundStyle(isMine ? .black : .white)
            .onBand(isMine ? BattleStyle.lime : .gray)
            .scaleEffect([0.4, 1, 1.2][phase])
            .opacity(phase == 1 ? 1 : 0)
            .allowsHitTesting(false)
            .task {
                withAnimation(.spring(duration: 0.25, bounce: 0.5)) { phase = 1 }
                try? await Task.sleep(for: .seconds(Self.duration))
                withAnimation(.easeIn(duration: 0.2)) { phase = 2 }
            }
    }
}

#Preview {
    VStack {
        DodgeComponent(isMine: true)
        DodgeComponent(isMine: false)
    }
    .background(.gray)
}
