//
//  CaptureFailedComponent.swift
//  ARApp
//

import SwiftUI

/// 野生のモンスターとのバトルで負けたときに、大きく「捕獲失敗…」を出す（VictoryComponent の負けた版）
/// 左右から斜めの帯が飛び込んできて交差し、その上に文字がたたきつけられる
/// 少し見せたあと、BattleFightComponent が捕獲画面に戻す
struct CaptureFailedComponent: View {
    /// 逃げられたモンスターの名前
    let monsterName: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            // 交差する 2 本の帯。左上と右下から飛び込んでくる
            ZStack {
                stripe(color: BattleStyle.red)
                    .rotationEffect(.degrees(-12))
                    .offset(x: isShown || reduceMotion ? 0 : -500)
                stripe(color: BattleStyle.ink)
                    .rotationEffect(.degrees(8))
                    .offset(x: isShown || reduceMotion ? 0 : 500)
            }

            VStack(spacing: 12) {
                Text("捕獲失敗…")
                    .font(BattleStyle.display(72))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .onBand(BattleStyle.red, slant: 24)
                    .rotationEffect(.degrees(-4))
                    // 大きいところから、たたきつけるように縮める
                    .scaleEffect(isShown || reduceMotion ? 1 : 2.2)
                Text("\(monsterName)に逃げられた！")
                    .font(BattleStyle.display(24))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.black)
                    .onBand(BattleStyle.cyan)
            }
            .padding(.horizontal)
            .opacity(isShown ? 1 : 0)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) { isShown = true }
        }
    }

    /// 画面の幅いっぱいの、黒い縁取りの帯
    private func stripe(color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: 900, height: 90)
            .overlay {
                Rectangle()
                    .stroke(.black, lineWidth: 4)
            }
            .opacity(0.9)
    }
}

#Preview {
    CaptureFailedComponent(monsterName: "キノコキング")
        .background(.gray)
}
