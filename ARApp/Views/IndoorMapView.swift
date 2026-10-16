//
//  IndoorMapView.swift
//  ARApp
//

import SwiftUI

/// 屋内マップ本体。背景・地点・モンスター・レイド地点・プレイヤーを重ねて描く
/// 位置は `MapPosition`（0〜1 の割合）を、実際の表示サイズに掛けて求める
struct IndoorMapView: View {
    let locations: [Location]
    var monsterSpots: [MonsterSpot] = []
    var raidSpots: [RaidSpot] = []
    let currentLocation: Location?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                MapBackgroundView(locations: locations, corridors: Location.corridors, size: size)

                ForEach(locations) { location in
                    LocationMarkerView(location: location, isCurrent: location.id == currentLocation?.id)
                        .position(point(for: location.position, in: size))
                }

                ForEach(raidSpots) { raid in
                    RaidMarkerView(raid: raid)
                        .position(point(for: raid.position, in: size))
                }

                ForEach(monsterSpots) { monster in
                    MonsterMarkerView(monster: monster)
                        .position(point(for: monster.position, in: size))
                }

                // プレイヤーは一番手前に描く
                if let currentLocation {
                    PlayerMarkerView()
                        .position(point(for: currentLocation.position, in: size))
                        // 現在地が変わったら、新しい位置までなめらかに移動する
                        .animation(.spring(duration: 0.6, bounce: 0.25), value: currentLocation.id)
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

/// 簡易マップの背景。床と通路、各場所の部屋を図形で描く
private struct MapBackgroundView: View {
    let locations: [Location]
    let corridors: [(from: String, to: String)]
    let size: CGSize

    var body: some View {
        ZStack {
            // 床
            Rectangle()
                .fill(Color(red: 0.62, green: 0.84, blue: 0.62))

            // 通路：つながっている地点どうしを線で結ぶ
            Path { path in
                for corridor in corridors {
                    guard let from = point(of: corridor.from), let to = point(of: corridor.to) else { continue }
                    path.move(to: from)
                    path.addLine(to: to)
                }
            }
            .stroke(Color(red: 0.95, green: 0.9, blue: 0.75),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))

            // 各地点の部屋
            ForEach(locations) { location in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.5, green: 0.74, blue: 0.55))
                    .stroke(.white.opacity(0.6), lineWidth: 2)
                    .frame(width: size.width * 0.26, height: size.height * 0.15)
                    .position(x: location.position.x * size.width, y: location.position.y * size.height)
            }
        }
    }

    private func point(of locationID: String) -> CGPoint? {
        guard let location = locations.first(where: { $0.id == locationID }) else { return nil }
        return CGPoint(x: location.position.x * size.width, y: location.position.y * size.height)
    }
}

/// 地点の目印と名前
private struct LocationMarkerView: View {
    let location: Location
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(isCurrent ? .white : .white.opacity(0.7))
                .frame(width: 10, height: 10)
            Text(location.name)
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .shadow(radius: 1)
        }
        // 目印の丸が場所の位置に来るように、名前のぶん下にずらす
        .offset(y: 8)
    }
}

/// モンスターのアイコン。その場でふわふわ上下に揺れる
private struct MonsterMarkerView: View {
    let monster: MonsterSpot
    @State private var isFloating = false

    var body: some View {
        Image(systemName: "pawprint.circle.fill")
            .font(.system(size: 28))
            .foregroundStyle(.white, .orange)
            .shadow(radius: 2)
            .offset(y: isFloating ? -4 : 0)
            .animation(.easeInOut(duration: 1).repeatForever(), value: isFloating)
            .onAppear { isFloating = true }
            .accessibilityLabel(monster.name)
    }
}

/// レイド地点のアイコン。台座の上にボスの印を置く
private struct RaidMarkerView: View {
    let raid: RaidSpot

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.purple, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white, lineWidth: 2))
                .shadow(radius: 2)
            Text("レイド：\(raid.bossName)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .background(.purple.opacity(0.8), in: Capsule())
        }
    }
}

/// プレイヤーのアイコン。足元の影と、ゆっくり広がる波紋で現在地を目立たせる
private struct PlayerMarkerView: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.25))
                .frame(width: 56, height: 56)
                .scaleEffect(isPulsing ? 1.2 : 0.7)
                .opacity(isPulsing ? 0 : 1)
                // 波紋だけを繰り返しアニメーションさせる（プレイヤーの移動には影響させない）
                .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)

            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white, .blue)
                .shadow(radius: 3)
        }
        .onAppear { isPulsing = true }
    }
}

#Preview {
    IndoorMapView(
        locations: Location.registered,
        monsterSpots: MonsterSpot.samples,
        raidSpots: RaidSpot.samples,
        currentLocation: Location.registered[0]
    )
        .padding()
}
