# 近距離対戦の設定と検証

既存の Supabase プロジェクトは、対戦中の利用者がいないときに SQL Editor で次の順に実行します。

1. `migrations/20261018_nearby_battle_pairing.sql`（適用済みなら不要）
2. `migrations/20261018_nearby_battle_consent.sql`

新規環境は `schema.sql` を実行します。既存環境での `schema.sql` の再実行は対戦データを削除するため、移行ファイルを使ってください。
アプリには `Resources/SupabaseSecrets.plist` の接続設定が必要です。

BLE は受付ごとに生成するセッション ID の交換に使います。サーバーが両端末を排他的に確保してから確認画面を表示し、双方の承諾後に対戦を開始します。
確認期限はペア確保から30秒です。辞退・受付OFF・マップからの移動・バックグラウンド移行は保留中のペアをキャンセルします。
通信断や強制終了でキャンセルを送れない場合も期限で解放します。双方承諾後の対戦相手待ちにも30秒の期限があります。
Bluetooth のシステム確認画面で一時的に inactive になっただけでは受付を停止しません。

SQL の回帰テストは、PostgreSQL を実行する PGlite を一時ディレクトリにインストールして実行できます。

```sh
npm install --prefix /tmp/os2609-pairing-tests @electric-sql/pglite
PGLITE_MODULE=file:///tmp/os2609-pairing-tests/node_modules/@electric-sql/pglite/dist/index.js node --test scripts/nearby_pairing.test.mjs
```

実機では2台で双方承諾・片方辞退・30秒の無応答・受付OFFを確認し、3台以上で同時受付して別々のペアで待ち続けないことを確認してください。
