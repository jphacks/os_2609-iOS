//
//  RealtimeBattleView.swift
//  ARApp
//

import SwiftUI

/// リアルタイムバトル画面。画面の空いている所をタップして攻撃し、溜まったら必殺技を撃つ
struct RealtimeBattleView: View {
    @State private var viewModel = RealtimeBattleViewModel()
    /// タップした位置の波紋（タップできているかの確認用）
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
                .frame(maxWidth: .infinity, alignment: .trailing)

            Spacer(minLength: 0)

            // 3. 中央下：自分のモンスター
            FighterImage(systemName: "shield.lefthalf.filled", color: .blue, size: 90)
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
                    color: .yellow
                )
            }

            // 5. 最下部：必殺技ボタン
            Button {
                // 必殺技は Step 4 で実装する
            } label: {
                Label("必殺技", systemImage: "bolt.fill")
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
        }
        .overlay {
            if let tapRipple {
                RippleView()
                    .position(tapRipple.location)
                    .id(tapRipple.id)
                    .allowsHitTesting(false)
            }
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
