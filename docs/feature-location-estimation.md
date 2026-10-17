# feature/location-estimation ブランチ

- 状態：PR #1 で `main` にマージ済み（`438d03f`、2026-10-12）
- 分岐元：`99f77e6`（AR まわりを責務ごとに分割）
- 最終コミット：`d5d2096`

## 目的

ESP32 が出す BLE ビーコンの電波強度（RSSI）から、屋内のどの地点にいるかを推定する。
将来の「近くにいるときだけ捕獲できる」「同じ場所にいる人と対戦する」といった判定の土台になる。

## 追加・変更したファイル

| ファイル | 種類 | 役割 |
|---|---|---|
| `Models/Location.swift` | 追加 | 地点と、その地点で測った RSSI のパターン（フィンガープリント）。ビーコン名の並び順 `beaconNames` もここで決める |
| `Services/BeaconScanner.swift` | 追加 | ビーコン受信の protocol。受信のたびに `onReceive(名前, RSSI)` を呼ぶ |
| `Services/BLEBeaconScanner.swift` | 追加 | CoreBluetooth での実装。ESP32 の Service UUID を広告しているデバイスだけを受信する |
| `Services/DummyBeaconScanner.swift` | 追加 | ESP32 がないとき用。決まった RSSI に ±3 の揺れを足して 200ms ごとに流す |
| `ViewModels/LocationViewModel.swift` | 追加 | 受信した RSSI から現在地を推定する |
| `Views/LocationStatusView.swift` | 追加 | 推定した現在地と、元になった RSSI を表示する |
| `Views/ARCaptureView.swift` | 変更 | AR 画面の下に `LocationStatusView` を重ね、表示中だけ推定を動かす |
| `project.pbxproj` | 変更 | `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription`（Bluetooth の利用目的）を追加 |

その後のブランチで、ファイルの場所や名前が次のように変わった。

- `LocationStatusView` → `Views/Map/LocationStatusComponent.swift`
- `ARCaptureView` → `Views/Capture/ARCaptureView.swift`

## 推定の仕組み

`LocationViewModel` は次のことを行う。

1. `BeaconScanner` から受信した RSSI を、ビーコンごとに時刻付きで記録する。`Location.beaconNames` にないビーコンは無視する。
2. 1 秒ごとに次の手順で推定し直す。
   - 直近 3 秒より古い記録を捨てる（スライディングウィンドウ）。
   - ビーコンごとに RSSI の中央値を取る。1 回も受信できなかったビーコンは -100 とする。
   - 登録地点のフィンガープリントとのユークリッド距離が一番小さい地点を現在地にする。
3. 1 台も受信できていない間は、現在地を `nil` にして「ビーコンを探しています…」と表示する。

## 主な設計判断

- **フィンガープリント方式。** RSSI を距離に換算する三点測位ではなく、「その場所で測った RSSI の並び」と照合する。屋内は反射が多く距離換算が不安定なため。
- **中央値を使う。** RSSI は揺れや外れ値が大きいので、平均ではなく中央値を使う。
- **スキャナーを protocol にする。** `LocationViewModel` は `BeaconScanner` を外から受け取る。ESP32 がなくてもダミーで開発できる。
- **重複受信を許可する。** CoreBluetooth は既定で同じデバイスの通知を 1 回にまとめる。RSSI を受信のたびに知りたいので `CBCentralManagerScanOptionAllowDuplicatesKey` を有効にしている。
- **RSSI を画面に出す。** 地点を登録するときは、会場の各地点で表示された値を控えて `Location.registered` に書き写す。

## 実機での確認手順

1. ESP32 を 4 台用意し、`BeaconA`〜`BeaconD` という名前で、`BLEBeaconScanner.serviceUUID` と同じ Service UUID を広告させる。
2. 実機で起動し、Bluetooth の利用を許可する。
3. AR 画面の下に「現在地：〇〇」と `RSSI -52, -67, ...` が出ることを確認する。
4. 場所を移動して、数秒以内に現在地が切り替わることを確認する。
5. ESP32 がない場合は、Xcode のプレビューで `LocationStatusView`（今は `LocationStatusComponent`）を開くと、ダミーの値で動きを確かめられる。

## コミットの流れ

| コミット | 内容 |
|---|---|
| `99c065b` | 地点と RSSI フィンガープリントのモデルを追加 |
| `56dbdab` | ビーコンをスキャンする Service を追加（CoreBluetooth 実装とダミー実装） |
| `31f9936` | RSSI から現在地を推定する `LocationViewModel` を追加 |
| `d5d2096` | AR 画面に推定した現在地と RSSI を表示 |

## 注意点

- `Location.registered` の RSSI は仮の値のまま。会場で測った値に置き換える必要がある。
- このブランチ時点の地点名（受付・展示エリアA など）は、`feature/indoor-map` で入口・ブースA などに変わっている。
