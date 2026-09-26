-- =====================================================================
--  Newsletter: consentimiento para recibir novedades por mail
--
--  Por qué existe: aceptar las bases del club NO es aceptar publicidad.
--  La ley de datos personales (25.326) pide consentimiento para usar el
--  mail con fines publicitarios. Por eso es una casilla APARTE, que arranca
--  destildada, que el socio puede cambiar cuando quiera, y el listado para
--  el newsletter trae SOLO a quienes la marcaron.
--  Se guarda también la fecha, como prueba de cuándo dio (o quitó) el permiso.
-- =====================================================================

alter table public.socios
  add column acepta_novedades boolean not null default false,
  add column novedades_cambiado_at timestamptz;

-- El alta automática ahora también lee la casilla de novedades del registro.
create or replace function public.crear_socio() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_novedades boolean := coalesce((new.raw_user_meta_data ->> 'acepta_novedades') = 'true', false);
begin
  insert into public.socios (id, email, nombre, codigo, acepta_bases_at, acepta_novedades, novedades_cambiado_at)
  values (
    new.id,
    new.email,
    nullif(trim(new.raw_user_meta_data ->> 'nombre'), ''),
    public.generar_codigo_socio(),
    case when (new.raw_user_meta_data ->> 'acepta_bases') = 'true' then now() end,
    v_novedades,
    case when v_novedades then now() end
  );
  return new;
end $$;

-- El socio prende o apaga las novedades desde su tarjeta.
create function public.cambiar_novedades(p_acepta boolean) returns json
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Tenés que iniciar sesión.'; end if;
  update public.socios
     set acepta_novedades = coalesce(p_acepta, false), novedades_cambiado_at = now()
   where id = auth.uid();
  return json_build_object('acepta_novedades', coalesce(p_acepta, false));
end $$;

-- Listado para el newsletter: solo administradores, y solo quienes aceptaron.
create function public.exportar_suscriptos()
returns table (nombre text, email text, acepto_el timestamptz, nivel text)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.es_admin() then raise exception 'Solo un administrador puede descargar los mails.'; end if;
  return query
    select s.nombre, s.email, s.novedades_cambiado_at,
           public.nivel_por_gasto(public.gasto_90_dias(s.id))
      from public.socios s
     where s.acepta_novedades
     order by s.novedades_cambiado_at;
end $$;

-- La tarjeta del socio muestra si tiene las novedades activadas.
create or replace function public.resumen_de(p_socio uuid) returns json
language plpgsql stable security definer set search_path = '' as $$
declare
  v_gasto numeric := public.gasto_90_dias(p_socio);
  v_nivel text := public.nivel_por_gasto(v_gasto);
  v_ultima timestamptz;
  s public.socios;
begin
  select * into s from public.socios where id = p_socio;
  select max(creado_at) into v_ultima from public.movimientos where socio_id = p_socio and tipo = 'compra';
  return json_build_object(
    'nombre', s.nombre,
    'email', s.email,
    'codigo', s.codigo,
    'saldo', public.saldo(p_socio),
    'nivel', v_nivel,
    'gasto_90_dias', v_gasto,
    'falta_siguiente_nivel', case v_nivel when 'pelo-crocante' then 60000 - v_gasto
                                          when 'tomasito' then 150000 - v_gasto else 0 end,
    'vencen_el', case when v_ultima is not null then (v_ultima + interval '90 days') end,
    'primera_compra_pendiente', v_ultima is null,
    'acepta_novedades', s.acepta_novedades
  );
end $$;

revoke execute on function public.cambiar_novedades(boolean), public.exportar_suscriptos() from public, anon;
grant execute on function public.cambiar_novedades(boolean) to authenticated;
grant execute on function public.exportar_suscriptos() to authenticated;
