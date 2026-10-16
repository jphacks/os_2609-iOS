//
//  IndoorMapView.swift
//  ARApp
//

import SwiftUI

/// 屋内マップ本体。地点と、プレイヤーの現在地を描く
/// 位置は `MapPosition`（0〜1 の割合）を、実際の表示サイズに掛けて求める
struct IndoorMapView: View {
    let locations: [Location]
    let currentLocation: Location?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                // 床
                Rectangle()
                    .fill(Color(red: 0.62, green: 0.84, blue: 0.62))

                ForEach(locations) { location in
                    LocationMarkerView(location: location, isCurrent: location.id == currentLocation?.id)
                        .position(point(for: location.position, in: size))
                }

                // プレイヤーは一番手前に描く
                if let currentLocation {
                    Image(systemName: "figure.walk.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white, .blue)
                        .position(point(for: currentLocation.position, in: size))
                }
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func point(for position: MapPosition, in size: CGSize) -> CGPoint {
        CGPoint(x: position.x * size.width, y: position.y * size.height)
    }
}

/// 地点の目印と名前
private struct LocationMarkerView: View {
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
    IndoorMapView(locations: Location.registered, currentLocation: Location.registered[0])
        .padding()
}
