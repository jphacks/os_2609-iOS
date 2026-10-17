//
//  ARSceneController.swift
//  ARApp
//

import RealityKit
import Combine
import UIKit

/// ARView のシーンを操作する
/// 担当：アンカーやエンティティの配置、タップなどシーンのイベントを ViewModel に伝えること
/// タップを UITapGestureRecognizer で受け取るため（@objc のメソッドを呼んでもらうため）NSObject を継承している
final class ARSceneController: NSObject {
    private let viewModel: ARCaptureViewModel
    private weak var arView: ARView?
    /// いま AR に置いている（または読み込み中の）出現の ID
    private var placedEncounterID: Encounter.ID?
    /// モンスターを乗せているアンカー。タップがモンスターに当たったかの判定と、消すときに使う
    private var monsterAnchor: AnchorEntity?
    /// アンカーの配置状態の購読。保持していないとすぐに解除される
    private var anchoredSubscription: Cancellable?
    /// モンスターのモデルを読み込むタスク
    private var loadTask: Task<Void, Never>?

    init(viewModel: ARCaptureViewModel) {
        self.viewModel = viewModel
    }

    /// ARView を作った直後に 1 回だけ呼ぶ。タップを受け取れるようにする
    func start(in arView: ARView) {
        self.arView = arView
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    /// ViewModel が出しているモンスターに AR を合わせる。今置いているものと同じなら何もしない
    func show(_ encounter: Encounter?) {
        guard encounter?.id != placedEncounterID else { return }
        removeMonster()
        if let encounter {
            placeMonster(encounter)
        }
    }

    func stop() {
        // ARView ごとアンカーがなくなるので、次に表示したときは床を探すところからやり直す
        removeMonster()
        arView = nil
    }

    private func placeMonster(_ encounter: Encounter) {
        guard let arView else { return }
        placedEncounterID = encounter.id

        // モデルの読み込みは時間がかかるので、読み込み終わってからアンカーごとシーンに置く
        // 先にアンカーを置くと、モデルが出る前に「現れた！」と表示されてしまう
        loadTask = Task {
            let entity = await MonsterEntity.make(from: encounter.monster)
            guard !Task.isCancelled else { return }
            addTapTarget(to: entity)

            // 20cm 四方以上の床が見つかったら、そこに自動で固定されるアンカー
            // 机や棚の上も水平面なので、床だけに絞る（絞らないと、机の高さに置かれて宙に浮いて見える）
            let anchor = AnchorEntity(.plane(.horizontal, classification: .floor, minimumBounds: [0.2, 0.2]))
            anchor.addChild(entity)

            // 平面が見つかってアンカーが固定されたら ViewModel に知らせる
            // 固定のイベントを取りこぼさないよう、シーンに置く前に購読しておく
            anchoredSubscription = arView.scene.subscribe(
                to: SceneEvents.AnchoredStateChanged.self,
                on: anchor
            ) { [weak self] event in
                self?.viewModel.monsterAnchorStateChanged(isAnchored: event.isAnchored)
            }
            arView.scene.addAnchor(anchor)
            monsterAnchor = anchor
        }
    }

    private func removeMonster() {
        loadTask?.cancel()
        loadTask = nil
        anchoredSubscription?.cancel()
        anchoredSubscription = nil
        monsterAnchor?.removeFromParent()
        monsterAnchor = nil
        placedEncounterID = nil
        viewModel.monsterAnchorStateChanged(isAnchored: false)
    }

    /// タップの当たり判定に使う形を付ける。形がないと arView.entity(at:) で見つからない
    /// 細かい形に合わせると腕の隙間などで外れやすいので、モデル全体を囲む箱にする
    private func addTapTarget(to entity: Entity) {
        let bounds = entity.visualBounds(relativeTo: entity)
        let shape = ShapeResource.generateBox(size: bounds.extents).offsetBy(translation: bounds.center)
        entity.components.set(CollisionComponent(shapes: [shape]))
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView, let monsterAnchor else { return }
        let point = recognizer.location(in: arView)
        // 当たったエンティティが、モンスターを乗せたアンカーの下にあるかで判定する
        guard let hit = arView.entity(at: point), hit.anchor === monsterAnchor else { return }
        viewModel.monsterTapped()
    }
}
