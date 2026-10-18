//
//  MonsterMenuComponent.swift
//  ARApp
//

import SwiftUI

/// 捕獲画面の下に置くメニューボタン。押すと「図鑑」「編成」のボタンが左上と右上に飛び出す
/// 開いているかは置く側が持つ（周りをタップして閉じられるようにするため）
struct MonsterMenuComponent: View {
    @Binding var isExpanded: Bool
    let onOpenBook: () -> Void
    let onOpenTeam: () -> Void

    /// 飛び出したボタンの、メニューボタンからの位置（pt）。x は左右に、y は上にずらす量
    private static let itemOffset = CGSize(width: 84, height: 72)

    var body: some View {
        ZStack {
            item(title: "図鑑", systemImage: "book.fill", color: BattleStyle.pink, direction: -1, action: onOpenBook)
            item(title: "編成", systemImage: "figure.2", color: BattleStyle.cyan, direction: 1, action: onOpenTeam)

            Button {
                withAnimation(.spring(duration: 0.35, bounce: 0.45)) { isExpanded.toggle() }
            } label: {
                Image(systemName: isExpanded ? "xmark" : "line.3.horizontal")
                    .font(.title.weight(.black))
                    .foregroundStyle(.black)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 68, height: 68)
                    .background(BattleStyle.yellow, in: Circle())
                    .overlay { Circle().stroke(.black, lineWidth: 3) }
                    .hardShadow()
            }
            .accessibilityLabel(isExpanded ? "メニューを閉じる" : "メニュー")
        }
        .sensoryFeedback(.selection, trigger: isExpanded)
    }

    /// 飛び出すボタン。閉じている間はメニューボタンの後ろに小さく隠しておく
    /// - Parameter direction: 左に飛び出すなら -1、右なら 1
    private func item(title: String, systemImage: String, color: Color, direction: CGFloat, action: @escaping () -> Void) -> some View {
        Button {
            isExpanded = false
            action()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.black))
                Text(title)
                    .font(BattleStyle.display(15))
            }
            .foregroundStyle(.black)
            .frame(width: 64, height: 64)
            .background(color, in: Circle())
            .overlay { Circle().stroke(.black, lineWidth: 3) }
            .hardShadow()
        }
        .scaleEffect(isExpanded ? 1 : 0.3)
        .opacity(isExpanded ? 1 : 0)
        .offset(
            x: isExpanded ? Self.itemOffset.width * direction : 0,
            y: isExpanded ? -Self.itemOffset.height : 0
        )
        .allowsHitTesting(isExpanded)
    }
}

#Preview {
    @Previewable @State var isExpanded = true
    MonsterMenuComponent(isExpanded: $isExpanded, onOpenBook: {}, onOpenTeam: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 40)
        .background(.gray)
}
