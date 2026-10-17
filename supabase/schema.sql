-- 対戦用のテーブルと関数
-- Supabase のダッシュボードの SQL Editor に貼り付けて、一度だけ実行する

-- 対戦 1 回ぶん。player1 が部屋を作って待ち、player2 が入ると始まる
create table battles (
  id uuid primary key default gen_random_uuid(),
  -- 対戦する地点の ID（Location.id と同じ。例：'entrance'）
  location_id text not null,
  -- waiting：相手待ち / playing：対戦中 / finished：終わった（途中でやめた場合も）
  status text not null default 'waiting' check (status in ('waiting', 'playing', 'finished')),
  player1_id uuid not null,
  -- モンスターのモデル名（Monster.modelName。例：'animal-cat'）
  player1_monster text not null,
  player2_id uuid,
  player2_monster text,
  created_at timestamptz not null default now()
);

-- 各プレイヤーの 1 ターンぶんの攻撃（Swift の BattleMove）
create table battle_moves (
  battle_id uuid not null references battles (id) on delete cascade,
  player_id uuid not null,
  turn int not null,
  -- 'normal' / 'strong'（AttackType の rawValue）
  attack_type text not null,
  -- 'perfect' / 'good' / 'miss' の配列（TimingJudgement の rawValue）
  judgements text[] not null,
  created_at timestamptz not null default now(),
  primary key (battle_id, player_id, turn)
);

-- 相手が入ってきたこと・相手の攻撃をすぐに受け取れるように、Realtime で変更を流す
alter publication supabase_realtime add table battles, battle_moves;

-- ⚠️ ハッカソン用：ログインなしで誰でも読み書きできる設定
-- 本番で使うときは Supabase Auth でログインさせ、自分の行だけ書けるようにする
alter table battles enable row level security;
alter table battle_moves enable row level security;
create policy "誰でも対戦を読める" on battles for select using (true);
create policy "誰でも対戦を終われる" on battles for update using (true);
create policy "誰でも攻撃を読める" on battle_moves for select using (true);
create policy "誰でも攻撃を送れる" on battle_moves for insert with check (true);

-- 同じ地点で待っている相手を探して入る。誰もいなければ自分が部屋を作って待つ
-- 同じ地点で 2 人が同時に呼んでも、地点ごとのロックで 1 人ずつ順番に処理する
-- （順番にしないと、待っている部屋がないときに 2 人とも部屋を作り、別々の部屋で待ち続けてしまう）
-- ロックはトランザクションが終わると外れるので、後の人には先の人が作った部屋が見える
-- 2 分以上前に作られた部屋は、待っていた人がもういないとみなして使わない
create or replace function join_battle(p_location_id text, p_player_id uuid, p_monster text)
returns battles
language plpgsql
security definer
set search_path = public
as $$
declare
  joined battles;
begin
  perform pg_advisory_xact_lock(hashtext(p_location_id));

  update battles
  set player2_id = p_player_id, player2_monster = p_monster, status = 'playing'
  where id = (
    select id from battles
    where status = 'waiting'
      and location_id = p_location_id
      and player1_id <> p_player_id
      and created_at > now() - interval '2 minutes'
    order by created_at
    limit 1
    for update skip locked
  )
  returning * into joined;

  if found then
    return joined;
  end if;

  insert into battles (location_id, player1_id, player1_monster)
  values (p_location_id, p_player_id, p_monster)
  returning * into joined;
  return joined;
end;
$$;

grant execute on function join_battle to anon;
