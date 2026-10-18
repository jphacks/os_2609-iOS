//
//  MonsterDetailView.swift
//  ARApp
//

import SwiftUI

/// 捕獲したモンスターの詳細画面。バトルに勝ったときに開く
/// 「GET!!」をたたきつけ、後ろで光の筋を回し、紙吹雪を降らせる（バトル画面と同じ、ビビッドでパキッとした見た目）
/// 3D モデル・名前・大きさを出す。3D は指で回せる
struct MonsterDetailView: View {
    let monster: Monster
    /// 「つぎへ」が押されたときに呼ぶ
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 出し始めたか。文字をたたきつけ、モンスターを弾ませるきっかけにする
    @State private var isShown = false
    /// 光の筋の角度
    @State private var rotation = 0.0
    /// 「GET!!」の帯の色を切り替えるか（ピンクと水色で点滅させる）
    @State private var isBlinking = false

    /// 光の筋の本数
    private static let rayCount = 16

    var body: some View {
        ZStack {
            BattleStyle.ink
                .ignoresSafeArea()
            rays
            ConfettiComponent()
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("GET!!")
                    .font(BattleStyle.display(96))
                    .foregroundStyle(BattleStyle.yellow)
                    .onBand(isBlinking ? BattleStyle.cyan : BattleStyle.pink, slant: 28)
                    .rotationEffect(.degrees(-6))
                    // 大きいところから、たたきつけるように縮める
                    .scaleEffect(isShown || reduceMotion ? 1 : 2.5)
                    .opacity(isShown ? 1 : 0)
                Text("捕獲成功！")
                    .font(BattleStyle.display(28))
                    .foregroundStyle(.white)

                // RealityKit ではなく SceneKit で表示する。理由は MonsterModelComponent に書いてある
                // 小さいモンスターも大きく見えるよう、どれも同じ高さにそろえる（大きさは下に文字で出す）
                MonsterModelComponent(monster: monster, height: 2.4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(isShown || reduceMotion ? 1 : 0.3)

                Text(monster.name)
                    .font(BattleStyle.display(40))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.black)
                    .onBand(BattleStyle.cyan)
                Text("大きさ \(monster.size, format: .number.precision(.fractionLength(0...2)))m")
                    .font(BattleStyle.display(20))
                    .foregroundStyle(BattleStyle.lime)

                Button("つぎへ", action: onClose)
                    .buttonStyle(BattleButtonStyle())
                    .padding(.top, 8)
            }
            .padding()
        }
        .environment(\.colorScheme, .dark)
        .sensoryFeedback(.success, trigger: isShown) { (_: Bool, isShown: Bool) -> Bool in
            isShown
        }
        .onAppear {
            withAnimation(.spring(duration: 0.45, bounce: 0.55)) { isShown = true }
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { rotation = 360 }
            withAnimation(.linear(duration: 0.25).repeatForever()) { isBlinking = true }
        }
    }

    /// 画面の真ん中から放射状に広がり、回り続ける光の筋
    private var rays: some View {
        ZStack {
            ForEach(0..<Self.rayCount, id: \.self) { index in
                Rectangle()
                    .fill([BattleStyle.yellow, BattleStyle.pink, BattleStyle.cyan][index % 3])
                    .opacity(0.35)
                    .frame(width: 40, height: 700)
                    .offset(y: -350)
                    .rotationEffect(.degrees(Double(index) / Double(Self.rayCount) * 360))
            }
        }
        .rotationEffect(.degrees(rotation))
        .opacity(isShown ? 1 : 0)
        .allowsHitTesting(false)
    }
}

/// 上から降り続ける、ビビッドな色の四角い紙吹雪
private struct ConfettiComponent: View {
    /// 紙吹雪 1 枚ぶん。位置や速さは作るときにランダムに決める
    private struct Piece: Identifiable {
        let id = UUID()
        let x = Double.random(in: 0...1)
        let delay = Double.random(in: 0...2)
        let duration = Double.random(in: 1.8...3.2)
        let spin = Double.random(in: 180...720)
        let color = [BattleStyle.yellow, BattleStyle.pink, BattleStyle.cyan, BattleStyle.lime].randomElement()!
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pieces = (0..<40).map { _ in Piece() }

    var body: some View {
        GeometryReader { proxy in
            // 動きを減らす設定のときは、紙吹雪を降らせない
            if !reduceMotion {
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(pieces) { piece in
                            // 落ちきったら上に戻って、くり返し降らせる
                            let progress = ((time + piece.delay).truncatingRemainder(dividingBy: piece.duration)) / piece.duration
                            Rectangle()
                                .fill(piece.color)
                                .frame(width: 8, height: 14)
                                .rotationEffect(.degrees(progress * piece.spin))
                                .position(x: piece.x * proxy.size.width, y: -20 + progress * (proxy.size.height + 40))
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    MonsterDetailView(monster: Monster.all[0]) {}
}
