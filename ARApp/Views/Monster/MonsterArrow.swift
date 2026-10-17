//
//  MonsterArrow.swift
//  ARApp
//

import RealityKit
import UIKit

/// 画面の外にいるモンスターの方向を指す矢印（捕獲画面とバトル画面で共通）
/// ARView の上に置き、毎フレーム update を呼んで位置と向きを変える。モンスターが画面に映っている間は隠す
final class MonsterArrow {
    /// 矢印を出す位置の、画面の端からの距離（pt）。上や下の表示に重ならないよう、少し内側に出す
    private let inset: CGFloat
    private let view: UIImageView = {
        let image = UIImage(
            systemName: "arrowtriangle.up.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .bold)
        )
        let view = UIImageView(image: image)
        view.tintColor = .systemYellow
        // カメラの映像が明るくても見えるよう、影を付ける
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.6
        view.layer.shadowRadius = 4
        view.layer.shadowOffset = .zero
        view.isHidden = true
        // 矢印の上をタップしても、後ろのモンスターや画面のタップを邪魔しない
        view.isUserInteractionEnabled = false
        return view
    }()

    init(inset: CGFloat) {
        self.inset = inset
    }

    func attach(to arView: ARView) {
        arView.addSubview(view)
    }

    func detach() {
        view.removeFromSuperview()
    }

    /// target（ワールド座標）が画面の外にあれば、画面の端に、その方向を指す矢印を出す。nil なら隠す
    /// 画面の真ん中から target が映るはずの点へ線を引き、画面の端（inset だけ内側）とぶつかる所に置く
    func update(pointingAt target: SIMD3<Float>?, in arView: ARView) {
        guard let target else {
            view.isHidden = true
            return
        }

        // カメラから見た位置にする。カメラは -Z 方向を向いているので、z が正ならカメラの後ろ
        let camera = arView.cameraTransform.matrix
        var local = camera.inverse * SIMD4(target, 1)
        let isBehind = local.z > 0
        // 後ろにいると画面に映る点が求められないので、カメラの前に折り返す
        // 上下左右の向きは変わらないので、右後ろなら右、左後ろなら左を指す
        if isBehind {
            local.z = -local.z
        }
        let front = camera * local
        guard let point = arView.project(SIMD3(front.x, front.y, front.z)) else {
            view.isHidden = true
            return
        }

        let bounds = arView.bounds
        if !isBehind && bounds.contains(point) {
            view.isHidden = true
            return
        }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        var dx = point.x - center.x
        var dy = point.y - center.y
        // ちょうど真後ろにいるときは、振り返るよう下を指す
        if hypot(dx, dy) < 1 {
            dx = 0
            dy = 1
        }
        // 縦と横のうち、先に画面の端とぶつかる方に合わせる（0 で割ると無限大になり、もう一方が選ばれる）
        let scale = min(
            (bounds.width / 2 - inset) / abs(dx),
            (bounds.height / 2 - inset) / abs(dy)
        )
        view.center = CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
        // 矢印の画像は上向きなので、右向き（0）から 90° 足す
        view.transform = CGAffineTransform(rotationAngle: atan2(dy, dx) + .pi / 2)
        view.isHidden = false
    }
}
