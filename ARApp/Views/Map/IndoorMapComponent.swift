//
//  IndoorMapComponent.swift
//  ARApp
//

import SwiftUI

/// 屋内マップ本体。地点と、プレイヤーの現在地を描く
/// 位置は `MapPosition`（0〜1 の割合）を、実際の表示サイズに掛けて求める
struct IndoorMapComponent: View {
    let locations: [Location]
    let currentLocation: Location?
    /// プレイヤーを描く位置。推定したチェックポイントの座標
    let currentPosition: MapPosition?
    let confidence: LocationConfidence

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Image("map")
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("会場マップ")

                ForEach(locations) { location in
                    LocationMarkerComponent(location: location, isCurrent: location.id == currentLocation?.id)
                        .position(point(for: location.iconPosition, in: size))
                }

                // プレイヤーは一番手前に描く
                if let currentPosition {
                    Image(systemName: "figure.walk.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white, color(for: confidence))
                        .position(point(for: currentPosition, in: size))
                }
            }
            // 推定の切り替わりを少しだけ滑らかにする
            .animation(.easeInOut(duration: 0.5), value: currentPosition)
        }
        // map.png は 1063 × 1799 の縦長。画像全体と正規化座標を一致させる
        .aspectRatio(1063.0 / 1799.0, contentMode: .fit)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func point(for position: MapPosition, in size: CGSize) -> CGPoint {
        CGPoint(x: position.x * size.width, y: position.y * size.height)
    }

    private func color(for confidence: LocationConfidence) -> Color {
        switch confidence {
        case .high: .blue
        case .medium: .orange
        case .low, .unavailable: .gray
        }
    }
}

/// 地点の目印と名前
private struct LocationMarkerComponent: View {
    let location: Location
    let isCurrent: Bool

    var body: some View {
        // 丸を地点の位置に置き、名前はその下に重ねる
        Circle()
            .fill(.white)
            .frame(width: 10, height: 10)
            .overlay(alignment: .top) {
                Text(location.name)
                    .font(.caption.bold())
                    .foregroundStyle(isCurrent ? .blue : .white)
                    .fixedSize()
                    // 現在地ではプレイヤーアイコンに隠れないよう、さらに下に出す
                    .offset(y: isCurrent ? 24 : 12)
            }
    }
}

#Preview {
    IndoorMapComponent(
        locations: Location.registered,
        currentLocation: Location.registered[0],
        currentPosition: Location.registered[0].iconPosition,
        confidence: .high
    )
    .padding()
}
