-- ============================================================
-- Shunya Mindstream — Initial Schema (idempotent, safe to re-run)
-- Run this entire script in your Supabase SQL Editor
-- ============================================================

-- 1. Enable pgvector (gemini-embedding-001 truncated to 768 dims)
create extension if not exists vector;

-- ============================================================
-- 2. Profiles (extends auth.users, auto-created on signup)
-- ============================================================
create table if not exists profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  full_name  text not null default '',
  role       text not null default 'analyst' check (role in ('analyst', 'pm')),
  created_at timestamptz default now()
);

alter table profiles enable row level security;

drop policy if exists "Users can read own profile"               on profiles;
drop policy if exists "All authenticated users can read profiles" on profiles;
drop policy if exists "Users can update own profile"             on profiles;
drop policy if exists "Users can insert own profile"             on profiles;
drop policy if exists "Service role can manage profiles"         on profiles;

create policy "All authenticated users can read profiles"
  on profiles for select using (auth.role() = 'authenticated');

create policy "Users can update own profile"
  on profiles for update using (auth.uid() = id);

create policy "Users can insert own profile"
  on profiles for insert with check (auth.uid() = id);

-- Auto-create profile when a user signs up
create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'role', 'analyst')
  )
  on conflict (id) do update
    set full_name = excluded.full_name,
        role      = excluded.role;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ============================================================
-- 3. Prompts (PM-created recording topics)
-- ============================================================
create table if not exists prompts (
  id          uuid primary key default gen_random_uuid(),
  created_by  uuid references profiles(id) on delete set null,
  title       text not null,
  description text,
  status      text not null default 'active' check (status in ('active', 'closed')),
  deadline    timestamptz,
  created_at  timestamptz default now()
);

alter table prompts enable row level security;

drop policy if exists "Authenticated users can read prompts" on prompts;
drop policy if exists "PMs can insert prompts"              on prompts;
drop policy if exists "PMs can update prompts"              on prompts;
drop policy if exists "PMs can update own prompts"          on prompts;
drop policy if exists "Service role can manage prompts"     on prompts;

create policy "Authenticated users can read prompts"
  on prompts for select using (auth.role() = 'authenticated');

create policy "PMs can insert prompts"
  on prompts for insert
  with check (
    exists (select 1 from profiles where id = auth.uid() and role = 'pm')
  );

create policy "PMs can update prompts"
  on prompts for update
  using (exists (select 1 from profiles where id = auth.uid() and role = 'pm'));

-- ============================================================
-- 4. Recordings
-- ============================================================
create table if not exists recordings (
  id            uuid primary key default gen_random_uuid(),
  analyst_id    uuid not null references profiles(id) on delete cascade,
  type          text not null check (type in ('freeform', 'prompted')),
  prompt_id     uuid references prompts(id) on delete set null,
  transcript    text not null,
  embedding     vector(768),
  duration_secs int,
  word_count    int,
  created_at    timestamptz default now()
);

alter table recordings enable row level security;

drop policy if exists "Analysts can insert own recordings" on recordings;
drop policy if exists "Analysts can read own recordings"   on recordings;
drop policy if exists "PMs can read all recordings"        on recordings;
drop policy if exists "Service role can manage recordings" on recordings;

create policy "Analysts can insert own recordings"
  on recordings for insert with check (analyst_id = auth.uid());

create policy "Analysts can read own recordings"
  on recordings for select using (analyst_id = auth.uid());

create policy "PMs can read all recordings"
  on recordings for select
  using (exists (select 1 from profiles where id = auth.uid() and role = 'pm'));

-- HNSW index for fast cosine similarity search
create index if not exists recordings_embedding_hnsw_idx
  on recordings using hnsw (embedding vector_cosine_ops);

-- ============================================================
-- 5. Vector similarity search RPC
-- ============================================================
create or replace function match_recordings(
  query_embedding  vector(768),
  match_threshold  float       default 0.45,
  match_count      int         default 20,
  filter_from      timestamptz default null,
  filter_to        timestamptz default null,
  filter_prompt_id uuid        default null
)
returns table (
  id            uuid,
  analyst_id    uuid,
  type          text,
  prompt_id     uuid,
  transcript    text,
  duration_secs int,
  word_count    int,
  created_at    timestamptz,
  similarity    float
)
language plpgsql security definer as $$
begin
  return query
  select
    r.id, r.analyst_id, r.type, r.prompt_id, r.transcript,
    r.duration_secs, r.word_count, r.created_at,
    1 - (r.embedding <=> query_embedding) as similarity
  from recordings r
  where 1 - (r.embedding <=> query_embedding) > match_threshold
    and (filter_from      is null or r.created_at >= filter_from)
    and (filter_to        is null or r.created_at <= filter_to)
    and (filter_prompt_id is null or r.prompt_id = filter_prompt_id)
  order by similarity desc
  limit match_count;
end;
$$;

-- Grant authenticated users the right to call the RPC
grant execute on function match_recordings to authenticated;

-- ============================================================
-- 6. Audio storage column
-- ============================================================
alter table recordings add column if not exists audio_path text;

-- ============================================================
-- 7. Supabase Storage — recordings bucket policies
-- NOTE: First create a PRIVATE bucket named 'recordings' in
--       Supabase Dashboard → Storage → New bucket
-- Then run these policies:
-- ============================================================
drop policy if exists "Analysts can upload own audio"       on storage.objects;
drop policy if exists "Authenticated can read audio"        on storage.objects;
drop policy if exists "Analysts can delete own audio"       on storage.objects;

create policy "Analysts can upload own audio"
  on storage.objects for insert
  with check (
    bucket_id = 'recordings'
    and auth.role() = 'authenticated'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Authenticated can read audio"
  on storage.objects for select
  using (
    bucket_id = 'recordings'
    and auth.role() = 'authenticated'
  );

create policy "Analysts can delete own audio"
  on storage.objects for delete
  using (
    bucket_id = 'recordings'
    and auth.role() = 'authenticated'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ============================================================
-- 8. Meeting Notes
-- ============================================================
create table if not exists meeting_notes (
  id           uuid primary key default gen_random_uuid(),
  analyst_id   uuid not null references profiles(id) on delete cascade,
  client_name  text not null,
  meeting_date date not null,
  transcript   text not null,
  audio_path   text,
  mom          text,           -- minutes of meeting (markdown, editable before confirm)
  status       text not null default 'draft' check (status in ('draft', 'confirmed')),
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

alter table meeting_notes enable row level security;

drop policy if exists "Analysts can manage own meeting notes"  on meeting_notes;
drop policy if exists "PMs can read all meeting notes"         on meeting_notes;

create policy "Analysts can manage own meeting notes"
  on meeting_notes for all using (analyst_id = auth.uid());

create policy "PMs can read all meeting notes"
  on meeting_notes for select
  using (exists (select 1 from profiles where id = auth.uid() and role = 'pm'));
