//
//  ARSceneController.swift
//  ARApp
//

import RealityKit
import Combine

/// ARView のシーンを操作する
/// 担当：アンカーやエンティティの配置、シーンのイベントを ViewModel に伝えること
final class ARSceneController {
    private let viewModel: ARCaptureViewModel
    /// アンカーの配置状態の購読。保持していないとすぐに解除される
    private var anchoredSubscription: Cancellable?
    /// モンスターのモデルを読み込むタスク
    private var loadTask: Task<Void, Never>?

    init(viewModel: ARCaptureViewModel) {
        self.viewModel = viewModel
    }

    func placeMonster(in arView: ARView) {
        // 20cm 四方以上の水平面が見つかったら、そこに自動で固定されるアンカー
        let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.2, 0.2]))
        arView.scene.addAnchor(anchor)

        // モデルの読み込みは時間がかかるので、終わってからアンカーに乗せる
        let monster = viewModel.monster
        loadTask = Task {
            let entity = await MonsterEntity.make(from: monster)
            guard !Task.isCancelled else { return }
            anchor.addChild(entity)
        }

        // 平面が見つかってアンカーが固定されたら ViewModel に知らせる
        anchoredSubscription = arView.scene.subscribe(
            to: SceneEvents.AnchoredStateChanged.self,
            on: anchor
        ) { [weak self] event in
            self?.viewModel.monsterAnchorStateChanged(isAnchored: event.isAnchored)
        }
    }

    func stop() {
        loadTask?.cancel()
        loadTask = nil
        anchoredSubscription?.cancel()
        anchoredSubscription = nil
        // ARView ごとアンカーがなくなるので、次に表示したときは床を探すところからやり直す
        viewModel.monsterAnchorStateChanged(isAnchored: false)
    }
}
