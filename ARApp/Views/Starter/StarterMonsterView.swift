//
//  StarterMonsterView.swift
//  ARApp
//

import SwiftUI

/// 最初にモンスターを選ぶ画面。円盤に乗った 3 体が輪になって並び、横にスワイプ（または ‹ ›）で回して、手前のモンスターに決める
/// 3D は SceneKit（StarterCarouselComponent）で出し、RealityKit は使わない（捕獲画面の ARView とぶつからないように）
struct StarterMonsterView: View {
    @State private var viewModel: StarterMonsterViewModel
    /// 決めたときに呼ぶ
    let onDecided: () -> Void

    /// これだけ横にスワイプしたら、輪を回す（pt）
    private static let swipeThreshold: CGFloat = 50

    init(collection: any MonsterCollection, onDecided: @escaping () -> Void) {
        _viewModel = State(initialValue: StarterMonsterViewModel(collection: collection))
        self.onDecided = onDecided
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("最初のモンスターを選ぼう")
                .font(.title2.bold())

            StarterCarouselComponent(monsters: viewModel.candidates, frontIndex: viewModel.selectedIndex)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            // 左にスワイプすると右のモンスターが、右にスワイプすると左のモンスターが手前に来る
                            if value.translation.width < -Self.swipeThreshold {
                                viewModel.showNext()
                            } else if value.translation.width > Self.swipeThreshold {
                                viewModel.showPrevious()
                            }
                        }
                )
                .overlay(alignment: .leading) {
                    arrowButton(systemName: "chevron.left") { viewModel.showPrevious() }
                }
                .overlay(alignment: .trailing) {
                    arrowButton(systemName: "chevron.right") { viewModel.showNext() }
                }

            Text(viewModel.selected.name)
                .font(.title3.bold())

            // 何番目のモンスターが手前に出ているかの目印
            HStack(spacing: 8) {
                ForEach(viewModel.candidates.indices, id: \.self) { index in
                    Circle()
                        .fill(index == viewModel.selectedIndex ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

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
        }
        .padding()
        // タブの上に重ねて出すので、タブバーやステータスバーの下まで覆う
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private func arrowButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.bold())
                .padding(8)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
    }
}

#Preview {
    // メモリの中だけに保存するので、プレビューで決めても端末には残らない
    StarterMonsterView(collection: SwiftDataMonsterCollection(inMemory: true)) {}
}
