//
//  BattleMonsterComponent.swift
//  ARApp
//

import SwiftUI
import RealityKit

/// バトル画面に、3D のモンスターを 1 体表示する（カメラ映像は使わない、普通の 3D 表示）
/// 立っているアニメーションをくり返し、animation が変わるたびにそのアニメーションを 1 回流す
struct BattleMonsterComponent: View {
    let monster: Monster
    let animation: MonsterAnimationRequest?
    /// モンスターの向き（Y 軸まわりの角度、ラジアン）。0 で正面（カメラの方）、正の値でカメラから見て右を向く
    let facing: Float

    @State private var model: Entity?

    var body: some View {
        RealityView { content in
            content.camera = .virtual

            // 画面の中で同じ大きさに見えるよう、どのモンスターも高さ 1 にそろえる
            let model = await MonsterEntity.make(from: monster, height: 1)
            model.orientation = simd_quatf(angle: facing, axis: [0, 1, 0])
            content.add(model)

            // カメラ映像がないので、部屋の光の代わりに前・横・後ろから照らす
            // 自分のモンスターは後ろ姿を見せるので、後ろからも前と同じくらい明るくする
            for (position, intensity) in [(SIMD3<Float>(1.5, 2, 2), Float(3000)), ([-2, 1, 1.5], 1500), ([0, 2, -2], 2500)] {
                let light = DirectionalLight()
                light.light.intensity = intensity
                light.look(at: [0, 0.5, 0], from: position, relativeTo: nil)
                content.add(light)
            }

            // 跳んだり武器を振ったりしてもはみ出さない範囲で、なるべく大きく映す
            let camera = PerspectiveCamera()
            camera.look(at: [0, 0.5, 0], from: [0, 0.65, 1.45], relativeTo: nil)
            content.add(camera)

            self.model = model
        }
        // 対戦ごとにモンスターが変わったら、作り直す
        .id(monster.modelName)
        .onChange(of: animation?.id) {
            guard let animation else { return }
            model?.monsterAnimator?.play(animation)
        }
    }
}

#Preview {
    BattleMonsterComponent(monster: Monster.all[0], animation: nil, facing: 0.4)
        .frame(width: 240, height: 240)
}
