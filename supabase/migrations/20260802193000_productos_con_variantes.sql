-- Dos modelos de inventario: pieza única o producto con combinaciones de color/talla.
alter table public.prendas
  add column tipo_producto text not null default 'prenda_unica' check (tipo_producto in ('prenda_unica', 'con_variantes')),
  add column color text,
  add column stock integer not null default 1 check (stock >= 0);

create table public.prenda_variantes (
  id uuid primary key default gen_random_uuid(),
  prenda_id uuid not null references public.prendas(id) on delete cascade,
  color text not null,
  talla text not null,
  stock integer not null default 0 check (stock >= 0),
  creado_en timestamptz not null default now(),
  unique (prenda_id, color, talla)
);
create index prenda_variantes_prenda_idx on public.prenda_variantes(prenda_id);

alter table public.ventas
  drop constraint ventas_prenda_id_key,
  add column variante_id uuid references public.prenda_variantes(id) on delete set null,
  add column variante_color text,
  add column variante_talla text;
create unique index ventas_prenda_unica_unica_idx on public.ventas(prenda_id) where variante_id is null;

alter table public.prenda_variantes enable row level security;
grant select, insert, update, delete on public.prenda_variantes to authenticated;
create policy "Variantes visibles a usuarios autorizados" on public.prenda_variantes for select to authenticated using (true);
create policy "Administradores crean variantes" on public.prenda_variantes for insert to authenticated with check ((select public.es_administrador()));
create policy "Administradores editan variantes" on public.prenda_variantes for update to authenticated using ((select public.es_administrador())) with check ((select public.es_administrador()));
create policy "Administradores eliminan variantes" on public.prenda_variantes for delete to authenticated using ((select public.es_administrador()));

drop function public.registrar_venta(uuid, numeric);
create function public.registrar_venta(p_prenda_id uuid, p_precio_final numeric, p_variante_id uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare pieza public.prendas; variante public.prenda_variantes; venta_id uuid;
begin
  if auth.uid() is null then raise exception 'Sesión no autorizada'; end if;
  if not exists (select 1 from public.perfiles where id = auth.uid()) then raise exception 'Usuario no autorizado'; end if;
  select * into pieza from public.prendas where id = p_prenda_id for update;
  if not found or pieza.estado <> 'disponible' then raise exception 'El producto ya no está disponible'; end if;
  if p_precio_final < 0 then raise exception 'El precio no puede ser negativo'; end if;

  if pieza.tipo_producto = 'con_variantes' then
    if p_variante_id is null then raise exception 'Selecciona una talla y color'; end if;
    select * into variante from public.prenda_variantes where id = p_variante_id and prenda_id = pieza.id for update;
    if not found or variante.stock < 1 then raise exception 'La variante seleccionada no tiene stock'; end if;
    update public.prenda_variantes set stock = stock - 1 where id = variante.id;
    if not exists (select 1 from public.prenda_variantes where prenda_id = pieza.id and stock > 0) then
      update public.prendas set estado = 'vendida', actualizado_en = now() where id = pieza.id;
    end if;
  else
    if p_variante_id is not null then raise exception 'Una prenda única no admite variantes'; end if;
    update public.prendas set estado = 'vendida', stock = 0, actualizado_en = now() where id = pieza.id;
  end if;

  insert into public.ventas(prenda_id, variante_id, variante_color, variante_talla, precio_compra, precio_sugerido, precio_final, descuento, ganancia, vendedor_id)
  values (pieza.id, variante.id, variante.color, variante.talla, pieza.precio_compra, pieza.precio_sugerido, p_precio_final, greatest(pieza.precio_sugerido - p_precio_final, 0), p_precio_final - pieza.precio_compra, auth.uid()) returning id into venta_id;
  return venta_id;
end; $$;
revoke execute on function public.registrar_venta(uuid, numeric, uuid) from public, anon, authenticated;
grant execute on function public.registrar_venta(uuid, numeric, uuid) to authenticated;
