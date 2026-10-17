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
        // モデルの読み込みは時間がかかるので、読み込み終わってからアンカーごとシーンに置く
        // 先にアンカーを置くと、モデルが出る前に「現れた！」と表示されてしまう
        // 【開発用】全モンスターを並べて見比べる。戻すときは MonsterLineupEntity.swift の先頭のコメントを見る
        loadTask = Task {
            let entity = await MonsterLineupEntity.make()
            guard !Task.isCancelled else { return }

            // 20cm 四方以上の水平面が見つかったら、そこに自動で固定されるアンカー
            let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.2, 0.2]))
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
