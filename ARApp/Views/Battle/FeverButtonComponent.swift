//
//  FeverButtonComponent.swift
//  ARApp
//

import SwiftUI

/// フィーバーボタン。フィーバーゲージが満タンなら押せる
/// フィーバー中は、押す代わりに残り時間を出す
struct FeverButtonComponent: View {
    let canUse: Bool
    /// フィーバーが終わる時刻。フィーバー中でなければ nil
    let endsAt: Date?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let endsAt {
                    // 残り時間を 0.1 秒ごとに書き換える
                    TimelineView(.periodic(from: .now, by: 0.1)) { context in
                        let remaining = max(endsAt.timeIntervalSince(context.date), 0)
                        Label {
                            Text("残り \(remaining, format: .number.precision(.fractionLength(1))) 秒")
                        } icon: {
                            Image(systemName: "flame.fill")
                        }
                    }
                } else {
                    Label(canUse ? "FEVER READY!" : "フィーバー", systemImage: "flame.fill")
                }
            }
            .font(.headline.monospacedDigit())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(endsAt != nil ? .orange : .pink)
        // フィーバー中は押しても何も起きないが、残り時間が暗くならないよう押せる見た目のままにする
        .disabled(!canUse && endsAt == nil)
    }
}

#Preview {
    VStack {
        FeverButtonComponent(canUse: false, endsAt: nil) {}
        FeverButtonComponent(canUse: true, endsAt: nil) {}
        FeverButtonComponent(canUse: false, endsAt: .now + 5) {}
    }
    .padding()
}
