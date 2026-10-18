-- 対戦用のテーブルと関数
-- Supabase のダッシュボードの SQL Editor に全部貼り付けて実行する
-- このファイルを変えたときも、全部貼り直して実行すれば作り直せる
-- ⚠️ 実行すると、それまでの対戦のデータはすべて消える（対戦中の人がいないときに実行する）

-- 前に作ったテーブルと関数を消す（タイミングバトルで使っていた battle_moves も含む）
-- テーブルを消すと、Realtime の設定とポリシーも一緒に消える
drop table if exists nearby_pairs, nearby_receivers, battle_actions, battle_moves, battles cascade;
drop function if exists join_battle, keep_waiting, finish_battle, check_battle_action, nearby_pair;

-- 対戦 1 回ぶん。player1 が部屋を作って待ち、player2 が入ると始まる
-- 場所は問わず、対戦相手を待っている人どうしで対戦する
create table battles (
  id uuid primary key default gen_random_uuid(),
  -- waiting：相手待ち / playing：対戦中 / finished：終わった（途中でやめた場合も）
  status text not null default 'waiting' check (status in ('waiting', 'playing', 'finished')),
  player1_id uuid not null,
  -- モンスターのモデル名（Monster.modelName。例：'monster-bunny'）
  player1_monster text not null,
  -- BLE で相互認識した 2 台だけが共有する、一回限りの対戦トークン
  pairing_token uuid not null,
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
  -- takeSpecial / dodgeSpecial は、相手の必殺技を受けた・よけたという結果（撃たれた側が送る）
  action text not null check (action in ('normalAttack', 'specialAttack', 'fever', 'feverAttack', 'takeSpecial', 'dodgeSpecial')),
  created_at timestamptz not null default now(),
  primary key (battle_id, player_id, seq)
);

-- フィーバーが正しく使われているかを、書き込む前に確かめる
-- アプリを書き換えて、ゲージが溜まっていないのにフィーバーしたり、ダメージ 2 倍の攻撃を出し続けたりできないようにする
-- - fever：前のフィーバーのあとに、通常攻撃（normalAttack）を 5 回以上している（BattleEngine の feverMinAttacks）
--   フィーバーになるかはアプリの中の抽選（FeverLottery）で決めるので、サーバーは続けてフィーバーしていないことだけを確かめる
-- - feverAttack：最後のフィーバーから 5 秒以内（BattleEngine の feverDuration）
--   送るのが遅れることがあるので 3 秒の余裕を持たせる
-- 確かめられないときは書き込みを断る。断られたアプリは、送れなかったとして対戦をやめる
create or replace function check_battle_action()
returns trigger
language plpgsql
as $$
declare
  last_fever battle_actions;
begin
  -- 書き込めたのに返事が届かず、同じ行を送り直してきたときは、もう確かめ終わっているので通す（書き込みは ON CONFLICT で無視される）
  if exists (
    select 1 from battle_actions
    where battle_id = new.battle_id and player_id = new.player_id and seq = new.seq
  ) then
    return new;
  end if;

  if new.action not in ('fever', 'feverAttack') then
    return new;
  end if;

  select * into last_fever from battle_actions
  where battle_id = new.battle_id and player_id = new.player_id and action = 'fever' and seq < new.seq
  order by seq desc
  limit 1;

  if new.action = 'fever' then
    if (
      select count(*) from battle_actions
      where battle_id = new.battle_id and player_id = new.player_id and action = 'normalAttack'
        and seq < new.seq and seq > coalesce(last_fever.seq, 0)
    ) < 5 then
      raise exception '前のフィーバーから通常攻撃をしていません';
    end if;
  elsif last_fever.seq is null or last_fever.created_at < now() - interval '8 seconds' then
    raise exception 'フィーバー中ではありません';
  end if;
  return new;
end;
$$;

create trigger check_battle_action
before insert on battle_actions
for each row execute function check_battle_action();

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

-- BLE で相互認識した、同じ pairing_token の相手だけを探して入る。誰もいなければ自分が部屋を作って待つ
-- 2 人が同時に呼んでも、ロックで 1 人ずつ順番に処理する
-- （順番にしないと、待っている部屋がないときに 2 人とも部屋を作り、別々の部屋で待ち続けてしまう）
-- ロックはトランザクションが終わると外れるので、後の人には先の人が作った部屋が見える
-- 10 秒以上「まだ待っている」と伝えてこない部屋は、待っていた人がもういない（アプリが落ちたなど）とみなして使わない
-- 長くすると、待っていた人がいなくなった部屋に入って、動かない相手と対戦してしまう
create or replace function join_battle(p_player_id uuid, p_monster text, p_pairing_token uuid)
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
      and pairing_token = p_pairing_token
      and last_seen_at > now() - interval '10 seconds'
    order by created_at
    limit 1
    for update skip locked
  )
  returning * into joined;

  if found then
    return joined;
  end if;

  insert into battles (player1_id, player1_monster, pairing_token)
  values (p_player_id, p_monster, p_pairing_token)
  returning * into joined;
  return joined;
end;
$$;

grant execute on function join_battle(uuid, text, uuid) to anon;

-- 部屋を作って待っている人が、まだ待っていることを伝える（アプリが 3 秒ごとに呼ぶ）
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

-- 20261018_nearby_battle_pairing.sql の後に実行する。
-- BLE は候補の発見にのみ使い、確保・承諾・辞退はこの RPC で共有する。
create table if not exists nearby_receivers (
  session_id uuid primary key,
  last_seen_at timestamptz not null default now(),
  enabled boolean not null default true
);
create table if not exists nearby_pairs (
  id uuid primary key default gen_random_uuid(),
  session1 uuid not null,
  session2 uuid not null check (session1 <> session2),
  accepted1 boolean not null default false,
  accepted2 boolean not null default false,
  status text not null default 'pending' check (status in ('pending', 'ready', 'cancelled', 'expired')),
  expires_at timestamptz not null default (now() + interval '30 seconds')
);
alter table nearby_receivers enable row level security;
alter table nearby_pairs enable row level security;
revoke all on nearby_receivers, nearby_pairs from anon, authenticated;

create or replace function nearby_pair(
  p_session uuid, p_action text, p_peer uuid default null, p_token uuid default null
)
returns setof nearby_pairs
language plpgsql
security definer
set search_path = public
as $$
declare
  paired nearby_pairs;
begin
  if p_session is null or p_action not in ('poll', 'offer', 'accept', 'stop') or p_action is null then
    raise exception 'Invalid pairing request';
  end if;
  -- A→B、B→C、C→A が同時でも、各端末を確保する処理は必ず直列化する。
  perform pg_advisory_xact_lock(hashtext('nearby_pair'));
  update nearby_pairs set status = 'expired'
    where status in ('pending', 'ready') and expires_at <= now();

  if p_action = 'stop' then
    insert into nearby_receivers(session_id, enabled) values (p_session, false)
      on conflict (session_id) do update set enabled = false;
    update nearby_pairs set status = 'cancelled'
      where status = 'pending' and p_session in (session1, session2);
    return;
  end if;

  insert into nearby_receivers(session_id) values (p_session)
    on conflict (session_id) do update set last_seen_at = now();
  -- 停止と処理中の offer が前後しても、停止済みの受付は復活させない。
  if not (select enabled from nearby_receivers where session_id = p_session) then return; end if;

  if p_token is not null then
    select * into paired from nearby_pairs
      where id = p_token and p_session in (session1, session2);
  else
    select * into paired from nearby_pairs
      where status in ('pending', 'ready') and p_session in (session1, session2)
      limit 1;
  end if;

  if paired.id is null and p_token is null and p_action = 'offer' and p_peer is not null and p_peer <> p_session then
    -- 相手も受付中であることを確認する。別の相手と確保済みなら割り込まない。
    if exists (select 1 from nearby_receivers where session_id = p_peer and enabled
                 and last_seen_at > now() - interval '5 seconds')
       and not exists (select 1 from nearby_pairs where status in ('pending', 'ready')
                         and p_peer in (session1, session2)) then
      insert into nearby_pairs(session1, session2) values (p_session, p_peer)
        returning * into paired;
    end if;
  end if;

  if paired.id is null then return; end if;
  if paired.status = 'pending' and p_action = 'accept' and paired.id = p_token then
    update nearby_pairs set
      accepted1 = accepted1 or session1 = p_session,
      accepted2 = accepted2 or session2 = p_session
      where id = paired.id returning * into paired;
    if paired.accepted1 and paired.accepted2 then
      update nearby_pairs set status = 'ready', expires_at = now() + interval '30 seconds'
        where id = paired.id returning * into paired;
    end if;
  end if;
  return next paired;
end;
$$;
revoke all on function nearby_pair(uuid, text, uuid, uuid) from public;
grant execute on function nearby_pair(uuid, text, uuid, uuid) to anon;
