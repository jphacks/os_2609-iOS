//
//  ARSceneController.swift
//  ARApp
//

import RealityKit
import Combine

/// ARView のシーンを操作する
/// 担当：アンカーやエンティティの配置、シーンのイベントを ViewModel に伝えること
final class ARSceneController {
    /// モンスターが出現する範囲。床のアンカーを中心にした円の半径（m）
    static let areaRadius: Float = 0.8

    private let viewModel: ARCaptureViewModel
    /// モンスターを置く床のアンカー。モンスターはすべてこの子にする
    private var floorAnchor: AnchorEntity?
    /// アンカーの配置状態の購読。保持していないとすぐに解除される
    private var anchoredSubscription: Cancellable?
    /// モンスターごとの、モデルを読み込んで床に置くまでのタスク
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
        }
    }

    /// 出現する範囲の中のランダムな点（床の上の x, z）
    private static func randomPointInArea() -> SIMD2<Float> {
        // 半径を平方根にすると、円の中に偏りなく散らばる
        let radius = areaRadius * Float.random(in: 0...1).squareRoot()
        let angle = Float.random(in: 0..<(2 * .pi))
        return [radius * cos(angle), radius * sin(angle)]
    }
}
