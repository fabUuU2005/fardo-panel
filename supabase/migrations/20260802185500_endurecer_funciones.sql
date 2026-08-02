-- Las funciones de apoyo no son endpoints públicos. La venta sí se ejecuta
-- de forma atómica para los usuarios autenticados y valida auth.uid() internamente.
create or replace function public.es_administrador()
returns boolean language sql stable security invoker set search_path = '' as $$
  select exists (select 1 from public.perfiles where id = (select auth.uid()) and rol = 'administrador');
$$;

revoke execute on function public.crear_perfil() from public, anon, authenticated;
revoke execute on function public.es_administrador() from public, anon, authenticated;
revoke execute on function public.registrar_venta(uuid, numeric) from public, anon, authenticated;
grant execute on function public.registrar_venta(uuid, numeric) to authenticated;
