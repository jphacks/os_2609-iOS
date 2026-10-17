//
//  StarterMonsterView.swift
//  ARApp
//

import SwiftUI

/// 最初にモンスターを選ぶ画面。3 体から 1 体をタップで選び、大きく 3D で確かめてから決める
/// 3D は SceneKit（MonsterModelComponent）で出し、RealityKit は使わない（捕獲画面の ARView とぶつからないように）
struct StarterMonsterView: View {
    @State private var viewModel: StarterMonsterViewModel
    /// 決めたときに呼ぶ
    let onDecided: () -> Void

    init(collection: any MonsterCollection, onDecided: @escaping () -> Void) {
        _viewModel = State(initialValue: StarterMonsterViewModel(collection: collection))
        self.onDecided = onDecided
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("最初のモンスターを選ぼう")
                .font(.title2.bold())

            Group {
                if let selected = viewModel.selected {
                    VStack(spacing: 4) {
                        MonsterModelComponent(monster: selected)
                            // 選び直したら、新しいモンスターで作り直す
                            .id(selected.modelName)
                        Text(selected.name)
                            .font(.title3.bold())
                    }
                } else {
                    ContentUnavailableView("下のモンスターをタップしてね", systemImage: "hand.tap")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 12) {
                ForEach(viewModel.candidates, id: \.modelName) { monster in
                    StarterMonsterCardComponent(monster: monster, isSelected: monster.modelName == viewModel.selected?.modelName)
                        .onTapGesture { viewModel.select(monster) }
                }
            }
            .frame(height: 160)

            Button {
                viewModel.confirm()
                onDecided()
            } label: {
                Text("このモンスターにする")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selected == nil)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

/// 選べるモンスター 1 体ぶんのカード。小さな 3D と名前を出し、選んでいるときは枠で囲む
private struct StarterMonsterCardComponent: View {
    let monster: Monster
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            MonsterModelComponent(monster: monster)
                // カードはタップで選ぶので、ドラッグで回さない（タップはカード全体で受け取る）
                .allowsHitTesting(false)
            Text(monster.name)
                .font(.caption.bold())
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 3)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    // メモリの中だけに保存するので、プレビューで決めても端末には残らない
    StarterMonsterView(collection: SwiftDataMonsterCollection(inMemory: true)) {}
}
