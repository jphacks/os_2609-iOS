//
//  MonsterTeamView.swift
//  ARApp
//

import SwiftUI

/// 編成の画面。捕まえたモンスターから、バトルに出すモンスターを選ぶ。捕獲画面のメニューから開き、捕獲画面の上に重ねて出す
/// 上半分にバトルに出すモンスターの 3D と名前・大きさ、下半分に捕まえたモンスターのマスを並べる。マスをタップした時点で決めて保存する
struct MonsterTeamView: View {
    @State private var viewModel: MonsterTeamViewModel
    /// × が押されたときに呼ぶ
    let onClose: () -> Void

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    init(collection: any MonsterCollection, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: MonsterTeamViewModel(collection: collection))
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 12) {
            MenuScreenHeaderComponent(title: "編成", onClose: onClose)
            Text("バトルに出すモンスター")
                .font(BattleStyle.display(20))
                .foregroundStyle(BattleStyle.lime)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if let battleMonster = viewModel.battleMonster {
                    MonsterPreviewComponent(monster: battleMonster)
                } else {
                    Text("下から選んでください")
                        .font(BattleStyle.display(20))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ScrollView {
                LazyVGrid(columns: Self.columns, spacing: 12) {
                    ForEach(viewModel.capturedMonsters, id: \.modelName) { monster in
                        let isChosen = monster.modelName == viewModel.battleMonster?.modelName
                        Button {
                            viewModel.choose(monster)
                        } label: {
                            MonsterCellComponent(monster: monster, isCaptured: true, isSelected: isChosen)
                                .overlay(alignment: .topLeading) {
                                    if isChosen {
                                        Text("出場中")
                                            .font(BattleStyle.display(13))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(BattleStyle.yellow)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
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
        .sensoryFeedback(.success, trigger: viewModel.battleMonster?.modelName)
    }
}

#Preview {
    // メモリの中だけの保存先に、何体か捕まえたことにして出す
    let collection = SwiftDataMonsterCollection(inMemory: true)
    Monster.all.prefix(5).forEach(collection.add)
    collection.setBattleMonster(Monster.all[0])
    return MonsterTeamView(collection: collection) {}
}
