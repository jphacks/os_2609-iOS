//
//  MapView.swift
//  ARApp
//

import SwiftUI

/// マップ画面。屋内マップと、近距離対戦の受付を表示する
struct MapView: View {
    let locationViewModel: LocationViewModel
    let nearbyBattleDiscovery: NearbyBattleDiscovery
    let onStartBattle: (UUID) -> Void
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 16) {
            Text(locationViewModel.statusMessage)
                .font(.headline)
                .foregroundStyle(locationViewModel.isMoving ? .orange : .primary)

            IndoorMapComponent(
                locations: Location.registered,
                currentLocation: locationViewModel.currentLocation,
                currentPosition: locationViewModel.currentPosition,
                confidence: locationViewModel.confidence
            )

            LocationSignalComponent(viewModel: locationViewModel)
            NearbyBattleReceptionComponent(discovery: nearbyBattleDiscovery)
        }
        .padding()
        .onDisappear {
            // Map タブ以外では、相手探しも端末の広告も行わない
            nearbyBattleDiscovery.stopForInactiveMap()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                nearbyBattleDiscovery.stopForInactiveMap()
            }
        }
        .onChange(of: nearbyBattleDiscovery.readyToken) {
            if let token = nearbyBattleDiscovery.readyToken { onStartBattle(token) }
        }
        .alert(
            "近くに対戦相手がいます",
            isPresented: Binding(
                get: { nearbyBattleDiscovery.pendingCandidate != nil },
                // 承諾・辞退の処理は各ボタンが行う。自動解除で候補を消さない。
                set: { _ in }
            )
        ) {
            Button("対戦する") {
                nearbyBattleDiscovery.confirmCandidate()
            }
            Button("今回はやめる", role: .cancel) {
                nearbyBattleDiscovery.dismissCandidate()
            }
        } message: {
            Text("お互いに対戦受付中であることを確認しました。対戦を開始しますか？")
        }
    }
}

/// 最寄りビーコンと推定の確からしさを表示する
private struct LocationSignalComponent: View {
    let viewModel: LocationViewModel

    var body: some View {
        HStack {
            Label(
                viewModel.isMoving ? "停止後に位置を測定します" : (viewModel.nearestBeacon ?? "ビーコン未検出"),
                systemImage: viewModel.isMoving ? "figure.walk" : "dot.radiowaves.left.and.right"
            )
            Spacer()
            Text("信頼度：\(viewModel.confidence.label)")
                .foregroundStyle(confidenceColor)
        }
        .font(.subheadline)
    }

    private var confidenceColor: Color {
        switch viewModel.confidence {
        case .high: .blue
        case .medium: .orange
        case .low, .unavailable: .secondary
        }
    }
}

/// 受付 ON の間だけ、専用 BLE サービスを広告して近くの受付中端末を探す
private struct NearbyBattleReceptionComponent: View {
    let discovery: NearbyBattleDiscovery

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(
                isOn: Binding(
                    get: { discovery.isAccepting },
                    set: { discovery.setAccepting($0) }
                )
            ) {
                Label("対戦受付", systemImage: "bolt.horizontal.circle")
            }
            .disabled((!discovery.isBluetoothReady || !discovery.isPairingConfigured) && !discovery.isAccepting)

            Text(statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var statusText: String {
        if let message = discovery.statusMessage { return message }
        if !discovery.isPairingConfigured { return "対戦の接続設定がありません" }
        if discovery.isWaitingForConsent { return "相手の承諾を待っています（最大30秒）" }
        if !discovery.isBluetoothReady {
            return "Bluetoothをオンにすると対戦受付を利用できます"
        }
        return discovery.isAccepting
            ? "近くで対戦受付中の相手を探しています"
            : "受付をオンにすると近くの相手を探します"
    }
}

#Preview {
    let location = Location.registered[0]
    let viewModel = LocationViewModel(scanner: DummyBeaconScanner(location: location))
    MapView(
        locationViewModel: viewModel,
        nearbyBattleDiscovery: NearbyBattleDiscovery(),
        onStartBattle: { _ in }
    )
        .onAppear { viewModel.start() }
}
