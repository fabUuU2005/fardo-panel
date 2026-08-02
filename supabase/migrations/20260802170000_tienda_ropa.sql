-- Fardo: inventario de piezas únicas, ventas y permisos.
create type public.rol_usuario as enum ('administrador', 'vendedor');
create type public.estado_prenda as enum ('disponible', 'vendida', 'apartada');

create table public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null default 'Usuario',
  rol public.rol_usuario not null default 'vendedor',
  creado_en timestamptz not null default now()
);

create table public.prendas (
  id uuid primary key default gen_random_uuid(),
  codigo text not null unique,
  nombre text not null,
  categoria text not null,
  marca text,
  talla text,
  condicion text not null,
  precio_compra numeric(12,2) not null check (precio_compra >= 0),
  precio_sugerido numeric(12,2) not null check (precio_sugerido >= 0),
  estado public.estado_prenda not null default 'disponible',
  foto_path text,
  foto_url text,
  creado_por uuid not null references auth.users(id),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.ventas (
  id uuid primary key default gen_random_uuid(),
  prenda_id uuid not null unique references public.prendas(id) on delete restrict,
  precio_compra numeric(12,2) not null,
  precio_sugerido numeric(12,2) not null,
  precio_final numeric(12,2) not null check (precio_final >= 0),
  descuento numeric(12,2) not null default 0 check (descuento >= 0),
  ganancia numeric(12,2) not null,
  fecha_venta timestamptz not null default now(),
  vendedor_id uuid not null references public.perfiles(id)
);

create index prendas_busqueda_idx on public.prendas using gin (to_tsvector('spanish', coalesce(codigo,'') || ' ' || coalesce(nombre,'') || ' ' || coalesce(marca,'') || ' ' || coalesce(categoria,'')));
create index prendas_estado_idx on public.prendas(estado);
create index ventas_fecha_idx on public.ventas(fecha_venta desc);

create or replace function public.crear_perfil()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.perfiles (id, nombre) values (new.id, coalesce(new.raw_user_meta_data ->> 'nombre', split_part(new.email, '@', 1)));
  return new;
end; $$;
revoke execute on function public.crear_perfil() from public, anon, authenticated;
create trigger al_crear_usuario after insert on auth.users for each row execute procedure public.crear_perfil();

create or replace function public.es_administrador()
returns boolean language sql stable security invoker set search_path = '' as $$
  select exists (select 1 from public.perfiles where id = (select auth.uid()) and rol = 'administrador');
$$;
revoke execute on function public.es_administrador() from public, anon, authenticated;

create sequence public.prendas_codigo_seq;
create or replace function public.asignar_codigo_prenda()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.codigo is null or new.codigo = '' then
    new.codigo := 'PRD-' || to_char(current_date, 'YYMMDD') || '-' || lpad(nextval('public.prendas_codigo_seq')::text, 4, '0');
  end if;
  new.creado_por := coalesce(new.creado_por, auth.uid());
  new.actualizado_en := now();
  return new;
end; $$;
create trigger antes_de_guardar_prenda before insert or update on public.prendas for each row execute procedure public.asignar_codigo_prenda();

-- Venta atómica: valida rol y disponibilidad, conserva precios históricos y cambia el estado.
create or replace function public.registrar_venta(p_prenda_id uuid, p_precio_final numeric)
returns uuid language plpgsql security definer set search_path = '' as $$
declare pieza public.prendas; venta_id uuid;
begin
  if auth.uid() is null then raise exception 'Sesión no autorizada'; end if;
  if not exists (select 1 from public.perfiles where id = auth.uid()) then raise exception 'Usuario no autorizado'; end if;
  select * into pieza from public.prendas where id = p_prenda_id for update;
  if not found or pieza.estado <> 'disponible' then raise exception 'La prenda ya no está disponible'; end if;
  if p_precio_final < 0 then raise exception 'El precio no puede ser negativo'; end if;
  update public.prendas set estado = 'vendida', actualizado_en = now() where id = pieza.id;
  insert into public.ventas(prenda_id, precio_compra, precio_sugerido, precio_final, descuento, ganancia, vendedor_id)
  values (pieza.id, pieza.precio_compra, pieza.precio_sugerido, p_precio_final, greatest(pieza.precio_sugerido - p_precio_final, 0), p_precio_final - pieza.precio_compra, auth.uid()) returning id into venta_id;
  return venta_id;
end; $$;
revoke execute on function public.registrar_venta(uuid, numeric) from public, anon, authenticated;
grant execute on function public.registrar_venta(uuid, numeric) to authenticated;

alter table public.perfiles enable row level security;
alter table public.prendas enable row level security;
alter table public.ventas enable row level security;
grant select, update on public.perfiles to authenticated;
grant select, insert, update, delete on public.prendas to authenticated;
grant select on public.ventas to authenticated;

create policy "Perfiles visibles a usuarios autorizados" on public.perfiles for select to authenticated using (true);
create policy "Solo administradores actualizan perfiles" on public.perfiles for update to authenticated using ((select public.es_administrador())) with check ((select public.es_administrador()));
create policy "Inventario visible a usuarios autorizados" on public.prendas for select to authenticated using (true);
create policy "Administradores crean prendas" on public.prendas for insert to authenticated with check ((select public.es_administrador()) and creado_por = (select auth.uid()));
create policy "Administradores editan prendas" on public.prendas for update to authenticated using ((select public.es_administrador())) with check ((select public.es_administrador()));
create policy "Administradores eliminan prendas" on public.prendas for delete to authenticated using ((select public.es_administrador()));
create policy "Ventas visibles a usuarios autorizados" on public.ventas for select to authenticated using (true);

insert into storage.buckets (id, name, public) values ('prendas', 'prendas', false) on conflict (id) do nothing;
create policy "Usuarios autorizados ven fotos" on storage.objects for select to authenticated using (bucket_id = 'prendas');
create policy "Administradores suben fotos" on storage.objects for insert to authenticated with check (bucket_id = 'prendas' and (select public.es_administrador()));
create policy "Administradores actualizan fotos" on storage.objects for update to authenticated using (bucket_id = 'prendas' and (select public.es_administrador())) with check (bucket_id = 'prendas' and (select public.es_administrador()));
create policy "Administradores eliminan fotos" on storage.objects for delete to authenticated using (bucket_id = 'prendas' and (select public.es_administrador()));

-- Después de crear el primer usuario, promuévelo una sola vez desde SQL Editor:
-- update public.perfiles set rol = 'administrador' where id = 'UUID_DEL_USUARIO';
