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
