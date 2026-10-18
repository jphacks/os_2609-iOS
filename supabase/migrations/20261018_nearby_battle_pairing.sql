-- 既存の Supabase プロジェクトへ近距離対戦の制限を追加する移行。
-- schema.sql をすでに再実行している場合は不要。
-- 対戦中の利用者がいないときに、Supabase SQL Editor で 1 回だけ実行する。

alter table battles add column if not exists pairing_token uuid;

-- 旧アプリが距離を問わずマッチングする関数を使えないようにする。
drop function if exists join_battle(uuid, text);

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
