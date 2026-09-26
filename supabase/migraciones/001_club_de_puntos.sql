-- =====================================================================
--  Club de puntos de Burger Couple — estructura de la base de datos
--
--  Idea central (y por qué está hecho así):
--  * Los puntos NO se guardan como un número que se pisa. Se guarda cada
--    movimiento (compra, canje, vencimiento, ajuste) y el saldo es la suma.
--    Así siempre se puede explicar de dónde salió cada punto, y un error
--    se corrige con un movimiento nuevo, nunca borrando el pasado.
--  * El cliente solo puede LEER sus datos. Sumar o restar puntos lo hacen
--    únicamente funciones del servidor que primero comprueban que quien
--    las llama es personal del local. El navegador nunca decide cuántos
--    puntos se suman: manda el monto de la compra y el servidor calcula.
--  * Cada carga lleva una "referencia" única: si el cajero toca dos veces el
--    botón o se corta internet y reintenta, la compra se cuenta una sola vez.
--
--  Reglas del programa (decididas por Mati el 26/09/2026):
--  * 10 puntos por cada $1.000 de compra.
--  * Doble puntos en la primera compra.
--  * Los puntos vencen si el socio pasa 3 meses (90 días) sin comprar.
--  * Niveles según lo gastado en los últimos 90 días:
--      Pelo Crocante (al registrarse), Tomasito ($60.000, +10% de puntos),
--      Comandante ($150.000, +25% de puntos y premio exclusivo).
--  * Los pedidos de Rappi no suman puntos (se carga solo en el local).
-- =====================================================================

-- ---------------------------------------------------------------------
--  Tablas
-- ---------------------------------------------------------------------
create table public.locales (
  id text primary key,
  nombre text not null,
  activo boolean not null default true
);

insert into public.locales (id, nombre) values
  ('la-mansion', 'La Mansión (Caballito)'),
  ('la-tercera', 'La Tercera (Belgrano)'),
  ('los-90s', 'Los 90''s (Palermo Soho)'),
  ('boedo', 'Boedo'),
  ('recoleta-express', 'Recoleta Express');

-- Un socio por cada cuenta creada en la web. Se crea solo (ver disparador abajo).
create table public.socios (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  nombre text,
  -- El código que va dentro del QR. Corto y sin letras que se confundan
  -- (sin 0/O ni 1/I), porque a veces el cajero lo va a tipear a mano.
  codigo text not null unique,
  acepta_bases_at timestamptz,
  creado_at timestamptz not null default now()
);

-- Personal de los locales: quién puede cargar compras y canjes.
create table public.personal (
  id uuid primary key references auth.users (id) on delete cascade,
  nombre text not null,
  rol text not null check (rol in ('cajero', 'admin')),
  local_id text references public.locales (id),
  activo boolean not null default true,
  creado_at timestamptz not null default now()
);

create table public.premios (
  id serial primary key,
  nombre text not null,
  puntos integer not null check (puntos > 0),
  -- Si tiene nivel, solo lo pueden canjear socios de ese nivel (premio exclusivo).
  solo_nivel text check (solo_nivel in ('tomasito', 'comandante')),
  activo boolean not null default true,
  orden integer not null default 0
);

insert into public.premios (nombre, puntos, solo_nivel, orden) values
  ('Gaseosa o limonada', 400, null, 1),
  ('Postre Franui', 1000, null, 2),
  ('Papas fritas con el polvito del Loco Piña', 1100, null, 3),
  ('Cheese simple', 1800, null, 4),
  ('Burger doble a elección', 2500, null, 5),
  ('The Burger Couple Box', 3000, null, 6),
  -- Premio exclusivo de nivel Comandante: a definir por Burger Couple.
  ('Premio exclusivo Comandante (a definir)', 2000, 'comandante', 7);

-- El libro de movimientos: la única fuente de verdad de los puntos.
create table public.movimientos (
  id bigint generated always as identity primary key,
  socio_id uuid not null references public.socios (id) on delete cascade,
  tipo text not null check (tipo in ('compra', 'canje', 'vencimiento', 'ajuste')),
  puntos integer not null,
  monto_pesos numeric(12, 2),
  premio_id integer references public.premios (id),
  local_id text references public.locales (id),
  personal_id uuid references public.personal (id),
  referencia uuid not null unique,
  motivo text,
  creado_at timestamptz not null default now(),
  -- Candados de coherencia: una compra siempre tiene monto y suma;
  -- un canje siempre tiene premio y resta.
  constraint compra_valida check (tipo <> 'compra' or (monto_pesos > 0 and puntos >= 0)),
  constraint canje_valido check (tipo <> 'canje' or (premio_id is not null and puntos < 0))
);
create index movimientos_socio_fecha on public.movimientos (socio_id, creado_at desc);

-- El pasado no se toca: nadie puede editar ni borrar movimientos.
-- (La única excepción es si se borra la cuenta entera del socio.)
create function public.movimientos_inmutables() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' and not exists (select 1 from public.socios where id = old.socio_id) then
    return old; -- se está borrando la cuenta completa del socio
  end if;
  raise exception 'Los movimientos no se modifican ni se borran: se corrigen con un ajuste.';
end $$;
create trigger movimientos_inmutables before update or delete on public.movimientos
  for each row execute function public.movimientos_inmutables();

-- ---------------------------------------------------------------------
--  Alta automática del socio al crear la cuenta
-- ---------------------------------------------------------------------
create function public.generar_codigo_socio() returns text
language plpgsql set search_path = '' as $$
declare
  alfabeto constant text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  nuevo text;
begin
  loop
    nuevo := 'BC';
    for i in 1..6 loop
      nuevo := nuevo || substr(alfabeto, 1 + floor(random() * length(alfabeto))::int, 1);
    end loop;
    exit when not exists (select 1 from public.socios where codigo = nuevo);
  end loop;
  return nuevo;
end $$;

create function public.crear_socio() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.socios (id, email, nombre, codigo, acepta_bases_at)
  values (
    new.id,
    new.email,
    nullif(trim(new.raw_user_meta_data ->> 'nombre'), ''),
    public.generar_codigo_socio(),
    case when (new.raw_user_meta_data ->> 'acepta_bases') = 'true' then now() end
  );
  return new;
end $$;
create trigger crear_socio after insert on auth.users
  for each row execute function public.crear_socio();

-- ---------------------------------------------------------------------
--  Cálculos (funciones internas: el público no las puede llamar)
-- ---------------------------------------------------------------------
create function public.saldo(p_socio uuid) returns integer
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(puntos), 0)::int from public.movimientos where socio_id = p_socio;
$$;

create function public.gasto_90_dias(p_socio uuid) returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(monto_pesos), 0) from public.movimientos
  where socio_id = p_socio and tipo = 'compra' and creado_at > now() - interval '90 days';
$$;

create function public.nivel_por_gasto(p_gasto numeric) returns text
language sql immutable set search_path = '' as $$
  select case when p_gasto >= 150000 then 'comandante'
              when p_gasto >= 60000 then 'tomasito'
              else 'pelo-crocante' end;
$$;

create function public.es_personal() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.personal where id = auth.uid() and activo);
$$;

create function public.es_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.personal where id = auth.uid() and activo and rol = 'admin');
$$;

-- Vence los puntos de un socio si pasó 90 días sin comprar.
-- Se llama antes de cada carga o canje, y una vez por día para todos.
create function public.vencer_puntos(p_socio uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_saldo integer := public.saldo(p_socio);
  v_ultima timestamptz;
begin
  if v_saldo <= 0 then return; end if;
  select max(creado_at) into v_ultima from public.movimientos
  where socio_id = p_socio and tipo = 'compra';
  if v_ultima is null or v_ultima > now() - interval '90 days' then return; end if;
  insert into public.movimientos (socio_id, tipo, puntos, referencia, motivo)
  values (p_socio, 'vencimiento', -v_saldo, gen_random_uuid(), '90 días sin compras');
end $$;

create function public.vencer_puntos_de_todos() returns void
language plpgsql security definer set search_path = '' as $$
declare s record;
begin
  for s in select id from public.socios loop
    perform public.vencer_puntos(s.id);
  end loop;
end $$;

-- Resumen de un socio, para el cajero y para el propio socio.
create function public.resumen_de(p_socio uuid) returns json
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
    'primera_compra_pendiente', v_ultima is null
  );
end $$;

-- ---------------------------------------------------------------------
--  Funciones que se llaman desde la web
-- ---------------------------------------------------------------------

-- Para el socio: su tarjeta.
create function public.mi_resumen() returns json
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Tenés que iniciar sesión.'; end if;
  perform public.vencer_puntos(auth.uid());
  return public.resumen_de(auth.uid());
end $$;

-- Para el cajero: buscar al socio por el código del QR.
create function public.buscar_socio(p_codigo text) returns json
language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if not public.es_personal() then raise exception 'Solo el personal de Burger Couple puede hacer esto.'; end if;
  select id into v_id from public.socios where codigo = upper(trim(p_codigo));
  if v_id is null then raise exception 'No existe un socio con el código %.', upper(trim(p_codigo)); end if;
  perform public.vencer_puntos(v_id);
  return public.resumen_de(v_id);
end $$;

-- Para el cajero: cargar una compra. El servidor calcula los puntos.
create function public.registrar_compra(p_codigo text, p_monto numeric, p_local text, p_referencia uuid)
returns json
language plpgsql security definer set search_path = '' as $$
declare
  v_socio public.socios;
  v_personal public.personal;
  v_nivel text;
  v_multiplicador numeric;
  v_primera boolean;
  v_puntos integer;
  v_existente public.movimientos;
begin
  select * into v_personal from public.personal where id = auth.uid() and activo;
  if v_personal.id is null then raise exception 'Solo el personal de Burger Couple puede cargar compras.'; end if;

  -- Si esta misma carga ya entró (doble toque, reintento), devolvemos lo que ya se cargó.
  select * into v_existente from public.movimientos where referencia = p_referencia;
  if v_existente.id is not null then
    return json_build_object('repetida', true, 'puntos', v_existente.puntos, 'resumen', public.resumen_de(v_existente.socio_id));
  end if;

  -- Límites razonables para frenar errores de tipeo (un cero de más).
  if p_monto is null or p_monto < 1000 then raise exception 'El monto mínimo para sumar puntos es $1.000.'; end if;
  if p_monto > 500000 then raise exception 'El monto supera $500.000. Revisalo; si es correcto, que lo cargue un administrador como ajuste.'; end if;
  if not exists (select 1 from public.locales where id = p_local and activo) then raise exception 'Local desconocido.'; end if;

  -- "for update" bloquea al socio mientras cargamos: si dos cajas cargan a la
  -- vez al mismo socio, una espera a la otra y los números no se pisan.
  select * into v_socio from public.socios where codigo = upper(trim(p_codigo)) for update;
  if v_socio.id is null then raise exception 'No existe un socio con el código %.', upper(trim(p_codigo)); end if;

  perform public.vencer_puntos(v_socio.id);

  v_nivel := public.nivel_por_gasto(public.gasto_90_dias(v_socio.id));
  v_multiplicador := case v_nivel when 'comandante' then 1.25 when 'tomasito' then 1.10 else 1 end;
  v_primera := not exists (select 1 from public.movimientos where socio_id = v_socio.id and tipo = 'compra');
  if v_primera then v_multiplicador := v_multiplicador * 2; end if;

  -- 10 puntos por cada $1.000 enteros, por el multiplicador del nivel.
  v_puntos := floor(floor(p_monto / 1000) * 10 * v_multiplicador);

  insert into public.movimientos (socio_id, tipo, puntos, monto_pesos, local_id, personal_id, referencia, motivo)
  values (v_socio.id, 'compra', v_puntos, p_monto, p_local, v_personal.id, p_referencia,
          case when v_primera then 'Primera compra: doble puntos' end);

  return json_build_object('repetida', false, 'puntos', v_puntos, 'primera_compra', v_primera,
                           'resumen', public.resumen_de(v_socio.id));
end $$;

-- Para el cajero: canjear un premio.
create function public.canjear_premio(p_codigo text, p_premio integer, p_local text, p_referencia uuid)
returns json
language plpgsql security definer set search_path = '' as $$
declare
  v_socio public.socios;
  v_premio public.premios;
  v_nivel text;
  v_existente public.movimientos;
begin
  if not public.es_personal() then raise exception 'Solo el personal de Burger Couple puede canjear premios.'; end if;

  select * into v_existente from public.movimientos where referencia = p_referencia;
  if v_existente.id is not null then
    return json_build_object('repetida', true, 'resumen', public.resumen_de(v_existente.socio_id));
  end if;

  select * into v_socio from public.socios where codigo = upper(trim(p_codigo)) for update;
  if v_socio.id is null then raise exception 'No existe un socio con el código %.', upper(trim(p_codigo)); end if;
  select * into v_premio from public.premios where id = p_premio and activo;
  if v_premio.id is null then raise exception 'Ese premio no existe o no está activo.'; end if;

  perform public.vencer_puntos(v_socio.id);

  v_nivel := public.nivel_por_gasto(public.gasto_90_dias(v_socio.id));
  if v_premio.solo_nivel = 'comandante' and v_nivel <> 'comandante' then
    raise exception 'Este premio es solo para socios nivel Comandante.';
  end if;
  if v_premio.solo_nivel = 'tomasito' and v_nivel not in ('tomasito', 'comandante') then
    raise exception 'Este premio es solo para socios nivel Tomasito o Comandante.';
  end if;
  if public.saldo(v_socio.id) < v_premio.puntos then
    raise exception 'No le alcanzan los puntos: tiene % y el premio cuesta %.', public.saldo(v_socio.id), v_premio.puntos;
  end if;

  insert into public.movimientos (socio_id, tipo, puntos, premio_id, local_id, personal_id, referencia, motivo)
  values (v_socio.id, 'canje', -v_premio.puntos, v_premio.id, p_local, auth.uid(), p_referencia, v_premio.nombre);

  return json_build_object('repetida', false, 'premio', v_premio.nombre, 'resumen', public.resumen_de(v_socio.id));
end $$;

-- Para administradores: dar de alta (o de baja) a alguien del personal.
-- La persona primero se crea una cuenta común en la web; después un admin la habilita.
create function public.alta_personal(p_email text, p_nombre text, p_rol text, p_local text)
returns json
language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if not public.es_admin() then raise exception 'Solo un administrador puede dar de alta personal.'; end if;
  select id into v_id from public.socios where lower(email) = lower(trim(p_email));
  if v_id is null then raise exception 'Esa persona todavía no se creó una cuenta en la web con el mail %.', p_email; end if;
  insert into public.personal (id, nombre, rol, local_id) values (v_id, p_nombre, p_rol, nullif(p_local, ''))
  on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, local_id = excluded.local_id, activo = true;
  return json_build_object('ok', true);
end $$;

create function public.baja_personal(p_email text) returns json
language plpgsql security definer set search_path = '' as $$
begin
  if not public.es_admin() then raise exception 'Solo un administrador puede dar de baja personal.'; end if;
  update public.personal set activo = false
  where id = (select id from public.socios where lower(email) = lower(trim(p_email)));
  return json_build_object('ok', true);
end $$;

-- Para administradores: corregir puntos a mano, siempre con motivo (queda registrado quién y por qué).
create function public.ajustar_puntos(p_codigo text, p_puntos integer, p_motivo text, p_referencia uuid)
returns json
language plpgsql security definer set search_path = '' as $$
declare v_socio uuid;
begin
  if not public.es_admin() then raise exception 'Solo un administrador puede ajustar puntos.'; end if;
  if coalesce(trim(p_motivo), '') = '' then raise exception 'El ajuste necesita un motivo.'; end if;
  if exists (select 1 from public.movimientos where referencia = p_referencia) then
    return json_build_object('repetida', true);
  end if;
  select id into v_socio from public.socios where codigo = upper(trim(p_codigo)) for update;
  if v_socio is null then raise exception 'No existe un socio con ese código.'; end if;
  insert into public.movimientos (socio_id, tipo, puntos, personal_id, referencia, motivo)
  values (v_socio, 'ajuste', p_puntos, auth.uid(), p_referencia, p_motivo);
  return json_build_object('repetida', false, 'resumen', public.resumen_de(v_socio));
end $$;

-- ---------------------------------------------------------------------
--  Permisos: quién puede ver y llamar qué
-- ---------------------------------------------------------------------
alter table public.locales enable row level security;
alter table public.socios enable row level security;
alter table public.personal enable row level security;
alter table public.premios enable row level security;
alter table public.movimientos enable row level security;

-- Nadie escribe directo en las tablas: todo pasa por las funciones de arriba.
revoke all on public.locales, public.socios, public.personal, public.premios, public.movimientos from anon, authenticated;
grant select on public.locales, public.premios to anon, authenticated;
grant select on public.socios, public.movimientos, public.personal to authenticated;
-- El socio puede cambiar su nombre, y nada más.
grant update (nombre) on public.socios to authenticated;

create policy "locales visibles" on public.locales for select using (activo);
create policy "premios visibles" on public.premios for select using (activo);
create policy "cada socio ve solo su ficha" on public.socios for select to authenticated using (id = auth.uid());
create policy "cada socio edita solo su nombre" on public.socios for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "cada socio ve solo sus movimientos" on public.movimientos for select to authenticated using (socio_id = auth.uid());
create policy "cada empleado ve solo su ficha" on public.personal for select to authenticated using (id = auth.uid());

-- Las funciones internas no se pueden llamar desde afuera.
revoke execute on all functions in schema public from public, anon, authenticated;
-- Solo estas se pueden llamar desde la web, y todas piden sesión iniciada.
grant execute on function public.mi_resumen() to authenticated;
grant execute on function public.buscar_socio(text) to authenticated;
grant execute on function public.registrar_compra(text, numeric, text, uuid) to authenticated;
grant execute on function public.canjear_premio(text, integer, text, uuid) to authenticated;
grant execute on function public.alta_personal(text, text, text, text) to authenticated;
grant execute on function public.baja_personal(text) to authenticated;
grant execute on function public.ajustar_puntos(text, integer, text, uuid) to authenticated;
-- Las funciones que se crearán en el futuro tampoco quedan abiertas por defecto.
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
