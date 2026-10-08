//
//  Monster.swift
//  ARApp
//

import Foundation

/// AR 空間に出現するモンスターのデータ
struct Monster: Identifiable {
    let id = UUID()
    let name: String
    /// 体の直径（メートル）。ARKit / RealityKit の 1.0 は現実の 1m
    let size: Float
}
