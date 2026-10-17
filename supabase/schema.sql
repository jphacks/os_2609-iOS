-- 対戦用のテーブルと関数
-- Supabase のダッシュボードの SQL Editor に全部貼り付けて実行する
-- このファイルを変えたときも、全部貼り直して実行すれば作り直せる
-- ⚠️ 実行すると、それまでの対戦のデータはすべて消える（対戦中の人がいないときに実行する）

-- 前に作ったテーブルと関数を消す（タイミングバトルで使っていた battle_moves も含む）
-- テーブルを消すと、Realtime の設定とポリシーも一緒に消える
drop table if exists battle_actions, battle_moves, battles cascade;
drop function if exists join_battle, keep_waiting, finish_battle;

-- 対戦 1 回ぶん。player1 が部屋を作って待ち、player2 が入ると始まる
-- 場所は問わず、対戦相手を待っている人どうしで対戦する
create table battles (
  id uuid primary key default gen_random_uuid(),
  -- waiting：相手待ち / playing：対戦中 / finished：終わった（途中でやめた場合も）
  status text not null default 'waiting' check (status in ('waiting', 'playing', 'finished')),
  player1_id uuid not null,
  -- モンスターのモデル名（Monster.modelName。例：'monster-bunny'）
  player1_monster text not null,
  player2_id uuid,
  player2_monster text,
  -- 勝った人のプレイヤー ID。決着がつく前や、途中でやめた対戦は null
  winner_id uuid,
  created_at timestamptz not null default now(),
  -- player1 が最後に「まだ待っている」と伝えてきた時刻（keep_waiting）。古い部屋には誰も入らない
  last_seen_at timestamptz not null default now()
);

-- 各プレイヤーの行動 1 回ぶん（Swift の BattleAction）
create table battle_actions (
  battle_id uuid not null references battles (id) on delete cascade,
  player_id uuid not null,
  -- その人の何回目の行動か（1 から）。受け取る側はこの順に反映し、抜けていたら届くまで待つ
  seq int not null,
  -- BattleAction の rawValue
  action text not null check (action in ('normalAttack', 'specialAttack')),
  created_at timestamptz not null default now(),
  primary key (battle_id, player_id, seq)
);

-- 相手が入ってきたこと・相手の行動をすぐに受け取れるように、Realtime で変更を流す
alter publication supabase_realtime add table battles, battle_actions;

-- ⚠️ ハッカソン用：ログインなしで誰でも読み書きできる設定
-- 本番で使うときは Supabase Auth でログインさせ、自分の行だけ書けるようにする
alter table battles enable row level security;
alter table battle_actions enable row level security;
create policy "誰でも対戦を読める" on battles for select using (true);
-- battles は直接書き換えさせない。部屋に入るのは join_battle、終わるのは finish_battle からだけにする
revoke update on battles from anon, authenticated;
create policy "誰でも行動を読める" on battle_actions for select using (true);
create policy "誰でも行動を送れる" on battle_actions for insert with check (true);

-- 待っている相手を探して入る（場所は問わない）。誰もいなければ自分が部屋を作って待つ
-- 2 人が同時に呼んでも、ロックで 1 人ずつ順番に処理する
-- （順番にしないと、待っている部屋がないときに 2 人とも部屋を作り、別々の部屋で待ち続けてしまう）
-- ロックはトランザクションが終わると外れるので、後の人には先の人が作った部屋が見える
-- 30 秒以上「まだ待っている」と伝えてこない部屋は、待っていた人がもういない（アプリが落ちたなど）とみなして使わない
create or replace function join_battle(p_player_id uuid, p_monster text)
returns battles
language plpgsql
security definer
set search_path = public
as $$
declare
  joined battles;
begin
  perform pg_advisory_xact_lock(hashtext('join_battle'));

  update battles
  set player2_id = p_player_id, player2_monster = p_monster, status = 'playing'
  where id = (
    select id from battles
    where status = 'waiting'
      and player1_id <> p_player_id
      and last_seen_at > now() - interval '30 seconds'
    order by created_at
    limit 1
    for update skip locked
  )
  returning * into joined;

  if found then
    return joined;
  end if;

  insert into battles (player1_id, player1_monster)
  values (p_player_id, p_monster)
  returning * into joined;
  return joined;
end;
$$;

grant execute on function join_battle to anon;

-- 部屋を作って待っている人が、まだ待っていることを伝える（アプリが 5 秒ごとに呼ぶ）
create or replace function keep_waiting(p_battle_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update battles set last_seen_at = now() where id = p_battle_id and status = 'waiting';
$$;

grant execute on function keep_waiting to anon;

-- 対戦を終える。p_winner_id を渡すと勝った人として記録し、渡さなければ（途中でやめたとき）勝者なしで終える
-- 勝者は最初に記録したものから変えない。2 人がほぼ同時にとどめを刺しても、先に記録した方の勝ちに決まる
-- 確定した勝者のプレイヤー ID を返す（勝者なしなら null）
create or replace function finish_battle(p_battle_id uuid, p_winner_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  final_winner uuid;
begin
  update battles
  set status = 'finished',
      winner_id = coalesce(
        winner_id,
        case when p_winner_id in (player1_id, player2_id) then p_winner_id end
      )
  where id = p_battle_id
  returning winner_id into final_winner;
  return final_winner;
end;
$$;

grant execute on function finish_battle to anon;
