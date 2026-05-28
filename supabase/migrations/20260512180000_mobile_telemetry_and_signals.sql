-- Mobile behavioral telemetry + preference signals + FCM device tokens.

create table if not exists public.user_telemetry_events (
  id bigint generated always as identity primary key,
  event_type text not null check (
    event_type in ('article_impression', 'article_click', 'dwell_time')
  ),
  article_url text not null,
  client_ts timestamptz not null default now(),
  dwell_seconds integer,
  metadata jsonb not null default '{}'::jsonb,
  session_id text,
  client_platform text,
  ingested_at timestamptz not null default now()
);

create index if not exists user_telemetry_events_client_ts_idx
  on public.user_telemetry_events (client_ts desc);

create index if not exists user_telemetry_events_article_url_idx
  on public.user_telemetry_events (article_url);

create table if not exists public.news_preference_signals (
  id bigint generated always as identity primary key,
  article_url text not null,
  liked boolean not null default false,
  more_like_this boolean not null default false,
  is_high_value_candidate boolean not null default false,
  locale text,
  tags text[] not null default '{}',
  client_ts timestamptz,
  ingested_at timestamptz not null default now()
);

create index if not exists news_preference_signals_article_url_idx
  on public.news_preference_signals (article_url);

create table if not exists public.push_device_tokens (
  id bigint generated always as identity primary key,
  token text not null unique,
  platform text not null check (platform in ('ios', 'android', 'web', 'unknown')),
  client_ts timestamptz,
  last_seen_at timestamptz not null default now()
);

create index if not exists push_device_tokens_platform_idx
  on public.push_device_tokens (platform);

alter table public.user_telemetry_events enable row level security;
alter table public.news_preference_signals enable row level security;
alter table public.push_device_tokens enable row level security;

create or replace function public.log_user_telemetry(
  events jsonb,
  session_id text default null,
  client_platform text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  ev jsonb;
  v_dwell int;
begin
  if events is null or jsonb_typeof(events) <> 'array' then
    return;
  end if;

  for ev in select value from jsonb_array_elements(events) as t(value)
  loop
    v_dwell := null;
    if ev ? 'dwell_seconds' and ev->>'dwell_seconds' is not null then
      v_dwell := (ev->>'dwell_seconds')::integer;
    end if;

    insert into public.user_telemetry_events (
      event_type,
      article_url,
      client_ts,
      dwell_seconds,
      metadata,
      session_id,
      client_platform
    ) values (
      ev->>'event_type',
      coalesce(ev->>'article_url', ''),
      coalesce((ev->>'client_ts')::timestamptz, now()),
      v_dwell,
      coalesce(ev->'metadata', '{}'::jsonb),
      session_id,
      client_platform
    );
  end loop;
end;
$$;

revoke all on function public.log_user_telemetry(jsonb, text, text) from public;
grant execute on function public.log_user_telemetry(jsonb, text, text) to anon, authenticated, service_role;
