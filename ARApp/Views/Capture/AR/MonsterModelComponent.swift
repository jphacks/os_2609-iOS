//
//  MonsterModelComponent.swift
//  ARApp
//

import SwiftUI
import RealityKit

/// モンスターの 3D モデルを、カメラ映像なしで表示する。指で左右にドラッグするとモデルが回る
/// RealityKit を使うので AR/ に置いている
///
/// カメラを動かして回す（realityViewCameraControls(.orbit)）と、RealityKit がカメラの動きにモーションブラーをかけて残像が出る
/// RealityView にはモーションブラーを切る設定がないので、カメラは止めたまま、モデルのほうを回している
struct MonsterModelComponent: View {
    let monster: Monster

    /// 指で回した角度（縦の軸まわり）
    @State private var angle = Angle.zero
    /// ドラッグを始めたときの角度。ドラッグ中はここに指の移動量を足す
    @State private var angleAtDragStart = Angle.zero

    /// 指を 1pt 動かしたときに回る角度
    private static let degreesPerPoint = 0.5
    private static let turntableName = "turntable"

    var body: some View {
        RealityView { content in
            // カメラ映像を使わず、3D の空間だけを映す
            content.camera = .virtual

            let model = await MonsterEntity.make(from: monster)
            // 原点は足元にあるので、体の真ん中が画面の中心に来るように下げる
            model.position.y = -monster.size / 2

            // 回すための台に乗せる。モデル自体の向きはアニメーションに任せ、台のほうを回す
            let turntable = Entity()
            turntable.name = Self.turntableName
            turntable.addChild(model)
            content.add(turntable)

            // 一番大きいモンスター（高さ 1.8m）でも画面に収まる距離から見る
            let camera = PerspectiveCamera()
            camera.position = [0, 0, 3]
            content.add(camera)
        } update: { content in
            let turntable = content.entities.first { $0.name == Self.turntableName }
            turntable?.orientation = simd_quatf(angle: Float(angle.radians), axis: [0, 1, 0])
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    angle = angleAtDragStart + .degrees(value.translation.width * Self.degreesPerPoint)
                }
                .onEnded { _ in
                    angleAtDragStart = angle
                }
        )
    }
}
