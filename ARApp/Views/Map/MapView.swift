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

            IndoorMapComponent(
                locations: Location.registered,
                currentLocation: locationViewModel.currentLocation,
                currentPosition: locationViewModel.currentPosition
            )

            NearbyBattleReceptionComponent(discovery: nearbyBattleDiscovery)
        }
        .padding()
        .onDisappear {
            // Map タブ以外では、相手探しも端末の広告も行わない
            nearbyBattleDiscovery.stopForInactiveMap()
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                nearbyBattleDiscovery.stopForInactiveMap()
            }
        }
        .alert(
            "近くに対戦相手がいます",
            isPresented: Binding(
                get: { nearbyBattleDiscovery.pendingCandidate != nil },
                // ボタンの action が候補を確定・破棄する。ここで先に nil にすると
                // 「対戦する」の押下時にトークンを取り出せなくなる。
                set: { _ in }
            )
        ) {
            Button("対戦する") {
                guard let pairingToken = nearbyBattleDiscovery.confirmCandidate() else { return }
                onStartBattle(pairingToken)
            }
            Button("今回はやめる", role: .cancel) {
                nearbyBattleDiscovery.dismissCandidate()
            }
        } message: {
            Text("お互いに対戦受付中であることを確認しました。対戦を開始しますか？")
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
            .disabled(!discovery.isBluetoothReady && !discovery.isAccepting)

            Text(statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var statusText: String {
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
