//
//  MonsterCardView.swift
//  ARApp
//

import SwiftUI

/// モンスターの見た目（3D モデルは AR 画面でだけ使うので、ここでは仮のアイコン）
struct MonsterCardView: View {
    let name: String
    let trait: String
    let isEnraged: Bool
    let isDefeated: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(
                    LinearGradient(
                        colors: isEnraged ? [.red, .orange] : [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .rect(cornerRadius: 12)
                )
                .overlay(alignment: .topTrailing) {
                    if isEnraged {
                        Label("怒り", systemImage: "flame.fill")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.4), in: .capsule)
                            .foregroundStyle(.white)
                            .padding(8)
                    }
                }
                .opacity(isDefeated ? 0.3 : 1)
                .animation(.easeInOut, value: isEnraged)

            HStack(spacing: 8) {
                Text(name)
                    .font(.title3.bold())
                Text(trait)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// モンスターの上に浮かんで消えるダメージの数字
struct FloatingDamageView: View {
    let text: String
    let color: Color

    @State private var isRisen = false

    var body: some View {
        Text(text)
            .font(.system(size: 44, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.4), radius: 2)
            .scaleEffect(isRisen ? 1 : 1.6)
            .offset(y: isRisen ? -40 : 0)
            .opacity(isRisen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) {
                    isRisen = true
                }
            }
    }
}

#Preview {
    MonsterCardView(name: "ライオン", trait: "連撃が多い", isEnraged: false, isDefeated: false)
        .overlay { FloatingDamageView(text: "-100", color: .orange) }
        .padding()
}
