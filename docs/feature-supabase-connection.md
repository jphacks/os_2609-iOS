# feature/supabase-connection ブランチ

- 状態：jphacks/os_2609-iOS の PR #2 でレビュー中
- 分岐元：`84083d9`（`feature/timing-battle` の最終コミット）
- 取り込んだブランチ：`feature/realtime-battle`（`319a9c5` でマージ）、`main`（`661f719` でマージ）

## 目的

バトルを、タイミングバトルから **タップで攻撃し合うリアルタイムバトル** に置き換え、Supabase で同じ地点にいる人と対戦できるようにする。
あわせて、公開リポジトリに Supabase の鍵を載せないようにする。

バトルのルールと通信の決まりは [battle.md](battle.md) にまとめた。この文書は、このブランチで何を変えたかの記録。

## 変更したこと

### Supabase の接続先を plist に分けた（`8565741`）

- URL と anon key は `ARApp/Resources/SupabaseSecrets.plist` に書く。`.gitignore` に入れている。
- ひな形は `supabase/SupabaseSecrets.example.plist`。
- plist がない、または値が空なら、CPU と対戦する（`DummyBattleService`）。鍵を持っていないメンバーも、ビルドして動かせる。
- `SupabaseConfig.swift` は、コードに値を書く形から、plist を読む形に変えた。

### リアルタイムバトルを取り込んだ（`319a9c5`）

`feature/realtime-battle`（分岐元は `438d03f`、PR #1 のマージ）をマージした。このブランチでは次のものを作っていた。

- タップで通常攻撃、ゲージが満タンになったら必殺技
- ダメージの数字、揺れ、踏み込み、画面が光る演出
- ルールを状態から切り離した `RealtimeBattleEngine` と、相手を差し替えられる `BattleOpponent`

タイミングバトルが入る前の `main` から分かれていたので、マージの時点では両方のバトルをタブに並べた。

### タイミングバトルを置き換えて、Supabase に対応させた（`5269347`）

- タイミングバトルの画面とモデルを削除した（`AttackType`、`BattleMove`、`BattleProfile`、`TimingGauge`、`TimingJudgement`、`TimingGaugeComponent`、`BattleMessageComponent`）。
- リアルタイムバトルのファイルを、今のフォルダ構成と名前のルールに合わせて移した。

| 移す前 | 移した後 |
|---|---|
| `Logic/RealtimeBattleEngine.swift` | `Logic/BattleEngine.swift` |
| `Models/BattleAction.swift` | `Models/Battle/BattleAction.swift` |
| `Models/RealtimeFighter.swift` | `Models/Battle/Fighter.swift` |
| `Models/RealtimeBattleState.swift` | `Models/Battle/BattleState.swift` |
| `ViewModels/RealtimeBattleViewModel.swift` | `ViewModels/BattleViewModel.swift`（相手探しの流れはタイミングバトルのものを使う） |
| `Views/RealtimeBattleView.swift` | `Views/Battle/BattleView.swift` と部品（`StatBarComponent`、`FighterImageComponent`、`BattleResultComponent`、`BattleEffects`） |
| `Services/BattleOpponent.swift`、`LocalAIOpponent.swift` | `Services/BattleService.swift`、`DummyBattleService.swift` にまとめた |

- `SupabaseBattleService` を書き直した。
  - 相手探しの `join_battle` と、Realtime を取りこぼしたときにデータベースを直接見る仕組みは、タイミングバトルのものを使う。
  - 行動は `battle_actions` に番号（`seq`）を付けて書き込み、受け取る側は番号順に反映する。
  - 決着は `finish_battle` で記録し、先に記録された勝者にそろえる。
- `supabase/schema.sql`：`battle_moves` をやめて `battle_actions` を足した。`battles` に `winner_id` を足し、`finish_battle` 関数を足した。`battles` はアプリから直接書き換えられないようにした。
- HP は 2 人とも 300 にした。元のリアルタイムバトルは自分 100、敵 300 だったが、オンラインでは同じ条件にしないと不公平なため。
- CPU（`DummyBattleService`）は 1 秒ごとに通常攻撃する。
- 決着後のボタンは「リトライ」から「ロビーに戻る」に変えた。同じ相手ともう一度戦う仕組みがないため。

### レビューでの修正（`6516542`、`16065e0`）

- やめた対戦の通信が遅れて届いても、次の対戦に混ざらないようにした。
- 開発用・仮のコードに、置き換える場所を書いた（`DummyBattleService`、`FighterImageComponent`、ランダムに選ぶ自分のモンスター、デバッグ用の `print`）。
- `schema.sql` は、全部貼り直して実行するだけで作り直せるようにした（先頭で前のテーブルと関数を消す）。

### main の取り込み（`661f719`）

署名の xcconfig と、ブランチの説明ドキュメントを取り込んだ。`.gitignore` は、Supabase の plist と各自の署名設定の両方を残した。

## 主な設計判断

- **ルールの計算はそれぞれの端末で行う。** サーバーで HP を計算すると、タップのたびに通信を待つことになり、反応が遅れる。Android でも同じ計算を書く必要があるので、数値と決まりは [battle.md](battle.md) にまとめた。
- **状態は「自分」「相手」ではなく ID で持つ。** 自分の行動も相手の行動も、同じ `BattleEngine.apply` で反映できるようにするため。
- **行動には番号を付けて、番号順に反映する。** Realtime の取りこぼしや、届く順番の入れ替わりがあっても、相手の端末と同じ順で計算できる。
- **勝敗はサーバーで確定させる。** HP の計算は足し算と引き算なので、反映する順番が違っても最後は同じになる。ただし、2 人がほぼ同時にとどめを刺した場合だけは、端末ごとに勝者が変わる。そこで `finish_battle` で先に記録した方にそろえる。
- **決着を記録する前に、自分の行動を送り終える。** とどめの行動が相手に届く前に「終わった」と伝わらないようにするため。

## 確認手順

### CPU 相手（Supabase なし）

1. `ARApp/Resources/SupabaseSecrets.plist` を置かずに起動する。
2. バトルタブで「〇〇で対戦相手を探す」を押すと、約 1.5 秒で相手が決まる。
3. 画面をタップして攻撃する。相手（CPU）は 1 秒ごとに攻撃してくる。
4. ゲージが満タンになったら、必殺技ボタンを押す。画面が光り、50 ダメージが入る。
5. どちらかの HP が 0 になると、結果が出る。

### プレイヤー同士（Supabase あり）

1. Supabase の SQL Editor で、`supabase/schema.sql` を全部貼って実行する。
2. `supabase/SupabaseSecrets.example.plist` を `ARApp/Resources/SupabaseSecrets.plist` にコピーし、URL と anon key を書く。URL の末尾に `/rest/v1/` は付けない。
3. 別々の機種のシミュレータ 2 台（または実機 2 台）で起動し、両方で「〇〇で対戦相手を探す」を押す。
4. 片方で攻撃すると、もう片方の自分の HP が減ることを確認する。
5. 決着が、片方は「勝利！」、もう片方は「敗北…」になることを確認する。
6. Supabase の `battles` の `winner_id` に、勝った人の ID が入っていることを確認する。
