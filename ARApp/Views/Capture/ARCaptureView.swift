//
//  ARCaptureView.swift
//  ARApp
//

import SwiftUI
import ARKit
import UIKit

/// AR 捕獲画面。カメラ映像の上に状態メッセージと現在地を重ねる
struct ARCaptureView: View {
    let locationViewModel: LocationViewModel
    @State private var viewModel = ARCaptureViewModel()
    /// この画面が表示されているか
    /// TabView は別のタブに切り替えても画面を残すので、自分で ARView を外してカメラを止める
    @State private var isVisible = false
    /// ⚠️ 開発用: 実測フィンガープリントを確認・コピーするための登録候補
    /// 不要になったら、右上の長押し UI と FingerprintRegistrationSheet を削除する
    @State private var registrationCandidate: RSSIFingerprintRegistration?
    @State private var registrationError: String?

    var body: some View {
        // ワールドトラッキングは A9 以降のチップを搭載した実機でのみ動作する（シミュレータは非対応）
        if ARWorldTrackingConfiguration.isSupported {
            ZStack {
                Color.black
                if isVisible {
                    // 外すと ARViewContainer の dismantleUIView が呼ばれ、セッションが止まる
                    ARViewContainer(viewModel: viewModel)
                }
            }
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                Text(viewModel.statusMessage)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
            }
            // ⚠️ 開発用: AR画面右上を1秒長押しすると、停止中の3秒中央値を辞書形式で表示する。
            .overlay(alignment: .topTrailing) {
                Label("RSSI登録", systemImage: "wave.3.right.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 1, maximumDistance: 30) {
                        showFingerprintRegistration()
                    }
                    .accessibilityLabel("RSSIフィンガープリントを登録")
                    .accessibilityHint("1秒間長押しすると、停止中に測定した値を表示します")
                    .padding(.top, 8)
                    .padding(.trailing, 12)
            }
            .overlay(alignment: .bottom) {
                LocationStatusComponent(viewModel: locationViewModel)
                    .padding(.bottom, 8)
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
            .sheet(item: $registrationCandidate) { candidate in
                FingerprintRegistrationSheet(candidate: candidate)
            }
            .alert(
                "RSSIを登録できません",
                isPresented: Binding(
                    get: { registrationError != nil },
                    set: { if !$0 { registrationError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { registrationError = nil }
            } message: {
                Text(registrationError ?? "")
            }
        } else {
            ContentUnavailableView(
                "ARに対応していません",
                systemImage: "arkit",
                description: Text("このデバイスではARを利用できません。ARKit対応のiPhoneまたはiPadの実機で起動してください。")
            )
        }
    }

    private func showFingerprintRegistration() {
        switch locationViewModel.fingerprintRegistration() {
        case .success(let candidate):
            registrationCandidate = candidate
        case .failure(let error):
            registrationError = error.message
        }
    }
}

/// ⚠️ 開発用: 新しいチェックポイントを採取した時にだけ表示するコピー用シート。
/// 本番で登録機能を公開しない場合は、この型と ARCaptureView の右上オーバーレイを削除する。
private struct FingerprintRegistrationSheet: View {
    let candidate: RSSIFingerprintRegistration

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Label("登録候補は妥当です", systemImage: "checkmark.seal.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.green)

                Text(candidate.qualitySummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("`Location` のチェックポイントに貼り付ける値")
                    .font(.subheadline.weight(.semibold))

                ScrollView(.horizontal) {
                    Text(candidate.dictionaryLiteral)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(14)
                }
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                Spacer()

                Button {
                    UIPasteboard.general.string = candidate.dictionaryLiteral
                    copied = true
                } label: {
                    Label(copied ? "コピーしました" : "辞書をコピー", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
            .navigationTitle("RSSIフィンガープリント")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
