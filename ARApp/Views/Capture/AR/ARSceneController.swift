//
//  ARSceneController.swift
//  ARApp
//

import RealityKit
import UIKit
import Combine

/// ARView のシーンを操作する
/// 担当：アンカーやエンティティの配置、モンスターを歩かせること、歩いた距離やタップなどシーンのイベントを ViewModel に伝えること
/// タップを受け取る `#selector` を使うため、NSObject を継承している
final class ARSceneController: NSObject {
    /// モンスターが出現する、自分からの距離（m）。少し歩かないと届かない距離にする
    static let spawnDistanceRange: ClosedRange<Float> = 1.5...3
    /// モンスターが出現する方向の、カメラの正面からのずれの最大（ラジアン）。出たことに気づけるよう、前の方に出す
    static let spawnAngleRange: Float = .pi / 4
    /// これだけ動いたら歩いたとみなす距離（m）
    /// その場で端末を動かしただけのぶれや、位置の追跡の小さな揺れを、歩いた距離に数えないようにする
    static let walkStep: Float = 0.3
    /// 出現した場所を中心に歩き回る範囲の半径（m）
    static let wanderRadius: Float = 1.5
    /// 1 回に歩く距離（m）
    static let stepRange: ClosedRange<Float> = 0.6...1.4
    /// 歩く速さ。モンスターの高さ 1m あたりの速さ（m/秒）
    /// 大きいモンスターほど歩幅が広いので、同じ歩くアニメーションでも速く進ませる（高さ 1.5m なら 0.6m/秒）
    static let walkSpeedPerHeight: Float = 0.4
    /// 向きを変えるのにかける時間（秒）
    static let turnDuration: TimeInterval = 0.4
    /// 歩き終わってから次に歩き出すまで止まっている時間（秒）
    static let restRange: ClosedRange<Double> = 0.5...2
    /// 捕まえたときに縮んで消えるまでの時間（秒）
    static let disappearDuration: TimeInterval = 0.3

    private let viewModel: ARCaptureViewModel
    private weak var arView: ARView?
    /// モンスターを置く床のアンカー。モンスターはすべてこの子にする
    private var floorAnchor: AnchorEntity?
    /// アンカーの配置状態の購読。保持していないとすぐに解除される
    private var anchoredSubscription: Cancellable?
    /// 毎フレームの更新の購読。歩いた距離を測るのに使う
    private var updateSubscription: Cancellable?
    /// 最後に歩いたとみなした、床の上での自分の位置（ワールド座標の x, z）
    private var lastWalkPoint: SIMD2<Float>?
    /// 床に置いたモンスター。キーは WildMonster.id
    private var entities: [WildMonster.ID: Entity] = [:]
    /// モンスターごとの、モデルの読み込みから歩き回るまでのタスク
    /// ここにあるモンスターは「置いた（または置こうとしている）」ことを表す
    private var tasks: [WildMonster.ID: Task<Void, Never>] = [:]

    init(viewModel: ARCaptureViewModel) {
        self.viewModel = viewModel
    }

    func start(in arView: ARView) {
        self.arView = arView

        // 20cm 四方以上の床が見つかったら、そこに自動で固定されるアンカー
        // 机や棚の上も水平面なので、床だけに絞る（絞らないと、机の高さに置かれて宙に浮いて見える）
        let anchor = AnchorEntity(.plane(.horizontal, classification: .floor, minimumBounds: [0.2, 0.2]))
        // 床が見つかってアンカーが固定されたら ViewModel に知らせる
        // 固定のイベントを取りこぼさないよう、シーンに置く前に購読しておく
        anchoredSubscription = arView.scene.subscribe(
            to: SceneEvents.AnchoredStateChanged.self,
            on: anchor
        ) { [weak self] event in
            self?.viewModel.floorStateChanged(isFound: event.isAnchored)
        }
        arView.scene.addAnchor(anchor)
        floorAnchor = anchor

        updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            self?.measureWalk()
        }

        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    /// ViewModel のモンスター一覧に合わせて、床のモンスターを置いたり消したりする
    func sync(_ monsters: [WildMonster]) {
        guard floorAnchor != nil else { return }
        let ids = Set(monsters.map(\.id))

        // 一覧からいなくなったのは、捕まえられたか逃げたモンスター
        for id in tasks.keys where !ids.contains(id) {
            disappear(id: id)
        }
        for wild in monsters where tasks[wild.id] == nil {
            appear(wild)
        }
    }

    func stop() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        entities.removeAll()
        anchoredSubscription?.cancel()
        anchoredSubscription = nil
        updateSubscription?.cancel()
        updateSubscription = nil
        lastWalkPoint = nil
        floorAnchor = nil
        // ARView ごとアンカーがなくなるので、次に表示したときは床を探すところからやり直す
        viewModel.floorStateChanged(isFound: false)
    }

    private func appear(_ wild: WildMonster) {
        tasks[wild.id] = Task { [weak self] in
            // モデルの読み込みは時間がかかるので、読み込み終わってから床に置く
            let entity = await MonsterEntity.make(from: wild.monster)
            guard let self, let floorAnchor = self.floorAnchor, let arView = self.arView, !Task.isCancelled else { return }

            // ARView.entity(at:) でタップを拾えるのは、当たり判定（CollisionComponent）を持つエンティティだけ
            entity.generateCollisionShapes(recursive: true)
            // y は MonsterEntity が決めた高さのまま（モデルは足元が原点なので 0）
            let home = Self.randomSpawnPoint(around: arView.cameraTransform, on: floorAnchor)
            entity.position = [home.x, entity.position.y, home.y]
            entity.orientation = simd_quatf(angle: .random(in: 0..<(2 * .pi)), axis: [0, 1, 0])
            floorAnchor.addChild(entity)
            self.entities[wild.id] = entity

            await self.walkAround(entity, home: home, speed: Self.walkSpeedPerHeight * wild.monster.size)
        }
    }

    private func disappear(id: WildMonster.ID) {
        tasks.removeValue(forKey: id)?.cancel()
        // まだ読み込み中だった場合はエンティティがないので、タスクを止めるだけでよい
        guard let entity = entities.removeValue(forKey: id) else { return }

        // 歩いている途中の動きを止めてから縮める
        entity.stopAllAnimations()
        var transform = entity.transform
        // 0 にすると計算が不安定になるので、見えないくらい小さくする
        transform.scale = .init(repeating: 0.001)
        entity.move(to: transform, relativeTo: entity.parent, duration: Self.disappearDuration)
        Task {
            try? await Task.sleep(for: .seconds(Self.disappearDuration))
            entity.removeFromParent()
        }
    }

    /// 「向きを変える → 歩く → 少し止まる」を、タスクが止められるまで繰り返す
    /// home は出現した場所。その周りだけを歩く。speed は歩く速さ（m/秒）
    /// 歩いている間は歩くアニメーション、止まっている間は立っているアニメーションを流す
    private func walkAround(_ entity: Entity, home: SIMD2<Float>, speed: Float) async {
        while !Task.isCancelled {
            let current = SIMD2(entity.position.x, entity.position.z)
            let target = Self.nextTarget(from: current, home: home)
            let direction = target - current

            var transform = entity.transform
            // モデルは +Z 方向が正面なので、+Z が進む方向を向くように Y 軸で回す
            // 実機で後ろ向きに歩いていたら、角度に .pi を足す
            transform.rotation = simd_quatf(angle: atan2(direction.x, direction.y), axis: [0, 1, 0])
            entity.move(to: transform, relativeTo: entity.parent, duration: Self.turnDuration)
            try? await Task.sleep(for: .seconds(Self.turnDuration))
            guard !Task.isCancelled else { return }

            let walkDuration = TimeInterval(simd_length(direction) / speed)
            transform.translation = [target.x, transform.translation.y, target.y]
            entity.monsterAnimator?.loop(.walk)
            entity.move(to: transform, relativeTo: entity.parent, duration: walkDuration, timingFunction: .linear)
            try? await Task.sleep(for: .seconds(walkDuration))
            guard !Task.isCancelled else { return }
            entity.monsterAnimator?.loop(.idle)

            try? await Task.sleep(for: .seconds(Double.random(in: Self.restRange)))
        }
    }

    /// 床の上で自分が walkStep 以上動いたら、その距離を ViewModel に伝える
    /// 高さは無視する（しゃがんだり端末を上下に動かしたりしても、歩いたことにしない）
    private func measureWalk() {
        guard let arView else { return }
        let camera = arView.cameraTransform.translation
        let point = SIMD2(camera.x, camera.z)
        guard let lastWalkPoint else {
            lastWalkPoint = point
            return
        }
        let distance = simd_distance(point, lastWalkPoint)
        guard distance >= Self.walkStep else { return }
        self.lastWalkPoint = point
        viewModel.walked(distance: distance)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView else { return }
        // 当たるのはモデルの中の部品なので、親をたどって床に置いたモンスターを探す
        var hit = arView.entity(at: recognizer.location(in: arView))
        while let entity = hit {
            if let (id, monster) = entities.first(where: { $0.value === entity }) {
                // スマホは床より 1m 以上高い位置にあるので、高さは無視して床の上の距離で測る
                let camera = arView.cameraTransform.translation
                let position = monster.position(relativeTo: nil)
                let distance = simd_distance(SIMD2(camera.x, camera.z), SIMD2(position.x, position.z))
                viewModel.monsterTapped(id: id, distance: distance)
                return
            }
            hit = entity.parent
        }
    }

    /// モンスターが出現するランダムな点（床のアンカーから見た x, z）。自分の前の方の、少し離れた場所にする
    /// 床のアンカーは最初に床が見つかった場所にあるので、歩いたあとは自分の位置から求める必要がある
    private static func randomSpawnPoint(around camera: Transform, on anchor: Entity) -> SIMD2<Float> {
        let position = anchor.convert(position: camera.translation, from: nil)
        // カメラは -Z 方向を向いている
        let forward = anchor.convert(direction: camera.rotation.act([0, 0, -1]), from: nil)
        let facing = atan2(forward.z, forward.x)
        let angle = facing + .random(in: -spawnAngleRange...spawnAngleRange)
        let distance = Float.random(in: spawnDistanceRange)
        return [position.x + distance * cos(angle), position.z + distance * sin(angle)]
    }

    /// 今いる場所から少し離れた、次に歩いていく点
    private static func nextTarget(from current: SIMD2<Float>, home: SIMD2<Float>) -> SIMD2<Float> {
        let step = Float.random(in: stepRange)
        let angle = Float.random(in: 0..<(2 * .pi))
        let target = current + [step * cos(angle), step * sin(angle)]
        // 歩き回る範囲の外に出てしまうときは、出現した場所に向かって歩かせる
        if simd_distance(target, home) > wanderRadius {
            return current + simd_normalize(home - current) * step
        }
        return target
    }
}
