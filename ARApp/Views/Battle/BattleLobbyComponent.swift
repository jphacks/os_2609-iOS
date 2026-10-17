//
//  BattleLobbyComponent.swift
//  ARApp
//
//  ⚠️⚠️⚠️ 開発用のコードを含む ⚠️⚠️⚠️
//  AR を使えない端末（シミュレータ）で対戦を確かめるための「バトルする」ボタン（onStart）がある。
//  本番の端末は AR を使えるので、開いたら自動で待ち、ボタンは出ない。
//  消すときは、このファイルの onStart とボタンに加えて、BattleView の waitsAutomatically と、
//  それを使っている所（onAppear、BattleLobbyComponent に渡す onStart、結果の画面の onBack）も一緒に消す。
//

import SwiftUI

/// 対戦相手を待っている間の画面。自分のモンスターを見せる
/// 待つのは自動（BattleViewModel が、画面を開いている間ずっと待つ）なので、本番の端末ではボタンは出ない
struct BattleLobbyComponent: View {
    let myMonster: Monster
    let isWaiting: Bool
    /// 対戦できなかったとき（通信の失敗、相手が抜けた）のメッセージ。少しすると自動で待ち直す
    let errorMessage: String?
    /// 【開発用】AR を使えない端末で、相手を待ち始めるボタンが押されたとき。nil ならボタンを出さない（自動で待つ）
    let onStart: (() -> Void)?
    /// ときどき手を振るアニメーション
    @State private var waveAnimation: MonsterAnimationRequest?

    /// 手を振る間隔（秒）
    private static let waveIntervalRange: ClosedRange<Double> = 4...8

    var body: some View {
        VStack(spacing: 20) {
            Text("MONSTER BATTLE")
                .font(.headline)

            BattleMonsterComponent(monster: myMonster, animation: waveAnimation, facing: 0.4)
                .frame(width: 240, height: 240)
                // 画面が表示されている間、ときどき手を振る
                .task {
                    while true {
                        do {
                            try await Task.sleep(for: .seconds(Double.random(in: Self.waveIntervalRange)))
                        } catch {
                            return // 画面が閉じられた
                        }
                        waveAnimation = MonsterAnimationRequest(animations: [.wave])
                    }
                }
            Text(myMonster.name)
                .font(.title3.bold())

            Text("この画面を開いている人と対戦できます。画面をタップして攻撃しよう")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            if let onStart, !isWaiting {
                Button(action: onStart) {
                    Text("バトルする")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if errorMessage == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("対戦相手を待っています…")
                }
            }
        }
    }
}

#Preview {
    BattleLobbyComponent(myMonster: Monster.all[0], isWaiting: true, errorMessage: nil, onStart: nil)
        .padding()
}
