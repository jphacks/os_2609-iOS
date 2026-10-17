# feature/timing-battle ブランチ

- 状態：PR #4 で `main` にマージ済み（`7a5a562`、2026-10-17）
- 分岐元：`4c7cff2`（PR #2 のマージ）
- 最終コミット：`84083d9`

## 目的

同じ地点にいるプレイヤー同士で遊べるタイミングバトルを追加する。
毎ターン、流れるカーソルを判定エリアで止めて攻撃し、相手の HP を先に 0 にしたほうが勝ち。
通信には Supabase を使い、接続先がないときは CPU と対戦できる。

## バトルのルール

- 対戦は 2 人。毎ターン 2 人が同時に攻撃し、2 人分の攻撃がそろったらまとめてダメージを反映する。
- ターンの初めに攻撃の種類を選ぶ。
  - **攻撃**：ふつう。
  - **強攻撃**：ダメージ 2 倍。判定エリアの幅は 0.6 倍。
- カーソルは左から右へ 1 回だけ流れる。STOP を押すたびに 1 回判定する。判定エリアの数だけ押せる。
- 判定のダメージ：PERFECT は 100、GOOD は 50、MISS は 0。
  - PERFECT が続くとコンボ倍率が付く。2 回目から 0.25 ずつ上がり、最大 2 倍。
  - コンボはターンをまたいで続く。
- PERFECT や GOOD を当てた瞬間は、カーソルが少し止まる（ヒットストップ）。
- 10 ターンで決着しなければ、残り HP の割合が多いほうの勝ち。
- モンスターごとに HP とゲージの難しさ（速さ・エリアの幅・数）が違う（`BattleProfile`）。HP が多いほどゲージが難しい。

## 追加・変更したファイル

### Models/Battle/（ルールと計算。UI や通信に依存しない）

| ファイル | 役割 |
|---|---|
| `AttackType.swift` | 攻撃の種類と、ダメージ・エリア幅の倍率 |
| `TimingJudgement.swift` | PERFECT / GOOD / MISS と基本ダメージ |
| `TimingGauge.swift` | 判定エリアの配置と、経過時間からのカーソル位置・判定の計算 |
| `BattleProfile.swift` | モンスターごとの HP とゲージの癖 |
| `BattleMove.swift` | 1 ターン分の攻撃の結果。相手にはこれだけを送る |
| `BattleState.swift` | 2 人の HP・コンボ・ターン・勝敗。`resolveTurn` で 1 ターン進める |

### ViewModel / Service

| ファイル | 役割 |
|---|---|
| `ViewModels/BattleViewModel.swift` | 画面の状態（`Phase`）とターンの進行、演出のきっかけ（`Event`） |
| `Services/BattleService.swift` | 対戦相手とのやり取りの protocol |
| `Services/DummyBattleService.swift` | 開発用。すぐに相手が見つかり、CPU がランダムに攻撃する |
| `Services/SupabaseBattleService.swift` | Supabase で相手を探し、攻撃をやり取りする |
| `Services/SupabaseConfig.swift` | Supabase の URL と anon key。空ならダミーを使う |
| `supabase/schema.sql` | `battles` / `battle_moves` テーブル、RLS、`join_battle` 関数 |

### Views

| ファイル | 役割 |
|---|---|
| `Views/Battle/BattleView.swift` | 対戦画面。ロビーと対戦中の画面を切り替える |
| `Views/Battle/BattleLobbyComponent.swift` | 相手を探す前の画面（現在地と自分のモンスター） |
| `Views/Battle/TimingGaugeComponent.swift` | ゲージとカーソル |
| `Views/Battle/HPBarComponent.swift`, `MonsterCardComponent.swift`, `BattleMessageComponent.swift`, `BattleResultComponent.swift` | HP バー、相手のカード、判定メッセージ、結果画面 |
| `Views/Battle/BattleEffects.swift` | 判定の色、振動、揺れの演出 |
| `Views/ContentView.swift` | 「バトル」タブを追加し、`BattleService` を 1 つ作って渡す |

### 構成の整理

- **View を機能ごとのフォルダに分けた。** `Map/`、`Capture/`（`Capture/AR/`）、`Battle/` の 3 つ。
- **バトル専用の Model を `Models/Battle/` にまとめた。**
- **画面の中の部品の名前を `〜Component` にそろえた。** 例：`IndoorMapView` → `IndoorMapComponent`、`LocationStatusView` → `LocationStatusComponent`。
- **パッケージを追加した。** Swift Package `supabase-swift`（`Package.resolved` も追加）。

## 通信の流れ（SupabaseBattleService）

1. **相手探し**：`join_battle(地点 ID, プレイヤー ID, モンスター名)` を呼ぶ。
   - 同じ地点で待っている部屋があれば入り、なければ自分が部屋を作って待つ。
   - 地点ごとのアドバイザリーロックで 1 人ずつ処理する。2 人が同時に呼んでも、別々の部屋で待ち続けることはない。
   - 2 分以上前の部屋は使わない。待つ側は 110 秒で諦める。
2. **攻撃の送信**：`battle_moves` に 1 ターン分を書き込む。
   - 3 回まで再試行する。
   - `upsert`（ON CONFLICT DO NOTHING）なので二重に書き込まない。
3. **相手の攻撃の受信**：Realtime で受け取る。
   - 取りこぼしや WebSocket の遮断に備えて、2 秒ごとにデータベースも直接見る。
   - 60 秒届かなければ相手がいなくなったとみなす。
4. **やめる**：`battles.status` を `finished` にする。
   - 相手待ちの部屋が残らず、対戦中なら相手にも伝わる。

プレイヤー ID はログインを使わず、アプリ起動ごとに `UUID()` で作る。

## 主な設計判断

- **ダメージは送らず、判定の結果（`BattleMove`）だけを送る。**
  - 2 人の端末が同じ入力から同じ計算をするので、結果が食い違わない。
  - そのため `BattleState` では乱数を使わない。
- **カーソルの位置を保存しない。**
  - 開始時刻からの経過時間で毎回計算する。
  - `TimelineView(.animation)` で描画し、カーソルが動いていない間は再描画を止める。
- **知らない値の入った攻撃は、行ごと受け取らない。**
  - 一部だけ捨てるとダメージ計算が相手の端末とずれるため。
- **キャンセルしても片付けは最後まで行う。**
  - `join_battle` の通信は、キャンセルされても最後まで終える。
  - 部屋の ID を受け取ってから片付けるので、サーバーに部屋が残らない。
  - 相手探しをやめた後は、片付けが終わるのを待ってからロビーに戻す（`Phase.cancellingSearch`）。
- **自分でやめたときはエラーを出さない。** キャンセル時は、投げられたエラーの種類に関係なく「対戦できませんでした」を出さない。
- **Realtime がつながらなくても対戦できる。** 会場の Wi-Fi などで WebSocket が遮断されても、定期的なデータベース確認だけで続けられる。
- **ハッカソン用にログインなしで読み書きできる。** `schema.sql` の RLS ポリシーは誰でも読み書きできる設定。本番では Supabase Auth と自分の行だけの書き込み制限が必要。

途中までは「野生のモンスターとのバトル（反撃・捕獲・怒り・逃走あり）」として作っていた。`86949a8` でプレイヤー同士の対戦に切り替え、それらの要素は削除した。

## 実機での確認手順

### CPU 相手（Supabase なし）

1. `SupabaseConfig` の `url` と `anonKey` が空のまま起動する。
2. バトルタブを開き、現在地が出ていることを確認する（シミュレータなら「入口」）。
3. 「〇〇で対戦相手を探す」を押すと、約 1.5 秒で相手が決まる。
4. 「攻撃」か「強攻撃」を選び、カーソルが判定エリアに入ったところで STOP を押す。
   - 判定の色とダメージが出る。
   - 当てたときに一瞬カーソルが止まり、振動する。
5. 相手の攻撃が届くと 2 人の HP が減り、ダメージを受けた側が揺れる。
6. 10 ターン以内にどちらかの HP が 0 になるか、10 ターン終わると結果画面が出る。

### プレイヤー同士（Supabase あり）

1. Supabase プロジェクトを作り、ダッシュボードの SQL Editor で `supabase/schema.sql` を 1 回実行する。
2. Project Settings → API の URL と anon key を `SupabaseConfig.swift` に書く。
3. 2 台の実機で起動し、同じ地点にいる状態（現在地の表示が同じ）にする。
4. 両方で「〇〇で対戦相手を探す」を押し、マッチングすることを確認する。
5. 片方が探している途中で「やめる」を押した場合：
   - ロビーに戻ることを確認する。
   - Supabase の `battles` に `waiting` の行が残っていないことを確認する。
6. 対戦中に片方がやめた場合：
   - もう片方が最大 60 秒以内に「対戦できませんでした」でロビーに戻ることを確認する。

## コミットの流れ

| まとまり | 主なコミット |
|---|---|
| バトルの土台 | `7667136` ルールとゲージ判定のモデル、`2df1181` バトル画面とタブ |
| 構成の整理 | `e5253ca` 機能ごとのフォルダ分け、`b8bd613` 部品の別ファイル化 |
| 対戦化 | `5082613` `BattleService` とダミー、`86949a8` プレイヤー同士の対戦とロビー |
| Supabase | `a8e4de6` パッケージ追加、`b423811` テーブルと関数、`2089c81` `SupabaseBattleService` |
| 通信の堅牢化 | `200b125` 待ち部屋の片付け・一時切断、`f2c5a20` 相手がやめた直後の受信、`46fc604` 片付け待ちと送信の再試行、`ce06e3b` Realtime なしでも継続、`84083d9` 同時マッチングのロック |
| 不具合修正 | `4dbedb5` カーソルが動く前の STOP、`f497e2a` 知らない判定の扱い |
| 未使用コードの整理 | `a067009`、`3d6c0fd`、`3bcded8`、`33dcc9b`、`f873850`、`58b1667` |
| 命名・状態の整理 | `3135dee` `Phase.cancellingSearch`、`13df62c` と `e5ee629` `〜Component` への改名 |
| ドキュメント | `cdc3f30` エリア幅 × 数の上限（0.86）を `BattleProfile` に記載 |

## 注意点

- `BattleProfile` の `zoneWidth × zoneCount` は 0.86 以下にする。超えるとゲージを作るときにクラッシュする。
- 自分のモンスターは対戦ごとにランダム。捕獲したモンスターから選ぶ仕組みはまだない。
