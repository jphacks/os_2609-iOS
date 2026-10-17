//
//  ARSceneController.swift
//  ARApp
//

import RealityKit
import ARKit
import UIKit

/// ARView のシーンを操作する
/// 担当：アンカーやエンティティの配置、タップなどシーンのイベントを ViewModel に伝えること
/// タップを UITapGestureRecognizer で受け取るため（@objc のメソッドを呼んでもらうため）NSObject を継承している
final class ARSceneController: NSObject {
    private let viewModel: ARCaptureViewModel
    private weak var arView: ARView?
    /// いま AR に置いている（または読み込み中・床待ちの）出現。AR を開始し直したときに置き直すために持っておく
    private var placedEncounter: Encounter?
    /// 読み込み終わって、置く床が見つかるのを待っているモンスター
    private var waitingEntity: Entity?
    /// モンスターを乗せているアンカー。タップがモンスターに当たったかの判定と、消すときに使う
    private var monsterAnchor: AnchorEntity?
    /// モンスターを置いた床（ARKit の平面）の ID。その平面が消えたときに置き直すために使う
    private var monsterPlaneID: UUID?
    /// モンスターのモデルを読み込むタスク
    private var loadTask: Task<Void, Never>?
    /// AR が中断されているか（ほかのアプリや AirDrop などがカメラを使っている間など）
    private var isSessionInterrupted = false
    /// 失敗した AR を、少し待ってから開始し直すタスク
    private var restartTask: Task<Void, Never>?

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
        guard encounter?.id != placedEncounter?.id else { return }
        removeMonster()
        if let encounter {
            placeMonster(encounter)
        }
    }

    func stop() {
        // ARView ごとアンカーがなくなるので、次に表示したときは床を探すところからやり直す
        removeMonster()
        restartTask?.cancel()
        restartTask = nil
        arView = nil
    }

    /// AR を開始し直す。床を探すところからやり直すので、置いていたモンスターも置き直す
    private func restartSession() {
        guard let arView else { return }
        ARViewContainer.runSession(on: arView, options: [.resetTracking, .removeExistingAnchors])
        if let encounter = placedEncounter {
            removeMonster()
            placeMonster(encounter)
        }
    }

    private func placeMonster(_ encounter: Encounter) {
        placedEncounter = encounter

        // モデルの読み込みは時間がかかるので、読み込み終わってから床を探して置く
        // 先にアンカーを置くと、モデルが出る前に「現れた！」と表示されてしまう
        loadTask = Task {
            let entity = await MonsterEntity.make(from: encounter.monster)
            guard !Task.isCancelled else { return }
            addTapTarget(to: entity)
            waitingEntity = entity
            placeOnFloorIfPossible()
        }
    }

    /// 待っているモンスターがいて、置ける床がもう見つかっていれば、そこに置く
    /// 床がまだなければ何もしない（ARKit が平面を見つけるたびに、もう一度呼ばれる）
    ///
    /// 床探しを AnchorEntity(.plane(...)) に任せず、見つかっている平面から自分で床を選んで、そこに直接置く
    /// AnchorEntity(.plane(...)) では「種類を判定できないが、カメラより十分低い平面」を床として選べないため
    private func placeOnFloorIfPossible() {
        guard let arView, let entity = waitingEntity,
              let floor = nearestFloor(in: arView) else { return }

        let anchor = AnchorEntity(anchor: floor)
        // 平面の原点ではなく、見つかっている範囲の真ん中に立たせる
        entity.position = floor.center
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)

        waitingEntity = nil
        monsterAnchor = anchor
        monsterPlaneID = floor.identifier
        viewModel.monsterAnchorStateChanged(isAnchored: true)
    }

    /// 見つかっている平面のうち、モンスターを置ける床で、カメラに一番近いもの
    private func nearestFloor(in arView: ARView) -> ARPlaneAnchor? {
        guard let frame = arView.session.currentFrame else { return nil }
        let cameraPosition = frame.camera.transform.columns.3
        return frame.anchors
            .compactMap { $0 as? ARPlaneAnchor }
            .filter { Self.canPlaceMonster(on: $0, cameraHeight: cameraPosition.y) }
            .min { distance($0, from: cameraPosition) < distance($1, from: cameraPosition) }
    }

    /// 種類を判定できなかった平面でも、カメラよりこれだけ（m）低ければ床とみなす
    /// スマホを胸の高さ（床から 1.3〜1.5m）で持つ前提。机（約 0.7m）や椅子（約 0.45m）の面はこれより高いので外れる
    /// しゃがんで使うと床を見逃しやすくなるので、そのときはこの値を小さくする
    private static let minimumFloorDepthBelowCamera: Float = 1.0

    /// モンスターを置ける平面か。置く場所の条件はここだけで決める
    /// 机や棚の上も水平面なので、床に絞る（絞らないと、机の高さに置かれて宙に浮いて見える）
    /// ARKit が「床」と判定した平面のほか、種類を判定できなかった平面もカメラより十分低ければ床とみなす
    /// （光を反射するタイルなどは、なかなか「床」と判定されず、モンスターが出なかったため）
    private static func canPlaceMonster(on plane: ARPlaneAnchor, cameraHeight: Float) -> Bool {
        guard plane.alignment == .horizontal,
              plane.planeExtent.width >= 0.2,
              plane.planeExtent.height >= 0.2 else { return false }
        switch plane.classification {
        case .floor:
            return true
        case .none:
            return cameraHeight - plane.transform.columns.3.y >= minimumFloorDepthBelowCamera
        default:
            return false
        }
    }

    private func distance(_ plane: ARPlaneAnchor, from cameraPosition: simd_float4) -> Float {
        simd_distance(plane.transform.columns.3, cameraPosition)
    }

    private func removeMonster() {
        loadTask?.cancel()
        loadTask = nil
        monsterAnchor?.removeFromParent()
        monsterAnchor = nil
        monsterPlaneID = nil
        waitingEntity = nil
        placedEncounter = nil
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

/// AR が見つけた平面の変化に合わせてモンスターを置き、AR が失敗したり中断されたりしたら開始し直す
extension ARSceneController: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        placeOnFloorIfPossible()
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // 平面は広がったり、あとから「床」と判定されたりするので、更新のたびにも確かめる
        placeOnFloorIfPossible()
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        // モンスターを置いた床が消えたら（ほかの平面とまとめられたときなど）、別の床に置き直す
        guard let monsterPlaneID, anchors.contains(where: { $0.identifier == monsterPlaneID }),
              let entity = monsterAnchor?.children.first else { return }
        monsterAnchor?.removeFromParent()
        monsterAnchor = nil
        self.monsterPlaneID = nil
        viewModel.monsterAnchorStateChanged(isAnchored: false)
        waitingEntity = entity
        placeOnFloorIfPossible()
    }

    /// 一度失敗した AR は自動では再開せず、カメラの映像が真っ暗のまま止まってしまうので、開始し直す
    /// （例：AirDrop などがカメラを一瞬使うと「Required sensor failed」で失敗することがある）
    func session(_ session: ARSession, didFailWithError error: Error) {
        // カメラの許可がないときは、開始し直しても同じように失敗するので何もしない
        if (error as? ARError)?.code == .cameraUnauthorized { return }
        // 中断中はカメラを使えないので、中断が終わったときに開始し直す
        guard !isSessionInterrupted else { return }
        // すぐに開始し直すと、同じ理由で失敗をくり返すことがあるので少し待つ
        restartTask?.cancel()
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, !Task.isCancelled, !isSessionInterrupted else { return }
            restartSession()
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        isSessionInterrupted = true
    }

    /// 中断のあとは、ARKit が見つけていた平面を捨ててやり直すことが多く、失敗したまま止まることもある
    /// そのため、失敗したかどうかにかかわらず毎回開始し直して、モンスターも置き直す
    func sessionInterruptionEnded(_ session: ARSession) {
        isSessionInterrupted = false
        restartTask?.cancel()
        restartTask = nil
        restartSession()
    }
}
