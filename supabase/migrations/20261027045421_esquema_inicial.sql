-- =========================================================
-- Tablas
-- =========================================================
create table public.pairs (
  id uuid primary key default gen_random_uuid(),
  invite_code text unique not null,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  pair_id uuid references public.pairs(id) on delete set null,
  fcm_token text,
  created_at timestamptz not null default now()
);

create type public.garment_category as enum
  ('ropa_interior', 'remeras', 'pantalones', 'buzos',
   'abrigos', 'calzado', 'accesorios', 'otros');

create table public.garments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  pair_id uuid not null references public.pairs(id) on delete cascade,
  name text not null,
  category public.garment_category not null,
  color text,
  photo_path text,
  at_partner_home boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.garment_movements (
  id bigint generated always as identity primary key,
  garment_id uuid not null references public.garments(id) on delete cascade,
  action text not null check (action in ('dejada', 'retirada')),
  created_at timestamptz not null default now()
);

create table public.confirmation_requests (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs(id) on delete cascade,
  requester_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pendiente'
    check (status in ('pendiente', 'confirmado', 'discrepancia')),
  note text,
  created_at timestamptz not null default now()
);

-- =========================================================
-- Función auxiliar: pareja del usuario autenticado
-- =========================================================
create or replace function public.my_pair_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select pair_id from public.profiles where id = auth.uid();
$$;

-- =========================================================
-- Perfil automático al registrarse
-- =========================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name',
             split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =========================================================
-- Crear pareja y unirse mediante código
-- =========================================================
create or replace function public.create_pair()
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_code text;
  v_pair uuid;
begin
  if public.my_pair_id() is not null then
    raise exception 'El usuario ya pertenece a una pareja';
  end if;

  v_code := upper(substr(md5(random()::text), 1, 6));
  insert into public.pairs (invite_code) values (v_code)
    returning id into v_pair;
  update public.profiles set pair_id = v_pair where id = auth.uid();
  return v_code;
end;
$$;

create or replace function public.join_pair(p_code text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_pair uuid;
  v_count int;
begin
  if public.my_pair_id() is not null then
    raise exception 'El usuario ya pertenece a una pareja';
  end if;

  select id into v_pair from public.pairs
    where invite_code = upper(trim(p_code));
  if v_pair is null then
    raise exception 'Código de invitación inválido';
  end if;

  select count(*) into v_count from public.profiles where pair_id = v_pair;
  if v_count >= 2 then
    raise exception 'La pareja ya tiene dos integrantes';
  end if;

  update public.profiles set pair_id = v_pair where id = auth.uid();
end;
$$;

-- =========================================================
-- Registro automático de movimientos y fecha de modificación
-- =========================================================
create or replace function public.on_garment_update()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.at_partner_home is distinct from old.at_partner_home then
    insert into public.garment_movements (garment_id, action)
    values (new.id,
            case when new.at_partner_home then 'dejada' else 'retirada' end);
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_garment_update
  before update on public.garments
  for each row execute function public.on_garment_update();

-- =========================================================
-- Row Level Security
-- =========================================================
alter table public.pairs                 enable row level security;
alter table public.profiles              enable row level security;
alter table public.garments              enable row level security;
alter table public.garment_movements     enable row level security;
alter table public.confirmation_requests enable row level security;

create policy "pairs_select_own" on public.pairs
  for select using (id = public.my_pair_id());

create policy "profiles_select" on public.profiles
  for select using (id = auth.uid() or pair_id = public.my_pair_id());
create policy "profiles_update_own" on public.profiles
  for update using (id = auth.uid());

create policy "garments_select_pair" on public.garments
  for select using (pair_id = public.my_pair_id());
create policy "garments_insert_own" on public.garments
  for insert with check (owner_id = auth.uid()
                         and pair_id = public.my_pair_id());
create policy "garments_update_own" on public.garments
  for update using (owner_id = auth.uid());
create policy "garments_delete_own" on public.garments
  for delete using (owner_id = auth.uid());

create policy "movements_select_pair" on public.garment_movements
  for select using (exists (
    select 1 from public.garments g
    where g.id = garment_id and g.pair_id = public.my_pair_id()));

create policy "confirm_select_pair" on public.confirmation_requests
  for select using (pair_id = public.my_pair_id());
create policy "confirm_insert_own" on public.confirmation_requests
  for insert with check (requester_id = auth.uid()
                         and pair_id = public.my_pair_id());
create policy "confirm_update_pair" on public.confirmation_requests
  for update using (pair_id = public.my_pair_id());

-- =========================================================
-- Realtime
-- =========================================================
alter publication supabase_realtime add table public.garments;
alter publication supabase_realtime add table public.confirmation_requests;