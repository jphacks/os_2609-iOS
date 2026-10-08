# ARApp

SwiftUI + ARKit + RealityKit で作る iOS 向け AR モンスター捕獲アプリ。
マップ上でモンスターを選び、AR 画面で捕獲する。将来は ESP32 の BLE RSSI で近接判定を行う。

## 開発の進め方

- Step 単位で段階的に実装する。**各 Step の完了後は必ず停止し、ユーザーが明示的に許可するまで次の Step に進まない。**
- ユーザーは ARKit / RealityKit を学習中。実装後は変更ファイルと役割、実機での確認手順を説明する。
- 不要な抽象化や複雑な設計は避ける。状態やロジックが生まれた時点で必要な層を追加する。

## アーキテクチャ：MVVM + Service 層

```
ARApp/
├── App/          エントリポイント（ARAppApp.swift）
├── Models/       データ定義のみ（例：Monster）。UI やフレームワークに依存しない
├── ViewModels/   画面の状態とロジック（@Observable）
├── Views/        SwiftUI の View、UIViewRepresentable
└── Services/     外部とのやり取り（BLE / RSSI、将来のサーバー通信）
```

空のフォルダは作らない。最初のファイルが必要になった時点でフォルダを作る。

### ルール

- **ViewModel は `@Observable` クラス**で実装する（`ObservableObject` は使わない）。
- **ViewModel に `ARView` や `UIView` などの UIKit オブジェクトを持たせない。**
  - ViewModel は「どのモンスターを出すか」「捕獲状態」などの状態だけを持つ。
  - 3D エンティティの配置、アンカー、タップ検知など ARView の命令的な操作は、`ARViewContainer` とその Coordinator が担当する。
  - ARView 側から ViewModel への通知は Coordinator 経由で行う。
- **Service は protocol で定義し、ViewModel に外から渡す。**
  - ESP32 がなくてもダミー実装で開発やテストができるようにするため。
- AR セッションのライフサイクル（`run` / `pause`）は `ARViewContainer` で管理する（`makeUIView` で run、`dismantleUIView` で pause）。

## プロジェクト設定

- Xcode のファイルシステム同期グループを使っているため、`ARApp/` 配下にファイルを置けば自動でターゲットに含まれる（pbxproj の編集は不要）。
- Info.plist は自動生成（`GENERATE_INFOPLIST_FILE = YES`）。キーを追加するときは pbxproj の `INFOPLIST_KEY_*` ビルド設定を使う。
- デプロイメントターゲットは iOS 26.2。デフォルトのアクター隔離は `MainActor`。
- AR は実機でのみ動作する。シミュレータでは非対応メッセージが表示される。

## ビルド確認

```sh
xcodebuild -project ARApp.xcodeproj -scheme ARApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

エディタの SourceKit が `UIViewRepresentable` などについて誤ったエラーを出すことがあるが、iOS 向けにビルドできれば問題ない。
