//
//  BattleARSceneController.swift
//  ARApp
//

import Foundation
import RealityKit
import UIKit
import Combine

/// バトル画面の ARView のシーンを操作する
/// 担当：床が見つかったら自分と相手のモンスターを置くこと、アニメーション（立っている間の動きも）を流すこと、
/// 攻撃したときに踏み込ませること、攻撃が当たったら受けた側を光らせて火花とダメージの数字を出すこと、
/// フィーバー中に自分のモンスターから金色の光を出すこと、相手の必殺技の予告で相手を赤く光らせること、勝ったときに金色の火花を散らすこと
final class BattleARSceneController {
    /// 光らせる、モデルの部品 1 つぶん。元のマテリアルと光らせたマテリアルを持っておき、入れ替える
    private struct FlashPart {
        let entity: Entity
        let original: [any Material]
        /// 攻撃が当たったとき（白）
        let lit: [any Material]
        /// 相手の必殺技の予告（赤）
        let warning: [any Material]
    }

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
    static let damageFontSize: CGFloat = 0.18
    static let feverDamageFontSize: CGFloat = 0.26
    static let specialDamageFontSize: CGFloat = 0.32
    static let finishingDamageFontSize: CGFloat = 0.42
    /// ダメージの数字が浮かび上がる高さ（m）と、消えるまでの時間（秒）
    static let damageRise: Float = 0.3
    static let damageDuration: TimeInterval = 0.8
    /// 連打しても数字が重なりすぎないよう、出す場所を左右と上にずらす幅（m）
    static let damageScatter: Float = 0.15
    /// ダメージの数字が出たときに、小さい大きさから弾んで大きくなるのにかける時間（秒）
    static let damagePopDuration: TimeInterval = 0.15
    /// 攻撃が当たったときに、受けた側が光っている時間（秒）と明るさ
    static let flashDuration: TimeInterval = 0.08
    static let finishingFlashDuration: TimeInterval = 0.25
    static let flashIntensity: Float = 1.2
    /// 火花の数。通常攻撃、フィーバー中の通常攻撃、必殺技、とどめ
    static let sparkCount = 40
    static let feverSparkCount = 90
    static let specialSparkCount = 150
    static let finishingSparkCount = 300
    /// フィーバー中と勝ったときの金色
    static let gold = UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1)
    /// 相手の必殺技の予告で、相手が赤く点滅する回数
    static let warningBlinkCount = 4
    /// 勝ったときに金色の火花を散らす回数と間隔（秒）
    static let victoryBurstCount = 4
    static let victoryBurstInterval: TimeInterval = 0.3
    /// 火花を出す場所。体の高さに掛ける割合と、体の中に隠れないよう攻撃した側へ出す距離（m）
    static let sparkHeightRatio: Float = 0.55
    static let sparkForwardOffset: Float = 0.15

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
    /// 最後に受け取ったアニメーション。モンスターを置く前に届いた分も、ここに残しておく
    private var myAnimation: MonsterAnimationRequest?
    private var opponentAnimation: MonsterAnimationRequest?
    private var hitOnOpponentID: UUID?
    private var hitOnMeID: UUID?
    private var dangerID: UUID?
    /// フィーバー中か。置く前に受け取った分は、置いたときに反映する
    private var isFeverActive = false
    private var isVictory = false
    /// 立っている間にくり返すアニメーション。置く前に受け取った分は、置いたときに流す
    private var myIdle = MonsterAnimation.idle
    private var opponentIdle = MonsterAnimation.idle
    /// 攻撃が当たったときに光らせる部品。モンスターを置いたときに作る
    private var myFlashParts: [FlashPart] = []
    private var opponentFlashParts: [FlashPart] = []
    /// 攻撃が当たったときに火花を出すエンティティ。当たるたびに作ると重くなるので、置いたときに 1 つずつ作って使い回す
    private var mySparks: Entity?
    private var opponentSparks: Entity?
    /// フィーバー中に自分のモンスターから立ちのぼる金色の光
    private var myAura: Entity?
    /// ダメージの数字の形。毎回作ると重いので、同じ数字と大きさなら使い回す
    private var damageMeshes: [String: MeshResource] = [:]

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
        hitOnMe: BattleViewModel.Hit?,
        danger: BattleViewModel.Danger?,
        isFeverActive: Bool,
        isVictory: Bool
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
            self.myAnimation = myAnimation
            myEntity?.monsterAnimator?.play(myAnimation)
        }
        if let opponentAnimation, opponentAnimation.id != opponentAnimationID {
            opponentAnimationID = opponentAnimation.id
            self.opponentAnimation = opponentAnimation
            opponentEntity?.monsterAnimator?.play(opponentAnimation)
        }
        if let hitOnOpponent, hitOnOpponent.id != hitOnOpponentID {
            hitOnOpponentID = hitOnOpponent.id
            lunge(myEntity, from: myHome, toward: opponentHome)
            let color: UIColor = if hitOnOpponent.isFinishing || hitOnOpponent.isFever {
                Self.gold
            } else if hitOnOpponent.isSpecial {
                .systemYellow
            } else {
                .systemOrange
            }
            showImpact(
                of: hitOnOpponent,
                attacker: myEntity,
                target: opponentEntity,
                flashing: opponentFlashParts,
                sparks: opponentSparks,
                above: opponentHome,
                height: opponentHeight,
                color: color
            )
        }
        if let hitOnMe, hitOnMe.id != hitOnMeID {
            hitOnMeID = hitOnMe.id
            lunge(opponentEntity, from: opponentHome, toward: myHome)
            showImpact(
                of: hitOnMe,
                attacker: opponentEntity,
                target: myEntity,
                flashing: myFlashParts,
                sparks: mySparks,
                above: myHome,
                height: myHeight,
                color: .systemPurple
            )
        }
        if let danger, danger.id != dangerID {
            dangerID = danger.id
            blinkWarning(opponentFlashParts)
        }
        if isFeverActive != self.isFeverActive {
            self.isFeverActive = isFeverActive
            setAura(isFeverActive)
        }
        if isVictory != self.isVictory {
            self.isVictory = isVictory
            if isVictory { celebrate() }
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
        myFlashParts = []
        opponentFlashParts = []
        mySparks = nil
        opponentSparks = nil
        myAura = nil
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
        myFlashParts = Self.flashParts(of: me)
        opponentFlashParts = Self.flashParts(of: opponent)
        mySparks = makeSparks(at: myHome, height: myHeight, facing: opponentHome)
        opponentSparks = makeSparks(at: opponentHome, height: opponentHeight, facing: myHome)
        myAura = makeAura(at: myHome, height: myHeight)
        setAura(isFeverActive)
        me.monsterAnimator?.changeLoop(to: myIdle)
        opponent.monsterAnimator?.changeLoop(to: opponentIdle)
        // 置く前に、最後に残る動き（倒れたまま、喜び続ける）が届いていたら流す
        // 床が見つかる前に決着したときや、対戦中にタブを切り替えて戻ってきたときに、立った姿にならないようにする
        // のけぞりなど 1 回で終わる動きは、もう終わっているはずなので流さない
        for (entity, animation) in [(me, myAnimation), (opponent, opponentAnimation)] {
            guard var animation, animation.ending != .backToLoop else { continue }
            animation.delay = 0
            entity.monsterAnimator?.play(animation)
        }
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

    /// 攻撃が当たるタイミングで、受けた側を一瞬光らせ、火花を散らし、頭の上にダメージの数字を出す
    /// とどめのときは、2 体とも少しの間止めて（ヒットストップ）、光る時間を延ばし、火花を増やす
    private func showImpact(
        of hit: BattleViewModel.Hit,
        attacker: Entity?,
        target: Entity?,
        flashing parts: [FlashPart],
        sparks: Entity?,
        above home: Transform,
        height: Float,
        color: UIColor
    ) {
        // モンスターを置く前に当たった攻撃は、何も出さない
        guard let sparks else { return }
        Task {
            try? await Task.sleep(for: .seconds(hit.impactDelay))
            // 待っている間に AR の画面が閉じられていたら出さない
            guard floorAnchor != nil else { return }
            if hit.isFinishing {
                attacker?.monsterAnimator?.freeze(for: BattleViewModel.Hit.hitStopDuration)
                target?.monsterAnimator?.freeze(for: BattleViewModel.Hit.hitStopDuration)
            }
            flash(parts, duration: hit.isFinishing ? Self.finishingFlashDuration : Self.flashDuration)
            let count = if hit.isFinishing {
                Self.finishingSparkCount
            } else if hit.isSpecial {
                Self.specialSparkCount
            } else if hit.isFever {
                Self.feverSparkCount
            } else {
                Self.sparkCount
            }
            burstSparks(sparks, color: color, count: count)
            showDamage(of: hit, above: home, height: height, color: color)
        }
    }

    /// モンスターを一瞬白く光らせてから、元の色に戻す
    private func flash(_ parts: [FlashPart], duration: TimeInterval) {
        for part in parts {
            part.entity.components[ModelComponent.self]?.materials = part.lit
        }
        Task {
            try? await Task.sleep(for: .seconds(duration))
            for part in parts {
                part.entity.components[ModelComponent.self]?.materials = part.original
            }
        }
    }

    /// 相手の必殺技の予告の間、相手を赤く点滅させる
    private func blinkWarning(_ parts: [FlashPart]) {
        let interval = BattleViewModel.dangerDuration / Double(Self.warningBlinkCount * 2)
        Task {
            for _ in 0..<Self.warningBlinkCount {
                for part in parts {
                    part.entity.components[ModelComponent.self]?.materials = part.warning
                }
                try? await Task.sleep(for: .seconds(interval))
                for part in parts {
                    part.entity.components[ModelComponent.self]?.materials = part.original
                }
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    /// 光らせる部品を集める。モデルは形を持つエンティティ（ModelComponent があるもの）が子に分かれているので、たどって全部集める
    private static func flashParts(of entity: Entity) -> [FlashPart] {
        var parts: [FlashPart] = []
        if let model = entity.components[ModelComponent.self] {
            parts.append(FlashPart(
                entity: entity,
                original: model.materials,
                lit: model.materials.map { litMaterial(from: $0, color: .white) },
                warning: model.materials.map { litMaterial(from: $0, color: .systemRed) }
            ))
        }
        return parts + entity.children.flatMap(flashParts)
    }

    /// 元の色を残したまま、color の色で自分で光っているように明るくしたマテリアル
    private static func litMaterial(from material: any Material, color: UIColor) -> any Material {
        guard var lit = material as? PhysicallyBasedMaterial else {
            // ほかの種類のマテリアルは明るさだけを変えられないので、その色で塗りつぶす
            return UnlitMaterial(color: color)
        }
        lit.emissiveColor = .init(color: color)
        lit.emissiveIntensity = flashIntensity
        return lit
    }

    /// 攻撃が当たったときに火花を出すエンティティを、受ける側の胸のあたりに置く。当たるまでは何も出さない
    private func makeSparks(at home: Transform, height: Float, facing attacker: Transform) -> Entity {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.03, 0.03, 0.03]
        // 真ん中から外へ向かって飛び散らせる
        emitter.birthLocation = .surface
        emitter.birthDirection = .normal
        emitter.speedVariation = 0.6
        // burst() を呼んだときだけ出す
        emitter.isEmitting = false
        emitter.mainEmitter.birthRate = 0
        emitter.mainEmitter.lifeSpan = 0.25
        emitter.mainEmitter.lifeSpanVariation = 0.1
        emitter.mainEmitter.size = 0.02
        emitter.mainEmitter.sizeVariation = 0.01
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.1
        // 勢いよく飛び出して、すぐに止まる
        emitter.mainEmitter.dampingFactor = 6
        // 飛ぶ向きに伸ばして、線のような火花にする
        emitter.mainEmitter.stretchFactor = 4
        emitter.mainEmitter.opacityCurve = .linearFadeOut
        // 周りの明るさに関係なく光って見えるよう、光の影響を受けず、重ねるほど明るくなるようにする
        emitter.mainEmitter.isLightingEnabled = false
        emitter.mainEmitter.blendMode = .additive

        let sparks = Entity()
        sparks.components.set(emitter)
        // 体の中で出すと隠れてしまうので、攻撃した側に少し出す
        var forward = attacker.translation - home.translation
        forward.y = 0
        sparks.position = home.translation + [0, height * Self.sparkHeightRatio, 0] + simd_normalize(forward) * Self.sparkForwardOffset
        floorAnchor?.addChild(sparks)
        return sparks
    }

    /// 火花を一度に散らす。数が多いほど遠くまで飛ばす
    private func burstSparks(_ sparks: Entity, color: UIColor, count: Int) {
        guard var emitter = sparks.components[ParticleEmitterComponent.self] else { return }
        // 白く光ってから、攻撃の色に変わりながら消える
        emitter.mainEmitter.color = .evolving(start: .single(.white), end: .single(color))
        emitter.burstCount = count
        emitter.burstCountVariation = count / 4
        emitter.speed = count > Self.sparkCount ? 2.2 : 1.4
        emitter.burst()
        sparks.components.set(emitter)
    }

    /// フィーバー中に、自分のモンスターの周りから立ちのぼる金色の光を作る。setAura(_:) で出したり止めたりする
    private func makeAura(at home: Transform, height: Float) -> Entity {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .cylinder
        emitter.emitterShapeSize = [height * 0.6, height * 0.2, height * 0.6]
        emitter.birthLocation = .surface
        emitter.emissionDirection = [0, 1, 0]
        emitter.speed = 0.4
        emitter.speedVariation = 0.2
        emitter.isEmitting = false
        emitter.mainEmitter.birthRate = 120
        emitter.mainEmitter.lifeSpan = 0.8
        emitter.mainEmitter.lifeSpanVariation = 0.3
        emitter.mainEmitter.size = 0.015
        emitter.mainEmitter.sizeVariation = 0.008
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.2
        emitter.mainEmitter.opacityCurve = .gradualFadeInOut
        emitter.mainEmitter.color = .evolving(start: .single(.white), end: .single(Self.gold))
        emitter.mainEmitter.isLightingEnabled = false
        emitter.mainEmitter.blendMode = .additive

        let aura = Entity()
        aura.components.set(emitter)
        aura.position = home.translation + [0, height * 0.1, 0]
        floorAnchor?.addChild(aura)
        return aura
    }

    private func setAura(_ isOn: Bool) {
        guard let myAura, var emitter = myAura.components[ParticleEmitterComponent.self] else { return }
        emitter.isEmitting = isOn
        myAura.components.set(emitter)
    }

    /// 勝ったときに、自分のモンスターから金色の火花を何度か散らす
    private func celebrate() {
        guard let mySparks else { return }
        Task {
            for _ in 0..<Self.victoryBurstCount {
                guard floorAnchor != nil else { return }
                burstSparks(mySparks, color: Self.gold, count: Self.specialSparkCount)
                try? await Task.sleep(for: .seconds(Self.victoryBurstInterval))
            }
        }
    }

    /// 受けた側の頭の上にダメージの数字を出す。弾むように大きくなってから、浮かび上がりながら消える
    private func showDamage(of hit: BattleViewModel.Hit, above home: Transform, height: Float, color: UIColor) {
        guard let floorAnchor else { return }

        let fontSize = if hit.isFinishing {
            Self.finishingDamageFontSize
        } else if hit.isSpecial {
            Self.specialDamageFontSize
        } else if hit.isFever {
            Self.feverDamageFontSize
        } else {
            Self.damageFontSize
        }
        let label = "-\(hit.damage)"
        let meshKey = "\(label)@\(fontSize)"
        let mesh = damageMeshes[meshKey] ?? MeshResource.generateText(
            label, extrusionDepth: 0.01, font: UIFont.systemFont(ofSize: fontSize, weight: .heavy)
        )
        damageMeshes[meshKey] = mesh
        // 周りの明るさに関係なく、はっきりした色で見せる
        let text = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: color)])
        // 文字は左下が原点なので、真ん中が原点に来るようにずらす
        // 連打で数字が重ならないよう、毎回少し左右と上にずらす（カメラの方を向く親の中なので、画面の上でのずれになる）
        let scatter = Self.damageScatter
        text.position = -mesh.bounds.center + [Float.random(in: -scatter...scatter), Float.random(in: 0...scatter), 0]

        // 弾む動きを、浮かび上がる動きと別に付けられるよう、間に 1 つ挟む
        let pop = Entity()
        pop.addChild(text)

        // 親に BillboardComponent を付けて、いつもカメラの方を向くようにする
        let popup = Entity()
        popup.components.set(BillboardComponent())
        popup.components.set(OpacityComponent())
        popup.addChild(pop)
        popup.position = home.translation + [0, height + 0.15, 0]
        floorAnchor.addChild(popup)

        // 小さい大きさから、少し大きくなりすぎてから戻る（弾む）
        var small = pop.transform
        small.scale = .init(repeating: 0.3)
        let popAnimation = FromToByAnimation(
            from: small,
            to: pop.transform,
            duration: Self.damagePopDuration,
            timing: .cubicBezier(controlPoint1: [0.3, 1.8], controlPoint2: [0.6, 1]),
            bindTarget: .transform
        )
        if let animation = try? AnimationResource.generate(with: popAnimation) {
            pop.playAnimation(animation)
        }

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
        Task {
            try? await Task.sleep(for: .seconds(Self.damageDuration))
            popup.removeFromParent()
        }
    }
}
