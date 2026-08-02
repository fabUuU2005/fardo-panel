-- Las políticas RLS de inventario y Storage consultan este helper con el rol autenticado.
-- La función solo devuelve si el usuario actual tiene el rol de administrador.
grant execute on function public.es_administrador() to authenticated;
