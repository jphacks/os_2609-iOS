//
//  MonsterBookView.swift
//  ARApp
//

import SwiftUI

/// 図鑑の画面。捕獲画面のメニューから開き、捕獲画面の上に重ねて出す
/// 上半分に選んだモンスターの 3D と名前・大きさ、下半分に全種類のマスを並べる。捕まえたマスをタップすると上半分が変わる
struct MonsterBookView: View {
    @State private var viewModel: MonsterBookViewModel
    /// × が押されたときに呼ぶ
    let onClose: () -> Void

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    init(collection: any MonsterCollection, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: MonsterBookViewModel(collection: collection))
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 12) {
            MenuScreenHeaderComponent(title: "図鑑", onClose: onClose)
            Text("\(viewModel.entries.count)種類中 \(viewModel.capturedCount)種類")
                .font(BattleStyle.display(20))
                .foregroundStyle(BattleStyle.lime)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if let selected = viewModel.selected {
                    MonsterPreviewComponent(monster: selected)
                } else {
                    Text("まだモンスターを捕まえていません")
                        .font(BattleStyle.display(20))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ScrollView {
                LazyVGrid(columns: Self.columns, spacing: 12) {
                    ForEach(viewModel.entries) { entry in
                        Button {
                            viewModel.select(entry)
                        } label: {
                            MonsterCellComponent(
                                monster: entry.monster,
                                isCaptured: entry.isCaptured,
                                isSelected: entry.monster.modelName == viewModel.selected?.modelName
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!entry.isCaptured)
                    }
                }
                .padding(4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BattleStyle.ink)
        .environment(\.colorScheme, .dark)
        .sensoryFeedback(.selection, trigger: viewModel.selected?.modelName)
    }
}

#Preview {
    // メモリの中だけの保存先に、何体か捕まえたことにして出す
    let collection = SwiftDataMonsterCollection(inMemory: true)
    Monster.all.prefix(5).forEach(collection.add)
    return MonsterBookView(collection: collection) {}
}
