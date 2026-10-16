//
//  BattleLobbyView.swift
//  ARApp
//

import SwiftUI

/// 対戦相手を探す前の画面。今いる地点と、自分のモンスターを見せる
struct BattleLobbyView: View {
    let myMonster: Monster
    /// 推定した現在地。わからない間は相手を探せない
    let location: Location?
    let isSearching: Bool
    let errorMessage: String?
    let onFind: (Location) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("MONSTER BATTLE")
                .font(.headline)

            MonsterCardView(name: myMonster.name, trait: BattleProfile.of(myMonster).trait, isDefeated: false)

            Text("同じ場所にいる人と対戦できます")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Spacer()

            if isSearching {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("\(location?.name ?? "")で相手を探しています…")
                    Button("やめる", role: .cancel, action: onCancel)
                }
            } else if let location {
                Button {
                    onFind(location)
                } label: {
                    Text("\(location.name)で対戦相手を探す")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Text("現在地を探しています…")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    BattleLobbyView(
        myMonster: Monster.all[0],
        location: Location.registered[0],
        isSearching: false,
        errorMessage: nil,
        onFind: { _ in },
        onCancel: {}
    )
    .padding()
}
