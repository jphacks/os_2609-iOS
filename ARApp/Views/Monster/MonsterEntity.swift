//
//  MonsterEntity.swift
//  ARApp
//

import RealityKit

/// モンスターの 3D の見た目を作る（捕獲画面とバトル画面で共通）
/// 担当：見た目だけ。配置する場所やタイミングは、使う画面（ARSceneController など）が決める
enum MonsterEntity {
    /// 独自のコンポーネントは、使う前に 1 回だけ RealityKit に登録する
    private static let registerComponents: Void = MonsterAnimatorComponent.registerComponent()

    /// モンスターの 3D モデル（USDZ）を読み込み、高さを合わせて、立っているアニメーションを流す
    /// アニメーションを切り替えるときは、返したエンティティの `monsterAnimator` を使う
    /// height を省略すると `monster.size` の高さ（現実の大きさ）になる
    /// ファイルの読み込みには時間がかかるので async になっている
    static func make(from monster: Monster, height: Float? = nil) async -> Entity {
        _ = registerComponents
        do {
            let model = try await Entity(named: monster.modelName)

            // モデルは 3〜4m の大きさで作られているので、指定の高さになるように縮小する
            // 腕を横に広げた姿勢で作られていて横幅の方が大きいので、一番長い辺ではなく高さで合わせる
            // 原点は足元にあるので、そのまま床の上に乗る
            let modelHeight = model.visualBounds(relativeTo: nil).extents.y
            if modelHeight > 0 {
                model.scale = .init(repeating: (height ?? monster.size) / modelHeight)
            }

            let animator = MonsterAnimator(model: model)
            model.components.set(MonsterAnimatorComponent(animator: animator))
            // アニメーションを流さないと、腕を広げた姿勢のまま固まって見える
            animator.loop(.idle)

            // 足元に影を落として、床の上に立っているように見せる（影がないと宙に浮いて見える）
            addGroundingShadow(to: model)
            return model
        } catch {
            // 【開発用】原因を調べるためのログ。リリースするときに消してよい
            print("モデル \(monster.modelName) を読み込めませんでした: \(error)")
            // 読み込めなかったときは何も表示しない
            return Entity()
        }
    }

    /// 影は形を持つエンティティ（ModelComponent があるもの）ごとに付ける必要があるので、子をたどって全部に付ける
    private static func addGroundingShadow(to entity: Entity) {
        if entity.components.has(ModelComponent.self) {
            entity.components.set(GroundingShadowComponent(castsShadow: true))
        }
        entity.children.forEach(addGroundingShadow)
    }
}
