-- 会場に出現する野生のモンスター（捕獲画面）のテーブルと関数
-- Supabase のダッシュボードの SQL Editor に全部貼り付けて実行する
-- 対戦の schema.sql とは別のファイル。こちらを実行しても対戦のデータは消えない
-- このファイルを変えたときも、全部貼り直して実行すれば作り直せる
-- ⚠️ 実行すると、出現中のモンスターと捕獲の記録はすべて消える

drop table if exists wild_monsters cascade;
drop function if exists list_wild_monsters, spawn_wild_monster, capture_wild_monster;

-- 出現したモンスター 1 体ぶん。捕まったり逃げたりしても行は残す（captured_by と escapes_at で判断する）
create table wild_monsters (
  id uuid primary key default gen_random_uuid(),
  -- 出現している地点の ID（Location.id と同じ。例：'entrance'）
  location_id text not null,
  -- モンスターのモデル名（Monster.modelName。例：'animal-cat'）
  monster text not null,
  spawned_at timestamptz not null default now(),
  -- この時刻を過ぎると逃げる
  escapes_at timestamptz not null default now() + interval '3 minutes',
  -- 捕まえた人のプレイヤー ID。まだ捕まっていなければ null
  captured_by uuid,
  captured_at timestamptz
);

-- ⚠️ ハッカソン用：ログインなしで誰でも使える設定
-- テーブルは直接読み書きさせず、下の関数からだけ使う（RLS を有効にしてポリシーを作らないと、直接は何もできない）
alter table wild_monsters enable row level security;

-- 今会場にいるモンスター（まだ捕まっておらず、逃げていない）
-- 逃げるまでの残り秒数を返す。端末の時計がずれていても、逃げる時刻がそろうようにするため
create or replace function list_wild_monsters()
returns table (id uuid, location_id text, monster text, seconds_left double precision)
language sql
stable
security definer
set search_path = public
as $$
  select w.id, w.location_id, w.monster, extract(epoch from w.escapes_at - now())::double precision
  from wild_monsters w
  where w.captured_by is null and w.escapes_at > now()
  order by w.spawned_at;
$$;

-- 地点にモンスターを出す。出す地点とモンスターは端末が選び、出してよいかはここで決める
-- 次のどれかに当てはまるときは何もしない
-- ・前の出現から 30 秒経っていない（遊んでいる端末の数が増えても、出現の頻度が変わらないように）
-- ・会場全体で 2 体いる
-- ・その地点にもういる
-- 何台の端末から同時に呼ばれても、ロックで 1 台ずつ順番に処理する
create or replace function spawn_wild_monster(p_location_id text, p_monster text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform pg_advisory_xact_lock(hashtext('spawn_wild_monster'));

  if exists (select 1 from wild_monsters where spawned_at > now() - interval '30 seconds') then
    return;
  end if;
  if (select count(*) from wild_monsters where captured_by is null and escapes_at > now()) >= 2 then
    return;
  end if;
  if exists (
    select 1 from wild_monsters
    where location_id = p_location_id and captured_by is null and escapes_at > now()
  ) then
    return;
  end if;

  insert into wild_monsters (location_id, monster) values (p_location_id, p_monster);
end;
$$;

-- モンスターを捕まえる。捕まえられたら true
-- 2 人が同時に呼んでも、後の人は先の人の更新を待ってから条件を見直すので、捕まえられるのは 1 人だけ
create or replace function capture_wild_monster(p_id uuid, p_player_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update wild_monsters
  set captured_by = p_player_id, captured_at = now()
  where id = p_id and captured_by is null and escapes_at > now();
  return found;
end;
$$;

grant execute on function list_wild_monsters to anon;
grant execute on function spawn_wild_monster to anon;
grant execute on function capture_wild_monster to anon;
