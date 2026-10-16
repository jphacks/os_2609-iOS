//
//  HPBarView.swift
//  ARApp
//

import SwiftUI

struct HPBarView: View {
    let title: String
    let hp: Int
    let maxHP: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(hp) / \(maxHP)")
                    .monospacedDigit()
            }
            .font(.subheadline)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.gray.opacity(0.2))
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * Double(hp) / Double(maxHP))
                }
            }
            .frame(height: 10)
            .animation(.easeOut(duration: 0.4), value: hp)
        }
    }
}

#Preview {
    HPBarView(title: "YOUR HP", hp: 60, maxHP: 100, color: .green)
        .padding()
}
