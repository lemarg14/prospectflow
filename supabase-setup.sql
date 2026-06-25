-- =====================================================================
--  ProspectFlow CRM — Schéma Supabase (à coller dans SQL Editor)
--  Tables + sécurité par rôle (admin / commercial) et par segment.
--  Exécute TOUT ce fichier d'un coup. Idempotent (réexécutable sans risque).
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- TABLES ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text default '',
  role text not null default 'commercial' check (role in ('admin','commercial')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.segments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  color text default '#7c5cff',
  created_at timestamptz not null default now()
);

-- Quel commercial a accès à quel segment
create table if not exists public.segment_access (
  segment_id uuid references public.segments(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  primary key (segment_id, user_id)
);

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  company text, contact text, role text, sector text,
  phone text, mobile text, email text, website text,
  city text, source text,
  status text not null default 'nouveau',
  priority text not null default 'froid',
  value numeric,
  followup date,
  last_contact date,
  tags text[] default '{}',
  notes jsonb default '[]'::jsonb,
  phone_key text,
  segment_id uuid references public.segments(id) on delete set null,
  assigned_to uuid references public.profiles(id) on delete set null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_leads_segment on public.leads(segment_id);
create index if not exists idx_leads_phone_key on public.leads(phone_key);
create index if not exists idx_leads_assigned on public.leads(assigned_to);
create index if not exists idx_segacc_user on public.segment_access(user_id);

-- ---------- FONCTIONS (security definer = contournent RLS, pas de récursion) ----------
create or replace function public.is_admin()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function public.has_segment(seg uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.segment_access
    where user_id = auth.uid() and segment_id = seg
  );
$$;

-- Crée automatiquement un profil à l'inscription. Le TOUT PREMIER inscrit devient admin.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare cnt int;
begin
  select count(*) into cnt from public.profiles;
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name',''),
    case when cnt = 0 then 'admin' else 'commercial' end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- ACTIVER RLS ----------
alter table public.profiles       enable row level security;
alter table public.segments       enable row level security;
alter table public.segment_access enable row level security;
alter table public.leads          enable row level security;

-- ---------- POLITIQUES : PROFILES ----------
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select
  using (id = auth.uid() or public.is_admin());

drop policy if exists profiles_admin_write on public.profiles;
create policy profiles_admin_write on public.profiles for all
  using (public.is_admin()) with check (public.is_admin());

-- ---------- POLITIQUES : SEGMENTS ----------
drop policy if exists segments_select on public.segments;
create policy segments_select on public.segments for select
  using (public.is_admin() or public.has_segment(id));

drop policy if exists segments_admin_write on public.segments;
create policy segments_admin_write on public.segments for all
  using (public.is_admin()) with check (public.is_admin());

-- ---------- POLITIQUES : SEGMENT_ACCESS ----------
drop policy if exists segacc_select on public.segment_access;
create policy segacc_select on public.segment_access for select
  using (public.is_admin() or user_id = auth.uid());

drop policy if exists segacc_admin_write on public.segment_access;
create policy segacc_admin_write on public.segment_access for all
  using (public.is_admin()) with check (public.is_admin());

-- ---------- POLITIQUES : LEADS ----------
-- Lecture : admin voit tout ; commercial voit seulement les leads des segments qu'on lui a ouverts.
drop policy if exists leads_select on public.leads;
create policy leads_select on public.leads for select
  using (
    public.is_admin()
    or (segment_id is not null and public.has_segment(segment_id))
  );

-- Modification : admin partout ; commercial seulement sur ses segments.
drop policy if exists leads_update on public.leads;
create policy leads_update on public.leads for update
  using (
    public.is_admin()
    or (segment_id is not null and public.has_segment(segment_id))
  )
  with check (
    public.is_admin()
    or (segment_id is not null and public.has_segment(segment_id))
  );

-- Ajout : admin partout ; commercial seulement dans un segment qu'il voit.
drop policy if exists leads_insert on public.leads;
create policy leads_insert on public.leads for insert
  with check (
    public.is_admin()
    or (segment_id is not null and public.has_segment(segment_id))
  );

-- Suppression : ADMIN UNIQUEMENT.
drop policy if exists leads_delete on public.leads;
create policy leads_delete on public.leads for delete
  using (public.is_admin());

-- ---------- REALTIME (rafraîchissement auto entre utilisateurs) ----------
do $$ begin
  alter publication supabase_realtime add table public.leads;
exception when others then null; end $$;

-- =====================================================================
--  FIN. Après le premier inscription (= admin), tu peux créer
--  des segments, des commerciaux, et leur ouvrir des segments.
-- =====================================================================
