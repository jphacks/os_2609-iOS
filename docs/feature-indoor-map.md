# feature/indoor-map ブランチ

- 状態：PR #2 で `main` にマージ済み（`4c7cff2`、2026-10-16）
- 分岐元：`438d03f`（PR #1 のマージ）
- 最終コミット：`db668cb`

## 目的

推定した現在地を屋内マップで見られるようにし、アプリをタブ構成（マップ / 捕獲）にする。
あわせて、仮の球体だったモンスターを 3D モデルに置き換える。
作業の途中でハッカソン向けの開発ルール（テストを書かない、開発用コードの印など）を固め、`CLAUDE.md` に書いている。

## 追加・変更したファイル

ブランチ終了時点のパスで書く。カッコ内は、後の `feature/timing-battle` で移動・改名した先。

| ファイル | 種類 | 役割 |
|---|---|---|
| `Models/MapPosition.swift` | 追加 | マップ上の位置を幅・高さに対する割合（0〜1）で表す。端末の画面サイズに依存しない |
| `Models/Location.swift` | 変更 | 場所 ID（`entrance` など）とマップ上の位置を持たせ、地点データをここに一本化 |
| `Models/Monster.swift` | 変更 | 3D モデル名と大きさを持たせ、24 体の一覧 `Monster.all` を追加 |
| `Resources/Models/*.usdz` | 追加 | Kenney「Cube Pets」（CC0）を変換したモンスターの 3D モデル 24 体 |
| `Views/ContentView.swift` | 変更 | マップ / 捕獲の `TabView`。`LocationViewModel` を 1 つだけ作って両方に渡す |
| `Views/MapView.swift` | 追加 | マップ画面（→ `Views/Map/MapView.swift`） |
| `Views/IndoorMapView.swift` | 追加 | 屋内マップ本体。地点の目印と現在地を描く（→ `Views/Map/IndoorMapComponent.swift`） |
| `Views/ARCaptureView.swift` | 変更 | AR 対応の判定をここに移し、タブが表示されている間だけ `ARViewContainer` を置く（→ `Views/Capture/`） |
| `Views/AR/MonsterEntity.swift` | 変更 | USDZ を非同期で読み込み、`monster.size` に縮小する（→ `Views/Capture/AR/`） |
| `Views/AR/PlaceholderMonsterEntity.swift` | 追加 | モデルが読めなかったときの緑の球体（開発用） |
| `Views/AR/ARSceneController.swift` | 変更 | モデルを読み込み終えてからアンカーをシーンに置く |
| `Services/DummyBeaconScanner.swift` | 変更 | 指定した `Location` のフィンガープリントからダミーの RSSI を作る |
| `ViewModels/ARCaptureViewModel.swift` | 変更 | 出すモンスターを `Monster.all` からランダムに選ぶ |
| `ARAppTests/`, `ARAppUITests/` | 削除 | 使っていないテストターゲット |
| `CLAUDE.md` | 変更 | 開発ルールを追記 |

## 主な設計判断

- **現在地の推定はアプリで 1 つだけ動かす。**
  - `LocationViewModel` を `ContentView` で作り、各画面に渡す。
  - 画面ごとに作ると推定が別々に動き、マップと捕獲画面で現在地が食い違うため。
- **地点データは `Location` 1 つにまとめる。**
  - 途中で作った `MapSpot` と `MapViewModel` は削除した。
  - ID・名前・マップ上の位置・フィンガープリントを `Location` に持たせ、同じデータを複数の型に重複させない。
- **タブを離れたら AR セッションを止める。**
  - `TabView` は別タブに切り替えても画面を残すので、そのままでは `dismantleUIView` が呼ばれずカメラが動き続ける。
  - `ARCaptureView` で `onAppear` / `onDisappear` を使って表示中かを持ち、表示中だけ `ARViewContainer` を置く。
- **3D モデルを読み込み終えてからアンカーを置く。**
  - USDZ の読み込みは時間がかかる。
  - 先にアンカーを置くと、平面が見つかった時点でモデルより先に「現れた！」と表示されてしまう。
  - アンカーの固定イベントは、取りこぼさないようにシーンに置く前に購読する。
- **マップは最小限にする。**
  - 途中で仮モンスター（`MonsterSpot`）、レイド地点（`RaidSpot`）、ボスゾーン、通路の表示を作った。
  - 地点と現在地だけの表示に戻し、使わなくなったものは削除した。
- **開発用コードに印を付ける。**
  - `DummyBeaconScanner`、`PlaceholderMonsterEntity`、`LocationStatusView` の先頭に「⚠️ 開発用」と削除手順を書いた。
- **シミュレータではダミーのビーコンを使う。**
  - `#if targetEnvironment(simulator)` で `DummyBeaconScanner` に切り替え、「入口」にいることにする。

## CLAUDE.md に追記したルール

- ハッカソン用のため、ユニットテストや UI テストは書かない
- 開発中だけ使うコードには「⚠️ 開発用」と削除手順を書く
- 使われていないコードは残さず削除する
- `ContentView` はタブを並べるだけにする。画面ごとの判定はその画面の中で行う
- 画面をまたぐ状態は `ContentView` で 1 つだけ作って渡す
- 同じデータを複数の型に重複して持たせない
- View の部品は必要になった時点で切り出す（目安 200 行で別ファイル）
- `TabView` の中で AR を使う画面は、表示中だけ `ARViewContainer` を置く

## 実機での確認手順

1. 実機で起動し、下に「マップ」「捕獲」のタブが出ることを確認する。
2. **マップ**：ビーコンが動いていれば、現在地の地点に人のアイコンが出て、地点名が青くなる。
3. **捕獲**：
   - 床を映すと、ランダムな動物の 3D モデル（約 20cm）が床に乗る。
   - モデルが出てから「〇〇が現れた！」と表示される。
4. 捕獲タブからマップタブに切り替えると、カメラが止まる（画面右上のカメラ使用中を示す緑の点が消える）。
5. もう一度捕獲タブに戻ると、床を探すところからやり直す。
6. シミュレータでは、マップに「入口」が現在地として出る。

## コミットの流れ

| まとまり | 主なコミット |
|---|---|
| 屋内マップの追加と整理 | `e965160` 場所 ID の追加、`840bb2b` 屋内マップ画面の追加、`755a35d` シミュレータでダミー表示、`7bd9b78` 推定の共有と `Location` への一本化 |
| AR セッションの停止 | `ecefc4e` 捕獲タブから離れたらセッションを止める |
| マップ表示の調整 | `c10f05b` ダミーを `Location` から作る・通路の定義、`06f0566` 現在地のバッジ |
| 3D モデル | `6699531` モデルと一覧を追加、`5f96f6b` AR 画面で表示、`a8dcc6f` 仮の球体を別ファイルに |
| 削って最小限にする | `599e0a5` 仮モンスターの削除、`12243fe` 地点と現在地だけの表示、`7edc667` ボスゾーンの削除、`79c8ab8` 未使用のプロパティ・引数の削除、`3defe52` テストターゲットの削除 |
| 開発用コードの印 | `7d0d814` と `8e8d3ec` |
| 不具合修正 | `db668cb` モデルより先に「現れた！」と出ないようにする |
| CLAUDE.md | `34f050c`、`73359e7`、`fa1dad8`、`d9a0e60` |
