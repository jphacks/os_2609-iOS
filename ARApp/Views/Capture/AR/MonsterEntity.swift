//
//  MonsterEntity.swift
//  ARApp
//

import RealityKit

/// モンスターの 3D の見た目を作る
/// 担当：見た目だけ。配置する場所やタイミングは ARSceneController が決める
enum MonsterEntity {
    /// モンスターの 3D モデル（USDZ）を読み込み、`monster.size` の大きさに合わせる
    /// ファイルの読み込みには時間がかかるので async になっている
    static func make(from monster: Monster) async -> Entity {
        do {
            let model = try await Entity(named: monster.modelName)

            // モデルは 3〜4m の大きさで作られているので、高さが size になるように縮小する
            // 腕を横に広げた姿勢で作られていて横幅の方が大きいので、一番長い辺ではなく高さで合わせる
            // 原点は足元にあるので、そのまま床の上に乗る
            let height = model.visualBounds(relativeTo: nil).extents.y
            if height > 0 {
                model.scale = .init(repeating: monster.size / height)
            }
            return model
        } catch {
            // 【開発用】原因を調べるためのログ。リリースするときに消してよい
            print("モデル \(monster.modelName) を読み込めませんでした: \(error)")
            // 開発用の球体。PlaceholderMonsterEntity.swift を消すときは `return Entity()` に置き換える
            return PlaceholderMonsterEntity.make(size: monster.size)
        }
    }
}
