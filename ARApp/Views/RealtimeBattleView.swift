//
//  RealtimeBattleView.swift
//  ARApp
//

import SwiftUI

/// リアルタイムバトル画面。画面の空いている所をタップして攻撃し、溜まったら必殺技を撃つ
struct RealtimeBattleView: View {
    @State private var viewModel = RealtimeBattleViewModel()
    /// タップした位置の波紋。クールダウン中でも出るので、タップが届いているかがわかる
    @State private var tapRipple: TapRipple?

    private var state: RealtimeBattleState { viewModel.state }

    var body: some View {
        VStack(spacing: 16) {
            // 1. 上部：敵の名前と HP
            StatBar(
                title: state.enemyName,
                value: state.enemyHP,
                maxValue: RealtimeBattleState.enemyMaxHP,
                color: .red
            )

            // 2. 中央上：敵モンスター
            FighterImage(systemName: "flame.fill", color: .orange, size: 120)
                .overlay {
                    if let hit = viewModel.lastHitOnEnemy {
                        FloatingDamage(
                            text: "-\(hit.damage)",
                            color: hit.isSpecial ? .yellow : .red,
                            fontSize: hit.isSpecial ? 64 : 36
                        )
                        .id(hit.id)
                    }
                }
                .shake(trigger: viewModel.lastHitOnEnemy?.id)
                // 敵の攻撃のたびに自分の方へ踏み込む
                .lunge(CGSize(width: -24, height: 36), trigger: viewModel.lastHitOnPlayer?.id)
                // 倒したら薄くなる
                .opacity(state.outcome == .won ? 0.2 : 1)
                .animation(.easeOut(duration: 0.5), value: state.outcome)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Spacer(minLength: 0)

            // 3. 中央下：自分のモンスター
            FighterImage(systemName: "shield.lefthalf.filled", color: .blue, size: 90)
                .overlay {
                    if let hit = viewModel.lastHitOnPlayer {
                        FloatingDamage(text: "-\(hit.damage)", color: .purple, fontSize: 36)
                            .id(hit.id)
                    }
                }
                .shake(trigger: viewModel.lastHitOnPlayer?.id)
                // 攻撃するたびに敵の方へ踏み込む
                .lunge(CGSize(width: 24, height: -36), trigger: viewModel.lastHitOnEnemy?.id)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 4. 下部：自分の HP と必殺技ゲージ
            VStack(spacing: 8) {
                StatBar(
                    title: state.playerName,
                    value: state.playerHP,
                    maxValue: RealtimeBattleState.playerMaxHP,
                    color: .green
                )
                StatBar(
                    title: "必殺技ゲージ",
                    value: state.specialGauge,
                    maxValue: RealtimeBattleState.specialGaugeMax,
                    color: state.canUseSpecial ? .orange : .yellow
                )
            }

            // 5. 最下部：必殺技ボタン
            Button {
                viewModel.useSpecial()
            } label: {
                Label(state.canUseSpecial ? "必殺技 READY!" : "必殺技", systemImage: "bolt.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .disabled(!state.canUseSpecial)
        }
        .padding()
        // 空いている所もタップできるようにする。ボタンのタップはボタンが優先される
        .contentShape(Rectangle())
        .onTapGesture { location in
            tapRipple = TapRipple(location: location)
            viewModel.attack()
        }
        .overlay {
            if let tapRipple {
                RippleView()
                    .position(tapRipple.location)
                    .id(tapRipple.id)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            // 必殺技が当たった瞬間、画面全体を光らせる
            if let hit = viewModel.lastHitOnEnemy, hit.isSpecial {
                FlashView()
                    .id(hit.id)
            }
        }
        .overlay {
            // 決着後は結果を全面に出す。下の画面へのタップも遮る
            if let outcome = state.outcome {
                ResultOverlay(outcome: outcome) {
                    viewModel.retry()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: state.outcome)
        // 画面が出ている間だけ敵が攻撃する。画面が消えると自動でキャンセルされ、
        // リトライで battleID が変わると、前の Task を止めてから新しく始める
        .task(id: viewModel.battleID) {
            await viewModel.runEnemyAttacks()
        }
    }
}

private extension View {
    /// trigger が変わるたびに左右に揺れる（攻撃を受けた演出）
    func shake(trigger: UUID?) -> some View {
        phaseAnimator([0, -12, 12, -6, 0], trigger: trigger) { content, x in
            content.offset(x: x)
        } animation: { _ in
            .linear(duration: 0.05)
        }
    }

    /// trigger が変わるたびに offset の方向へ踏み込んで戻る（攻撃する演出）
    func lunge(_ offset: CGSize, trigger: UUID?) -> some View {
        phaseAnimator([CGSize.zero, offset, .zero], trigger: trigger) { content, value in
            content.offset(value)
        } animation: { _ in
            .easeOut(duration: 0.08)
        }
    }
}

/// 勝敗とリトライボタン
private struct ResultOverlay: View {
    let outcome: RealtimeBattleOutcome
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: outcome == .won ? "crown.fill" : "xmark.octagon.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(outcome == .won ? .yellow : .red)
                Text(outcome == .won ? "勝利！" : "敗北…")
                    .font(.largeTitle.bold())
                Button("リトライ", systemImage: "arrow.clockwise", action: onRetry)
                    .font(.headline)
                    .buttonStyle(.borderedProminent)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }
}

private struct TapRipple {
    let id = UUID()
    let location: CGPoint
}

/// タップした位置に広がって消える円
private struct RippleView: View {
    @State private var isExpanded = false

    var body: some View {
        Circle()
            .stroke(.secondary, lineWidth: 2)
            .frame(width: 60, height: 60)
            .scaleEffect(isExpanded ? 1 : 0.2)
            .opacity(isExpanded ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) { isExpanded = true }
            }
    }
}

/// ダメージの数字。上に浮かびながら消える
private struct FloatingDamage: View {
    let text: String
    let color: Color
    let fontSize: CGFloat
    @State private var isFloating = false

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .shadow(radius: 2)
            .offset(y: isFloating ? -80 : -20)
            .opacity(isFloating ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) { isFloating = true }
            }
    }
}

/// 画面全体が一瞬光って消える（必殺技の演出）
private struct FlashView: View {
    @State private var isFading = false

    var body: some View {
        Color.yellow
            .opacity(isFading ? 0 : 0.6)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { isFading = true }
            }
    }
}

/// モンスターの仮表示（SF Symbols）
private struct FighterImage: View {
    let systemName: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size))
            .foregroundStyle(color)
            .padding(24)
            .background(color.opacity(0.15), in: Circle())
    }
}

/// 名前と数値付きの横棒（HP バー・ゲージ共通）
private struct StatBar: View {
    let title: String
    let value: Int
    let maxValue: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(value) / \(maxValue)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * CGFloat(value) / CGFloat(maxValue))
                }
            }
            .frame(height: 12)
            .animation(.easeOut(duration: 0.2), value: value)
        }
    }
}

#Preview {
    RealtimeBattleView()
}
