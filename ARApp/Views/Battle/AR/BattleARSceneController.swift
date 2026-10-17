//
//  BattleARSceneController.swift
//  ARApp
//

import Foundation
import RealityKit
import UIKit
import Combine

/// バトル画面の ARView のシーンを操作する
/// 担当：床が見つかったら自分と相手のモンスターを置くこと、アニメーションを流すこと、
/// 攻撃したときに踏み込ませること、攻撃が当たったらダメージの数字を出すこと
final class BattleARSceneController {
    /// モンスターの大きさ。現実の大きさ（Monster.size）に掛ける
    /// 現実の大きさのままだと、手前の自分のモンスターが画面からはみ出すので小さくする
    static let sizeScale: Float = 0.5
    /// 床が見つかったときのカメラから見た、自分のモンスターまでの距離（m）
    static let myDistance: Float = 1.2
    /// 相手のモンスターまでの距離（m）
    static let opponentDistance: Float = 2.8
    /// 正面から左右にずらす距離（m）。自分は左、相手は右に置き、斜めに向かい合わせる
    static let sideOffset: Float = 0.35
    /// 攻撃するときに相手の方へ踏み込む距離（m）と、踏み込むのにかける時間（秒）
    static let lungeDistance: Float = 0.25
    static let lungeDuration: TimeInterval = 0.12
    /// ダメージの数字の文字の高さ（m）。通常攻撃と必殺技
    static let damageFontSize: CGFloat = 0.15
    static let specialDamageFontSize: CGFloat = 0.25
    /// ダメージの数字が浮かび上がる高さ（m）と、消えるまでの時間（秒）
    static let damageRise: Float = 0.3
    static let damageDuration: TimeInterval = 0.8

    private let myMonster: Monster
    private let opponentMonster: Monster
    /// 2 体とも床に置き終わったときに呼ぶ
    private let onPlaced: () -> Void
    private weak var arView: ARView?
    private var floorAnchor: AnchorEntity?
    /// アンカーの配置状態の購読。保持していないとすぐに解除される
    private var anchoredSubscription: Cancellable?
    private var placeTask: Task<Void, Never>?
    private var myEntity: Entity?
    private var opponentEntity: Entity?
    /// 置いた場所と向き（床のアンカーから見た値）。踏み込んだあとはここに戻る
    /// 踏み込んでいる途中の場所から次の踏み込みを始めると、少しずつずれていくため、置いたときの値を持っておく
    private var myHome = Transform.identity
    private var opponentHome = Transform.identity
    /// 最後に受け取ったアニメーションと攻撃の id。変わったときだけ流す
    private var myAnimationID: UUID?
    private var opponentAnimationID: UUID?
    private var hitOnOpponentID: UUID?
    private var hitOnMeID: UUID?
    /// 立っている間にくり返すアニメーション。置く前に受け取った分は、置いたときに流す
    private var myIdle = MonsterAnimation.idle
    private var opponentIdle = MonsterAnimation.idle

    /// 床に置いたときのモンスターの高さ（m）。ダメージの数字を頭の上に出すのに使う
    private var myHeight: Float { myMonster.size * Self.sizeScale }
    private var opponentHeight: Float { opponentMonster.size * Self.sizeScale }

    init(myMonster: Monster, opponentMonster: Monster, onPlaced: @escaping () -> Void) {
        self.myMonster = myMonster
        self.opponentMonster = opponentMonster
        self.onPlaced = onPlaced
    }

    func start(in arView: ARView) {
        self.arView = arView

        // 20cm 四方以上の床が見つかったら、そこに自動で固定されるアンカー（捕獲画面と同じ）
        let anchor = AnchorEntity(.plane(.horizontal, classification: .floor, minimumBounds: [0.2, 0.2]))
        // 固定のイベントを取りこぼさないよう、シーンに置く前に購読しておく
        anchoredSubscription = arView.scene.subscribe(
            to: SceneEvents.AnchoredStateChanged.self,
            on: anchor
        ) { [weak self] event in
            guard let self, event.isAnchored, self.placeTask == nil else { return }
            self.placeTask = Task { await self.placeMonsters() }
        }
        arView.scene.addAnchor(anchor)
        floorAnchor = anchor
    }

    /// SwiftUI の状態に合わせて、アニメーションを流したり踏み込ませたりする
    /// id が前と同じなら何もしない（updateUIView は、関係のない状態が変わったときも呼ばれるため）
    func update(
        myIdle: MonsterAnimation,
        opponentIdle: MonsterAnimation,
        myAnimation: MonsterAnimationRequest?,
        opponentAnimation: MonsterAnimationRequest?,
        hitOnOpponent: BattleViewModel.Hit?,
        hitOnMe: BattleViewModel.Hit?
    ) {
        if myIdle != self.myIdle {
            self.myIdle = myIdle
            myEntity?.monsterAnimator?.changeLoop(to: myIdle)
        }
        if opponentIdle != self.opponentIdle {
            self.opponentIdle = opponentIdle
            opponentEntity?.monsterAnimator?.changeLoop(to: opponentIdle)
        }
        if let myAnimation, myAnimation.id != myAnimationID {
            myAnimationID = myAnimation.id
            myEntity?.monsterAnimator?.play(myAnimation)
        }
        if let opponentAnimation, opponentAnimation.id != opponentAnimationID {
            opponentAnimationID = opponentAnimation.id
            opponentEntity?.monsterAnimator?.play(opponentAnimation)
        }
        if let hitOnOpponent, hitOnOpponent.id != hitOnOpponentID {
            hitOnOpponentID = hitOnOpponent.id
            lunge(myEntity, from: myHome, toward: opponentHome)
            showDamage(of: hitOnOpponent, above: opponentHome, height: opponentHeight, color: hitOnOpponent.isSpecial ? .systemYellow : .systemRed)
        }
        if let hitOnMe, hitOnMe.id != hitOnMeID {
            hitOnMeID = hitOnMe.id
            lunge(opponentEntity, from: opponentHome, toward: myHome)
            showDamage(of: hitOnMe, above: myHome, height: myHeight, color: .systemPurple)
        }
    }

    func stop() {
        placeTask?.cancel()
        placeTask = nil
        anchoredSubscription?.cancel()
        anchoredSubscription = nil
        floorAnchor = nil
        myEntity = nil
        opponentEntity = nil
    }

    /// カメラの前の床に、自分のモンスターを手前、相手のモンスターを奥に置き、向かい合わせる
    private func placeMonsters() async {
        // モデルの読み込みは時間がかかるので、読み込み終わってから床に置く
        let me = await MonsterEntity.make(from: myMonster, height: myHeight)
        let opponent = await MonsterEntity.make(from: opponentMonster, height: opponentHeight)
        guard let arView, let floorAnchor, !Task.isCancelled else { return }

        // 置く場所は、置くときのカメラの位置と向きで決める（床のアンカーの場所は、カメラの前とは限らない）
        // カメラは -Z 方向を向いているので、その向きを床と平行にしたものを「前」にする
        let camera = arView.cameraTransform.matrix
        var forward = SIMD2(-camera.columns.2.x, -camera.columns.2.z)
        // 真下を向いていると前がわからないので、そのときはワールドの -Z を前にする
        forward = simd_length(forward) > 0.1 ? simd_normalize(forward) : [0, -1]
        let right = SIMD2(-forward.y, forward.x)
        let cameraPosition = SIMD2(camera.columns.3.x, camera.columns.3.z)
        let myPosition = cameraPosition + forward * Self.myDistance - right * Self.sideOffset
        let opponentPosition = cameraPosition + forward * Self.opponentDistance + right * Self.sideOffset

        let floorY = floorAnchor.position(relativeTo: nil).y
        for (entity, position, target) in [(me, myPosition, opponentPosition), (opponent, opponentPosition, myPosition)] {
            floorAnchor.addChild(entity)
            entity.setPosition([position.x, floorY, position.y], relativeTo: nil)
            // モデルは +Z 方向が正面なので、+Z が相手の方を向くように Y 軸で回す
            let direction = target - position
            entity.setOrientation(simd_quatf(angle: atan2(direction.x, direction.y), axis: [0, 1, 0]), relativeTo: nil)
        }
        myEntity = me
        opponentEntity = opponent
        myHome = me.transform
        opponentHome = opponent.transform
        me.monsterAnimator?.changeLoop(to: myIdle)
        opponent.monsterAnimator?.changeLoop(to: opponentIdle)
        onPlaced()
    }

    /// 相手の方へ少し踏み込んで、元の場所に戻る（攻撃する演出）
    private func lunge(_ entity: Entity?, from home: Transform, toward target: Transform) {
        guard let entity else { return }
        // 2 体とも床のアンカーの子なので、アンカーから見た位置で計算する
        var stepped = home
        stepped.translation += simd_normalize(target.translation - home.translation) * Self.lungeDistance
        entity.move(to: stepped, relativeTo: entity.parent, duration: Self.lungeDuration, timingFunction: .easeOut)
        Task {
            try? await Task.sleep(for: .seconds(Self.lungeDuration))
            entity.move(to: home, relativeTo: entity.parent, duration: Self.lungeDuration * 2, timingFunction: .easeInOut)
        }
    }

    /// 攻撃が当たるタイミングで、受けた側の頭の上にダメージの数字を出す。浮かび上がりながら消える
    private func showDamage(of hit: BattleViewModel.Hit, above home: Transform, height: Float, color: UIColor) {
        // モンスターを置く前に当たった攻撃は、数字を出さない
        guard myEntity != nil else { return }
        Task {
            try? await Task.sleep(for: .seconds(hit.impactDelay))
            guard let floorAnchor else { return }

            let font = UIFont.systemFont(ofSize: hit.isSpecial ? Self.specialDamageFontSize : Self.damageFontSize, weight: .heavy)
            let mesh = MeshResource.generateText("-\(hit.damage)", extrusionDepth: 0.01, font: font)
            // 周りの明るさに関係なく、はっきりした色で見せる
            let text = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: color)])
            // 文字は左下が原点なので、真ん中が原点に来るようにずらす
            text.position = -mesh.bounds.center

            // 親に BillboardComponent を付けて、いつもカメラの方を向くようにする
            let popup = Entity()
            popup.components.set(BillboardComponent())
            popup.components.set(OpacityComponent())
            popup.addChild(text)
            popup.position = home.translation + [0, height + 0.15, 0]
            floorAnchor.addChild(popup)

            // 上に浮かびながら、透明になって消える
            var risen = popup.transform
            risen.translation.y += Self.damageRise
            let rise = FromToByAnimation(
                from: popup.transform, to: risen, duration: Self.damageDuration, timing: .easeOut, bindTarget: .transform
            )
            let fade = FromToByAnimation<Float>(
                from: 1, to: 0, duration: Self.damageDuration, timing: .easeIn, bindTarget: .opacity
            )
            if let animation = try? AnimationResource.group(with: [
                AnimationResource.generate(with: rise),
                AnimationResource.generate(with: fade),
            ]) {
                popup.playAnimation(animation)
            }
            try? await Task.sleep(for: .seconds(Self.damageDuration))
            popup.removeFromParent()
        }
    }
}
