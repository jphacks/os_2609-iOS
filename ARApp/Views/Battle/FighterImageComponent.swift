//
//  FighterImageComponent.swift
//  ARApp
//

import SwiftUI

/// モンスターの仮表示（SF Symbols）。3D モデルは AR 画面でだけ使う
struct FighterImageComponent: View {
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

#Preview {
    FighterImageComponent(systemName: "flame.fill", color: .orange, size: 120)
}
