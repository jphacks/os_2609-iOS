//
//  MonsterAnimation.swift
//  ARApp
//

import RealityKit

/// モンスターのモデルに入っているアニメーション
/// USDZ にはアニメーションが 1 本の流れとして並んで入っているので、使う区間を切り出して流す
/// 区間は scripts/convert_monster_models.py が書き出したもので、全モンスターで同じ（単位は秒）
///
///   Death 0.0000–0.7917 / Duck 0.8333–2.5000 / HitReact 2.5417–3.1667 / Idle 3.2083–4.2083
///   Jump 4.2500–4.6250 / Jump_Idle 4.6667–5.1667 / Jump_Land 5.2083–5.5833 / No 5.6250–7.2917
///   Punch 7.3333–8.2083 / Run 8.2500–8.8333 / Walk 8.8750–9.8750 / Wave 9.9167–11.5833
///   Weapon 11.6250–12.5000 / Yes 12.5417–14.2083
///
/// 新しく使うときは、上の表から区間を写して case を足す
enum MonsterAnimation {
    /// 立ったまま体を揺らす
    case idle

    private var timeRange: ClosedRange<Double> {
        switch self {
        case .idle: 3.2083...4.2083
        }
    }

    /// モデルでこのアニメーションをくり返し流す。モデルにアニメーションが入っていなければ何もしない
    func playRepeating(on model: Entity) {
        guard let animation = model.availableAnimations.first else { return }
        var definition = animation.definition
        definition.trimStart = timeRange.lowerBound
        definition.trimEnd = timeRange.upperBound
        definition.repeatMode = .repeat
        guard let clip = try? AnimationResource.generate(with: definition) else { return }
        model.playAnimation(clip)
    }
}
