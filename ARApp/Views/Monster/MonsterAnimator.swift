//
//  MonsterAnimator.swift
//  ARApp
//

import Foundation
import RealityKit

/// モンスターのアニメーションを切り替える
/// MonsterEntity.make で作ったモンスターには付いているので、どの画面からでも次のように使える
///
///     model.monsterAnimator?.loop(.walk)       // くり返し流す（歩く、立っているなど）
///     model.monsterAnimator?.playOnce(.punch)  // 1 回だけ流して、くり返していたアニメーションに戻る
///     model.monsterAnimator?.playOnce(.death, staysAtEnd: true)  // 最後のポーズのまま止まる
///     model.monsterAnimator?.play(request)     // MonsterAnimationRequest のとおりに流す（待ってから、続けて流すなど）
///
/// 切り替えるときは前のアニメーションと少しの間混ぜて、ポーズが急に飛ばないようにする
final class MonsterAnimator {
    private weak var model: Entity?
    /// モデルに入っている、14 種類が 1 本につながったアニメーション。入っていないモデルでは nil で、何も流さない
    private let source: AnimationResource?
    /// くり返し流しているアニメーション。1 回だけ流すアニメーションが終わったら、これに戻る
    private var looping = MonsterAnimation.idle
    private var returnTask: Task<Void, Never>?
    /// play(_:) で、流し始めるのを待っているタスク
    private var requestTask: Task<Void, Never>?

    init(model: Entity) {
        self.model = model
        source = model.availableAnimations.first
    }

    /// MonsterAnimationRequest のとおりにアニメーションを流す
    /// 流している途中で次の play(_:) が呼ばれたら、前の分の残りは流さない
    func play(_ request: MonsterAnimationRequest) {
        requestTask?.cancel()
        requestTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(request.delay))
                // 途中のアニメーションは終わりのポーズで止めておき、混ぜ始める時間になったら次を流す
                for animation in request.animations.dropLast() {
                    self?.playOnce(animation, staysAtEnd: true)
                    try await Task.sleep(for: .seconds(animation.duration - MonsterAnimation.transitionDuration))
                }
            } catch {
                return
            }
            guard let self, let last = request.animations.last else { return }
            switch request.ending {
            case .backToLoop: playOnce(last)
            case .staysAtEnd: playOnce(last, staysAtEnd: true)
            case .repeats: loop(last)
            }
        }
    }

    /// アニメーションをくり返し流す
    func loop(_ animation: MonsterAnimation) {
        looping = animation
        returnTask?.cancel()
        returnTask = nil
        play(animation, repeats: true)
    }

    /// アニメーションを 1 回だけ流す。終わったら、くり返していたアニメーションに戻る
    /// staysAtEnd を true にすると、戻らずに最後のポーズのまま止まる（倒れる Death など）
    func playOnce(_ animation: MonsterAnimation, staysAtEnd: Bool = false) {
        returnTask?.cancel()
        returnTask = nil
        play(animation, repeats: false)
        guard !staysAtEnd else { return }
        returnTask = Task { [weak self] in
            // 戻るときも混ぜるので、その時間だけ早めに切り替え始める
            try? await Task.sleep(for: .seconds(animation.duration - MonsterAnimation.transitionDuration))
            guard let self, !Task.isCancelled else { return }
            self.play(self.looping, repeats: true)
        }
    }

    private func play(_ animation: MonsterAnimation, repeats: Bool) {
        guard let model, let source else { return }
        var definition = source.definition
        definition.trimStart = animation.timeRange.lowerBound
        definition.trimEnd = animation.timeRange.upperBound
        definition.repeatMode = repeats ? .repeat : .none
        // 1 回だけ流すときは、終わったあと最後のポーズを保つ
        definition.fillMode = .forwards
        guard let clip = try? AnimationResource.generate(with: definition) else { return }
        model.playAnimation(clip, transitionDuration: MonsterAnimation.transitionDuration)
    }
}

/// エンティティに MonsterAnimator を持たせるためのコンポーネント（RealityKit の Component）
/// MonsterEntity.make が付ける
struct MonsterAnimatorComponent: Component {
    let animator: MonsterAnimator
}

extension Entity {
    /// MonsterEntity.make で作ったモンスターなら、アニメーションを切り替える MonsterAnimator
    var monsterAnimator: MonsterAnimator? {
        components[MonsterAnimatorComponent.self]?.animator
    }
}
