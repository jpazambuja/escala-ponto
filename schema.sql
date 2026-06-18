-- ============================================================
--  Escala de Funcionários — esquema do banco (Supabase / Postgres)
--  Cole TODO este conteúdo no SQL Editor do Supabase e clique em "Run".
--  Pode rodar mais de uma vez sem problema (usa IF NOT EXISTS / OR REPLACE).
-- ============================================================

-- ---------- TABELAS ----------

-- Perfis: cada usuário do Supabase Auth vira um perfil.
-- role = 'gestor' (acesso total) ou 'funcionario' (só os próprios dados).
create table if not exists public.profiles (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  role        text not null default 'funcionario' check (role in ('gestor','funcionario')),
  name        text not null default '',
  cargo       text not null default '',
  login       text unique,                -- login curto usado para bater ponto (ex: "maria")
  color       text not null default '#4f9cff',
  work_shift  uuid,                       -- turno padrão de trabalho
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- Turnos de trabalho (manhã, tarde, etc.)
create table if not exists public.shifts (
  id      uuid primary key default gen_random_uuid(),
  label   text not null,
  color   text not null default '#4f9cff',
  start_t text not null default '08:00',
  end_t   text not null default '16:00',
  sort    int  not null default 0
);

-- Configurações gerais (linha única, id = 1)
create table if not exists public.settings (
  id        int primary key default 1 check (id = 1),
  min_work  int not null default 1,
  max_folga int not null default 2
);
insert into public.settings (id) values (1) on conflict (id) do nothing;

-- Escala planejada: 1 marcação por funcionário por dia.
-- value = id do turno (uuid em texto) ou 'folga' / 'falta'.
create table if not exists public.schedule (
  employee_id uuid not null references public.profiles(user_id) on delete cascade,
  day         date not null,
  value       text not null,
  primary key (employee_id, day)
);

-- Batidas de ponto (entrada/saída) com horário real.
create table if not exists public.punches (
  id          uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.profiles(user_id) on delete cascade,
  ts          timestamptz not null default now(),
  type        text not null check (type in ('in','out'))
);
create index if not exists punches_emp_ts on public.punches (employee_id, ts);

-- ---------- FUNÇÃO AUXILIAR ----------
-- Retorna true se o usuário logado é gestor (security definer evita recursão de RLS).
create or replace function public.is_gestor()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid() and p.role = 'gestor'
  );
$$;

-- ---------- SEGURANÇA (RLS) ----------
alter table public.profiles enable row level security;
alter table public.shifts   enable row level security;
alter table public.settings enable row level security;
alter table public.schedule enable row level security;
alter table public.punches  enable row level security;

-- PROFILES: cada um lê o próprio; gestor lê/gerencia todos.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select
  using (user_id = auth.uid() or public.is_gestor());
drop policy if exists profiles_admin on public.profiles;
create policy profiles_admin on public.profiles for all
  using (public.is_gestor()) with check (public.is_gestor());
-- permite o próprio usuário criar seu perfil no primeiro login (auto-cadastro do funcionário)
drop policy if exists profiles_self_insert on public.profiles;
create policy profiles_self_insert on public.profiles for insert
  with check (user_id = auth.uid());

-- SHIFTS / SETTINGS: todos autenticados leem; só gestor altera.
drop policy if exists shifts_read on public.shifts;
create policy shifts_read on public.shifts for select using (auth.role() = 'authenticated');
drop policy if exists shifts_admin on public.shifts;
create policy shifts_admin on public.shifts for all using (public.is_gestor()) with check (public.is_gestor());

drop policy if exists settings_read on public.settings;
create policy settings_read on public.settings for select using (auth.role() = 'authenticated');
drop policy if exists settings_admin on public.settings;
create policy settings_admin on public.settings for all using (public.is_gestor()) with check (public.is_gestor());

-- SCHEDULE: funcionário lê a própria escala; gestor lê e altera tudo.
drop policy if exists schedule_read on public.schedule;
create policy schedule_read on public.schedule for select
  using (employee_id = auth.uid() or public.is_gestor());
drop policy if exists schedule_admin on public.schedule;
create policy schedule_admin on public.schedule for all
  using (public.is_gestor()) with check (public.is_gestor());

-- PUNCHES: funcionário registra e lê só o próprio ponto; gestor lê tudo.
drop policy if exists punches_self_insert on public.punches;
create policy punches_self_insert on public.punches for insert
  with check (employee_id = auth.uid());
drop policy if exists punches_read on public.punches;
create policy punches_read on public.punches for select
  using (employee_id = auth.uid() or public.is_gestor());
-- (ninguém edita/apaga ponto pelo app — só inserir; gestor pode apagar via painel se precisar)
drop policy if exists punches_admin on public.punches;
create policy punches_admin on public.punches for all
  using (public.is_gestor()) with check (public.is_gestor());

-- ---------- TURNOS PADRÃO (só na primeira vez) ----------
insert into public.shifts (label, color, start_t, end_t, sort)
select * from (values
  ('Manhã', '#f5b942', '06:00', '14:00', 0),
  ('Tarde', '#ff7a59', '14:00', '22:00', 1),
  ('Noite', '#7c6cf0', '22:00', '06:00', 2)
) as v(label,color,start_t,end_t,sort)
where not exists (select 1 from public.shifts);

-- ============================================================
--  DEPOIS de criar o usuário GESTOR em Authentication > Users,
--  rode o trecho abaixo trocando o e-mail pelo que você cadastrou,
--  para marcar esse usuário como gestor:
--
--  insert into public.profiles (user_id, role, name)
--  select id, 'gestor', 'Gestor'
--  from auth.users where email = 'SEU-EMAIL-DO-GESTOR@exemplo.com'
--  on conflict (user_id) do update set role = 'gestor';
-- ============================================================
