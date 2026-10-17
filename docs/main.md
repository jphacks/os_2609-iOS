# main ブランチ

最終確認時点：`7a5a562`（2026-10-17、PR #4 のマージ）

## 目的

ハッカソン向けの iOS アプリ「AR モンスター捕獲」の統合ブランチ。
屋内の現在地を BLE ビーコンの RSSI から推定し、マップ表示・AR での捕獲・同じ地点にいるプレイヤーとの対戦を 1 つのアプリにまとめている。

各機能は feature ブランチで作り、PR でマージしている。

| PR | ブランチ | 内容 | ドキュメント |
|---|---|---|---|
| #1 | `feature/location-estimation` | ビーコンの RSSI から現在地を推定する | [feature-location-estimation.md](feature-location-estimation.md) |
| #2 | `feature/indoor-map` | 屋内マップ画面、3D モデルのモンスター、タブ構成 | [feature-indoor-map.md](feature-indoor-map.md) |
| #4 | `feature/timing-battle` | タイミングバトル（Supabase でのプレイヤー対戦） | [feature-timing-battle.md](feature-timing-battle.md) |
| jphacks #2 | `feature/supabase-connection` | リアルタイムバトルに置き換え、Supabase で対戦（`feature/realtime-battle` を含む） | [feature-supabase-connection.md](feature-supabase-connection.md) |

バトルのルールと通信の決まりは [battle.md](battle.md) にまとめている（Android も同じ決まりで実装する）。

## main に直接積んだ土台（feature ブランチ以前）

| コミット | 内容 |
|---|---|
| `786bb36` | Xcode のプロジェクトテンプレート |
| `e24f0c8` | Step 1：RealityKit の `ARView` でカメラ映像を表示 |
| `85e924b` | MVVM のフォルダ構成と、アーキテクチャを CLAUDE.md に記載 |
| `d284958` | Step 2：床に仮の 3D モンスター（緑の球体）を表示 |
| `99f77e6` | AR まわりを責務ごとに分割（`ARViewContainer` / `ARSceneController` / `MonsterEntity`） |

`99f77e6` で決めた AR の責務分担は、その後のブランチでもそのまま使っている。

## 現在のアプリ構成

`ContentView` は 3 つのタブを並べるだけ。

| タブ | 画面 | できること |
|---|---|---|
| マップ | `MapView` | 屋内マップに登録地点と推定した現在地を表示 |
| 捕獲 | `ARCaptureView` | 床を検出してモンスターの 3D モデルを出す。下に現在地と RSSI（開発用）を表示 |
| バトル | `BattleView` | 現在地と同じ地点にいる相手を探し、タップで攻撃し合って対戦 |

画面をまたいで使う状態は `ContentView` で 1 つだけ作り、各画面に渡す。

- `LocationViewModel`：現在地の推定。3 つのタブで共有する
- `BattleService`：対戦の通信。Supabase の接続先（`SupabaseSecrets.plist`）がなければダミー（CPU 相手）を使う

### フォルダ構成

```
ARApp/
├── App/ARAppApp.swift
├── Models/
│   ├── Location.swift, MapPosition.swift, Monster.swift
│   └── Battle/          BattleAction, BattleState, Fighter
├── Logic/               BattleEngine（バトルのルール）
├── ViewModels/          LocationViewModel, ARCaptureViewModel, BattleViewModel
├── Views/
│   ├── ContentView.swift
│   ├── Map/             MapView, IndoorMapComponent, LocationStatusComponent（開発用）
│   ├── Capture/         ARCaptureView
│   │   └── AR/          ARViewContainer, ARSceneController, MonsterEntity, PlaceholderMonsterEntity（開発用）
│   └── Battle/          BattleView と部品（〜Component）、BattleEffects
├── Services/            BeaconScanner 系、BattleService 系、SupabaseConfig
└── Resources/
    ├── Models/          モンスターの USDZ（Kenney「Cube Pets」、CC0）24 体
    └── SupabaseSecrets.plist  Supabase の接続先（.gitignore 済み。各自で置く）
supabase/schema.sql      対戦用のテーブルと join_battle / finish_battle 関数
supabase/SupabaseSecrets.example.plist  接続先のひな形
```

## 主な設計判断（全体）

- **MVVM ＋ Service 層。** ViewModel は `@Observable` で、状態は `private(set)`。`ARView` などの UIKit オブジェクトは持たせない。
- **AR の命令的な操作は `ARSceneController` に集める。** `UIViewRepresentable` の Coordinator として使う。
- **外部とのやり取りは protocol にしてダミー実装を用意する。** `BeaconScanner` と `BattleService` が該当する。ESP32 や Supabase がなくてもシミュレータとプレビューで動かせる。
- **ハッカソン用のため、テストは書かない。** テストターゲットは `feature/indoor-map` で削除した。動作はプレビューと実機で確認する。
- **開発中だけ使うコードには「⚠️ 開発用」のコメントを付ける。** 削除するときに一緒に消す場所もファイル先頭に書く。
- **View の命名を統一する。** 画面は `〜View`、画面の中の部品は `〜Component`。

細かなルールはリポジトリ直下の `CLAUDE.md` を参照。

## 実機での確認手順

1. Xcode で `ARApp.xcodeproj` を開く。Signing & Capabilities の Team を自分のものに変える。必要なら Bundle Identifier も変える。
2. iPhone を接続して Run する。
3. 初回起動時に Bluetooth の許可を求められたら許可する。
4. 3 つのタブを確認する。
   - **マップ**：ESP32 のビーコンが動いていれば現在地が出る。動いていなければ「ビーコンを探しています…」のまま。
   - **捕獲**：床を映してゆっくり動かすと、モンスターが出て「〇〇が現れた！」と表示される。
   - **バトル**：現在地が出ていれば「〇〇で対戦相手を探す」を押せる。`SupabaseSecrets.plist` がなければ CPU と対戦する。
5. シミュレータで起動した場合：
   - ダミーのビーコンで「入口」にいることになる。
   - 捕獲タブは「ARに対応していません」と表示される。

ビルドだけを確かめるときは次のコマンドを使う。

```sh
xcodebuild -project ARApp.xcodeproj -scheme ARApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## 残っている課題（コードから読み取れるもの）

- `Location.registered` の RSSI は仮の値。会場で測って置き換える必要がある。
- 実際に対戦するには、`supabase/SupabaseSecrets.example.plist` を `ARApp/Resources/SupabaseSecrets.plist` にコピーし、URL と anon key を書く（鍵はメンバーから受け取る）。
- 捕獲画面はモンスターを出すところまで。タップして捕獲する処理はまだない。
- バトルで使うモンスターはランダム。捕獲したモンスターから選ぶ仕組みはない。
