//
//  BattleMonsterComponent.swift
//  ARApp
//

import SwiftUI
import RealityKit

/// BattleMonsterComponent に流してほしいアニメーション
/// 作るたびに id が変わるので、同じアニメーション（続けてのパンチなど）でも毎回流せる
struct MonsterAnimationRequest {
    let id = UUID()
    let animation: MonsterAnimation
    /// true なら流し終わったあと、最後のポーズのまま止める（倒れたとき）
    var staysAtEnd = false
}

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
            for (position, intensity) in [(SIMD3<Float>(1.5, 2, 2), Float(3000)), ([-2, 1, 1.5], 1500), ([0, 2, -2], 1000)] {
                let light = DirectionalLight()
                light.light.intensity = intensity
                light.look(at: [0, 0.5, 0], from: position, relativeTo: nil)
                content.add(light)
            }

            let camera = PerspectiveCamera()
            camera.look(at: [0, 0.45, 0], from: [0, 0.6, 1.8], relativeTo: nil)
            content.add(camera)

            self.model = model
        }
        // 対戦ごとにモンスターが変わったら、作り直す
        .id(monster.modelName)
        .onChange(of: animation?.id) {
            guard let animation else { return }
            model?.monsterAnimator?.playOnce(animation.animation, staysAtEnd: animation.staysAtEnd)
        }
    }
}

#Preview {
    BattleMonsterComponent(monster: Monster.all[0], animation: nil, facing: 0.4)
        .frame(width: 240, height: 240)
}
