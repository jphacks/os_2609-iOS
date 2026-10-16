//
//  MapPosition.swift
//  ARApp
//

import Foundation

/// マップ上の位置。マップの幅・高さに対する割合（0〜1）で表す
/// 画面サイズに依存しないので、どの端末でも同じ場所に表示できる
struct MapPosition {
    /// 0 が左端、1 が右端
    let x: Double
    /// 0 が上端、1 が下端
    let y: Double
}
