//
//  StarterMonsterSelectionModifier.swift
//  ARApp
//

import SwiftUI

/// バトルに出すモンスターがまだ決まっていなければ、最初にモンスターを選ぶ画面を上に重ねて出す
/// 決めると選ぶ画面がフェードで消え、消え終わってから onDecided を呼ぶ
struct StarterMonsterSelectionModifier: ViewModifier {
    let collection: any MonsterCollection
    let onDecided: () -> Void

    @State private var isChoosing: Bool

    init(collection: any MonsterCollection, onDecided: @escaping () -> Void) {
        self.collection = collection
        self.onDecided = onDecided
        _isChoosing = State(initialValue: collection.battleMonster == nil)
    }

    func body(content: Content) -> some View {
        content.overlay {
            if isChoosing {
                StarterMonsterView(collection: collection) {
                    // 選ぶ画面（SceneKit）が消えきる前に捕獲画面の ARView を作らないよう、フェードが終わるのを待つ
                    withAnimation(.easeInOut) {
                        isChoosing = false
                    } completion: {
                        onDecided()
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

extension View {
    /// バトルに出すモンスターがまだ決まっていなければ、最初にモンスターを選ぶ画面を上に重ねて出す
    /// - Parameters:
    ///   - collection: バトルに出すモンスターを読み書きする保存先
    ///   - onDecided: モンスターを決め、選ぶ画面が消え終わったときに呼ぶ
    func starterMonsterSelection(collection: any MonsterCollection, onDecided: @escaping () -> Void) -> some View {
        modifier(StarterMonsterSelectionModifier(collection: collection, onDecided: onDecided))
    }
}
