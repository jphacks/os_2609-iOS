//
//  ARSceneController.swift
//  ARApp
//

import Foundation
import RealityKit
import Combine

/// ARView のシーンを操作する
/// 担当：アンカーやエンティティの配置、モンスターを歩かせること、シーンのイベントを ViewModel に伝えること
final class ARSceneController {
    /// モンスターが出現・歩き回る範囲。床のアンカーを中心にした円の半径（m）
    static let areaRadius: Float = 0.8
    /// 1 回に歩く距離（m）
    static let stepRange: ClosedRange<Float> = 0.2...0.5
    /// 歩く速さ（m/秒）
    static let walkSpeed: Float = 0.15
    /// 向きを変えるのにかける時間（秒）
    static let turnDuration: TimeInterval = 0.4
    /// 歩き終わってから次に歩き出すまで止まっている時間（秒）
    static let restRange: ClosedRange<Double> = 0.5...2

    private let viewModel: ARCaptureViewModel
    /// モンスターを置く床のアンカー。モンスターはすべてこの子にする
    private var floorAnchor: AnchorEntity?
    /// アンカーの配置状態の購読。保持していないとすぐに解除される
    private var anchoredSubscription: Cancellable?
    /// モンスターごとの、モデルの読み込みから歩き回るまでのタスク
    /// ここにあるモンスターは「置いた（または置こうとしている）」ことを表す
    private var tasks: [WildMonster.ID: Task<Void, Never>] = [:]

    init(viewModel: ARCaptureViewModel) {
        self.viewModel = viewModel
    }

    func start(in arView: ARView) {
        // 20cm 四方以上の水平面が見つかったら、そこに自動で固定されるアンカー
        let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.2, 0.2]))
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
    }

    /// ViewModel のモンスター一覧に合わせて、まだ置いていないモンスターを床に置く
    func sync(_ monsters: [WildMonster]) {
        guard floorAnchor != nil else { return }
        for wild in monsters where tasks[wild.id] == nil {
            appear(wild)
        }
    }

    func stop() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        anchoredSubscription?.cancel()
        anchoredSubscription = nil
        floorAnchor = nil
        // ARView ごとアンカーがなくなるので、次に表示したときは床を探すところからやり直す
        viewModel.floorStateChanged(isFound: false)
    }

    private func appear(_ wild: WildMonster) {
        tasks[wild.id] = Task { [weak self] in
            // モデルの読み込みは時間がかかるので、読み込み終わってから床に置く
            let entity = await MonsterEntity.make(from: wild.monster)
            guard let self, let floorAnchor = self.floorAnchor, !Task.isCancelled else { return }

            // y は MonsterEntity が決めた高さのまま（モデルは足元が原点なので 0）
            let point = Self.randomPointInArea()
            entity.position = [point.x, entity.position.y, point.y]
            entity.orientation = simd_quatf(angle: .random(in: 0..<(2 * .pi)), axis: [0, 1, 0])
            floorAnchor.addChild(entity)

            await self.walkAround(entity)
        }
    }

    /// 「向きを変える → 歩く → 少し止まる」を、タスクが止められるまで繰り返す
    private func walkAround(_ entity: Entity) async {
        while !Task.isCancelled {
            let current = SIMD2(entity.position.x, entity.position.z)
            let target = Self.nextTarget(from: current)
            let direction = target - current

            var transform = entity.transform
            // モデルは +Z 方向が正面なので、+Z が進む方向を向くように Y 軸で回す
            // 実機で後ろ向きに歩いていたら、角度に .pi を足す
            transform.rotation = simd_quatf(angle: atan2(direction.x, direction.y), axis: [0, 1, 0])
            entity.move(to: transform, relativeTo: entity.parent, duration: Self.turnDuration)
            try? await Task.sleep(for: .seconds(Self.turnDuration))
            guard !Task.isCancelled else { return }

            let walkDuration = TimeInterval(simd_length(direction) / Self.walkSpeed)
            transform.translation = [target.x, transform.translation.y, target.y]
            entity.move(to: transform, relativeTo: entity.parent, duration: walkDuration, timingFunction: .linear)
            try? await Task.sleep(for: .seconds(walkDuration))
            guard !Task.isCancelled else { return }

            try? await Task.sleep(for: .seconds(Double.random(in: Self.restRange)))
        }
    }

    /// 歩ける範囲の中のランダムな点（床の上の x, z）
    private static func randomPointInArea() -> SIMD2<Float> {
        // 半径を平方根にすると、円の中に偏りなく散らばる
        let radius = areaRadius * Float.random(in: 0...1).squareRoot()
        let angle = Float.random(in: 0..<(2 * .pi))
        return [radius * cos(angle), radius * sin(angle)]
    }

    /// 今いる場所から少し離れた、次に歩いていく点
    private static func nextTarget(from current: SIMD2<Float>) -> SIMD2<Float> {
        let step = Float.random(in: stepRange)
        let angle = Float.random(in: 0..<(2 * .pi))
        let target = current + [step * cos(angle), step * sin(angle)]
        // 範囲の外に出てしまうときは、中心に向かって歩かせる
        if simd_length(target) > areaRadius {
            return current - simd_normalize(current) * step
        }
        return target
    }
}
