//
//  BattleStyle.swift
//  ARApp
//

import SwiftUI

/// バトル画面の見た目をそろえるための色・文字・形
/// 丸みを使わず、角ばった形、ビビッドな色、ぼかさない影で、格闘ゲームやパチンコのようなパキッとした見た目にする
enum BattleStyle {
    static let pink = Color(red: 1, green: 0.1, blue: 0.55)
    static let cyan = Color(red: 0, green: 0.9, blue: 1)
    static let yellow = Color(red: 1, green: 0.92, blue: 0)
    static let lime = Color(red: 0.6, green: 1, blue: 0)
    static let red = Color(red: 1, green: 0.12, blue: 0.2)
    /// パネルの地の色（ほぼ黒）
    static let ink = Color(red: 0.04, green: 0.04, blue: 0.1)

    /// 見出しの文字。丸くない極太の斜体を、横に詰めて使う
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.condensed).italic()
    }
}

/// 左右の端を斜めに切った四角形（平行四辺形）。バー、パネル、ボタンの形に使う
struct SlantedRectangle: Shape {
    /// 上の辺を右に、下の辺を左にずらす幅（pt）
    var slant: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + slant, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - slant, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

extension View {
    /// ぼかさずに右下へずらした影。パネルやボタンなどの形に付ける
    /// 文字に付けると、文字が 2 重に重なって見えて読みにくいので、文字には付けない（「MONSTER BATTLE」の飾り文字だけは例外）
    func hardShadow(_ color: Color = .black, offset: CGFloat = 4) -> some View {
        // まとめて 1 枚にしてから影を付ける。そのままだと、帯の上の文字にも 1 文字ずつ影が付き、文字が重なって見える
        compositingGroup()
            .shadow(color: color, radius: 0, x: offset, y: offset)
    }

    /// 文字を、斜めに切った帯の上に載せる。カメラの映像の上でも、影を付けずに読めるようにする
    func onBand(_ color: Color, slant: CGFloat = 16) -> some View {
        padding(.horizontal, 28)
            .padding(.vertical, 4)
            .background(color, in: SlantedRectangle(slant: slant))
            .hardShadow()
    }

    /// HP などをまとめるパネル。黒い平行四辺形に、色の付いた枠を付ける
    func battlePanel(accent: Color) -> some View {
        padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(BattleStyle.ink.opacity(0.85), in: SlantedRectangle())
            .overlay { SlantedRectangle().stroke(accent, lineWidth: 2) }
    }
}

/// バトル画面のボタン。ビビッドな平行四辺形に黒い文字。押すと影の分だけ沈む
struct BattleButtonStyle: ButtonStyle {
    var color = BattleStyle.yellow

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BattleStyle.display(24))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color, in: SlantedRectangle(slant: 16))
            .overlay { SlantedRectangle(slant: 16).stroke(.black, lineWidth: 3) }
            .hardShadow(offset: configuration.isPressed ? 0 : 5)
            .offset(x: configuration.isPressed ? 5 : 0, y: configuration.isPressed ? 5 : 0)
    }
}

#Preview {
    VStack(spacing: 24) {
        Text("MONSTER BATTLE")
            .font(BattleStyle.display(40))
            .foregroundStyle(BattleStyle.yellow)
            .hardShadow(BattleStyle.pink)
        Text("パネル")
            .foregroundStyle(.white)
            .battlePanel(accent: BattleStyle.cyan)
        Button("バトルする") {}
            .buttonStyle(BattleButtonStyle())
    }
    .padding()
    .background(.gray)
}
