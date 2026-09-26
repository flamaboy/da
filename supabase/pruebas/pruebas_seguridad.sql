-- =====================================================================
--  Pruebas del club de puntos
--
--  Crea usuarios de prueba, se hace pasar por un socio, un cajero y un
--  administrador, y comprueba que cada uno pueda hacer SOLO lo que le
--  corresponde. Al final deshace todo (ROLLBACK): no deja datos de prueba.
--
--  Resultado: una tabla con cada prueba y si pasó (ok = true).
--  Si alguna da false, NO se lanza el club hasta arreglarlo.
-- =====================================================================
begin;

create schema pruebas;
grant usage on schema pruebas to anon, authenticated;
create table pruebas.resultados (n serial, prueba text, ok boolean, detalle text);
grant all on pruebas.resultados to anon, authenticated;
grant usage on sequence pruebas.resultados_n_seq to anon, authenticated;

create function pruebas.anotar(p_prueba text, p_ok boolean, p_detalle text default null) returns void
language sql as $$ insert into pruebas.resultados (prueba, ok, detalle) values (p_prueba, p_ok, p_detalle) $$;

-- Hacerse pasar por un usuario con sesión iniciada (como lo haría la web).
create function pruebas.como(p_usuario uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_usuario, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;
create function pruebas.como_anonimo() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  execute 'set local role anon';
end $$;
create function pruebas.volver() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
end $$;
grant execute on all functions in schema pruebas to anon, authenticated;

-- Usuarios de prueba: dos socios, un cajero y un administrador.
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'socia.a@prueba.test', '{"nombre":"Socia A","acepta_bases":"true"}'),
  ('00000000-0000-0000-0000-00000000000b', 'socio.b@prueba.test', '{"nombre":"Socio B"}'),
  ('00000000-0000-0000-0000-00000000000c', 'cajero@prueba.test', '{"nombre":"Cajero"}'),
  ('00000000-0000-0000-0000-00000000000d', 'admin@prueba.test', '{"nombre":"Admin"}');
insert into public.personal (id, nombre, rol, local_id) values
  ('00000000-0000-0000-0000-00000000000c', 'Cajero de prueba', 'cajero', 'la-mansion'),
  ('00000000-0000-0000-0000-00000000000d', 'Admin de prueba', 'admin', null);

-- ------------------------------------------------------------ Alta automática
do $$
declare s public.socios;
begin
  select * into s from public.socios where id = '00000000-0000-0000-0000-00000000000a';
  perform pruebas.anotar('Al crear la cuenta se crea el socio con código BC + 6', s.codigo ~ '^BC[2-9A-HJ-NP-Z]{6}$', s.codigo);
  perform pruebas.anotar('Guarda el nombre y la aceptación de las bases', s.nombre = 'Socia A' and s.acepta_bases_at is not null);
end $$;

-- ------------------------------------------------------------ Lo que NO puede un socio
select pruebas.como('00000000-0000-0000-0000-00000000000a');
do $$
declare n int;
begin
  select count(*) into n from public.socios;
  perform pruebas.anotar('Un socio ve solo su propia ficha (no la de otros)', n = 1, n || ' fichas visibles');

  begin
    insert into public.movimientos (socio_id, tipo, puntos, referencia)
    values ('00000000-0000-0000-0000-00000000000a', 'ajuste', 99999, gen_random_uuid());
    perform pruebas.anotar('Un socio NO puede sumarse puntos escribiendo en la tabla', false, 'pudo insertar');
  exception when others then
    perform pruebas.anotar('Un socio NO puede sumarse puntos escribiendo en la tabla', true, sqlerrm);
  end;

  begin
    update public.socios set codigo = 'BCHACK00' where id = '00000000-0000-0000-0000-00000000000a';
    perform pruebas.anotar('Un socio NO puede cambiar su código', false, 'pudo cambiarlo');
  exception when others then
    perform pruebas.anotar('Un socio NO puede cambiar su código', true, sqlerrm);
  end;

  update public.socios set nombre = 'Socia A editada' where id = '00000000-0000-0000-0000-00000000000a';
  perform pruebas.anotar('Un socio SÍ puede cambiar su nombre', (select nombre from public.socios) = 'Socia A editada');

  begin
    perform public.registrar_compra((select codigo from public.socios), 50000, 'la-mansion', gen_random_uuid());
    perform pruebas.anotar('Un socio NO puede cargarse una compra', false, 'pudo cargarla');
  exception when others then
    perform pruebas.anotar('Un socio NO puede cargarse una compra', true, sqlerrm);
  end;

  begin
    perform public.saldo('00000000-0000-0000-0000-00000000000b');
    perform pruebas.anotar('Un socio NO puede usar las funciones internas', false, 'pudo usarlas');
  exception when others then
    perform pruebas.anotar('Un socio NO puede usar las funciones internas', true, sqlerrm);
  end;

  begin
    perform public.alta_personal('socia.a@prueba.test', 'Yo', 'admin', null);
    perform pruebas.anotar('Un socio NO puede nombrarse administrador', false, 'pudo');
  exception when others then
    perform pruebas.anotar('Un socio NO puede nombrarse administrador', true, sqlerrm);
  end;

  begin
    perform public.buscar_socio('BC222222');
    perform pruebas.anotar('Un socio NO puede buscar a otros socios', false, 'pudo');
  exception when others then
    perform pruebas.anotar('Un socio NO puede buscar a otros socios', true, sqlerrm);
  end;
end $$;
select pruebas.volver();

-- ------------------------------------------------------------ Visitante sin cuenta
select pruebas.como_anonimo();
do $$
declare n int;
begin
  select count(*) into n from public.premios;
  perform pruebas.anotar('Un visitante sin cuenta ve el catálogo de premios', n > 0, n || ' premios');
  begin
    select count(*) into n from public.socios;
    perform pruebas.anotar('Un visitante sin cuenta NO ve socios', n = 0, n || ' visibles');
  exception when others then
    perform pruebas.anotar('Un visitante sin cuenta NO ve socios', true, sqlerrm);
  end;
  begin
    perform public.mi_resumen();
    perform pruebas.anotar('Un visitante sin cuenta NO puede pedir un resumen', false, 'pudo');
  exception when others then
    perform pruebas.anotar('Un visitante sin cuenta NO puede pedir un resumen', true, sqlerrm);
  end;
end $$;
select pruebas.volver();

-- El código de la socia A se anota antes, porque el cajero (con razón) no puede leer la tabla de socios:
-- en la vida real lo obtiene escaneando el QR.
select set_config('pruebas.codigo_a', (select codigo from public.socios where id = '00000000-0000-0000-0000-00000000000a'), true);

-- ------------------------------------------------------------ El cajero carga compras
select pruebas.como('00000000-0000-0000-0000-00000000000c');
do $$
declare
  cod text := current_setting('pruebas.codigo_a');
  ref1 uuid := gen_random_uuid();
  r json;
begin
  r := public.registrar_compra(cod, 20000, 'la-mansion', ref1);
  perform pruebas.anotar('Primera compra de $20.000 suma 400 (doble puntos)', (r ->> 'puntos')::int = 400, r::text);

  r := public.registrar_compra(cod, 20000, 'la-mansion', ref1);
  perform pruebas.anotar('La misma carga repetida (doble toque) NO suma dos veces',
    (r ->> 'repetida')::boolean and (r -> 'resumen' ->> 'saldo')::int = 400, r::text);

  r := public.registrar_compra(cod, 45000, 'la-tercera', gen_random_uuid());
  perform pruebas.anotar('Compra de $45.000 en nivel Pelo Crocante suma 450', (r ->> 'puntos')::int = 450, r::text);
  perform pruebas.anotar('Con $65.000 gastados sube a nivel Tomasito', r -> 'resumen' ->> 'nivel' = 'tomasito', r -> 'resumen' ->> 'nivel');

  r := public.registrar_compra(cod, 10500, 'los-90s', gen_random_uuid());
  perform pruebas.anotar('En nivel Tomasito, $10.500 suma 110 (+10%, $500 sueltos no suman)', (r ->> 'puntos')::int = 110, r::text);
  perform pruebas.anotar('Saldo total 960', (r -> 'resumen' ->> 'saldo')::int = 960, r -> 'resumen' ->> 'saldo');

  begin
    perform public.registrar_compra(cod, 600000, 'la-mansion', gen_random_uuid());
    perform pruebas.anotar('Frena montos gigantes (error de tipeo)', false, 'aceptó $600.000');
  exception when others then perform pruebas.anotar('Frena montos gigantes (error de tipeo)', true, sqlerrm); end;

  begin
    perform public.registrar_compra(cod, 500, 'la-mansion', gen_random_uuid());
    perform pruebas.anotar('Frena montos menores a $1.000', false, 'aceptó $500');
  exception when others then perform pruebas.anotar('Frena montos menores a $1.000', true, sqlerrm); end;

  begin
    perform public.registrar_compra('BCNOEXIS', 20000, 'la-mansion', gen_random_uuid());
    perform pruebas.anotar('Avisa si el código no existe', false, 'aceptó');
  exception when others then perform pruebas.anotar('Avisa si el código no existe', true, sqlerrm); end;

  r := public.canjear_premio(cod, (select id from public.premios where puntos = 400), 'la-mansion', gen_random_uuid());
  perform pruebas.anotar('Canje de gaseosa (400) deja 560', (r -> 'resumen' ->> 'saldo')::int = 560, r::text);

  begin
    perform public.canjear_premio(cod, (select id from public.premios where puntos = 3000), 'la-mansion', gen_random_uuid());
    perform pruebas.anotar('NO deja canjear si no alcanzan los puntos', false, 'dejó');
  exception when others then perform pruebas.anotar('NO deja canjear si no alcanzan los puntos', true, sqlerrm); end;

  begin
    perform public.canjear_premio(cod, (select id from public.premios where solo_nivel = 'comandante'), 'la-mansion', gen_random_uuid());
    perform pruebas.anotar('El premio exclusivo es solo para Comandantes', false, 'dejó');
  exception when others then perform pruebas.anotar('El premio exclusivo es solo para Comandantes', true, sqlerrm); end;

  perform pruebas.anotar('El cajero NO ve los movimientos de los socios en la tabla', (select count(*) from public.movimientos) = 0);

  begin
    perform public.alta_personal('socio.b@prueba.test', 'B', 'cajero', 'boedo');
    perform pruebas.anotar('Un cajero NO puede dar de alta personal', false, 'pudo');
  exception when others then perform pruebas.anotar('Un cajero NO puede dar de alta personal', true, sqlerrm); end;

  begin
    perform public.ajustar_puntos(cod, 5000, 'regalo', gen_random_uuid());
    perform pruebas.anotar('Un cajero NO puede regalar puntos con un ajuste', false, 'pudo');
  exception when others then perform pruebas.anotar('Un cajero NO puede regalar puntos con un ajuste', true, sqlerrm); end;
end $$;
select pruebas.volver();

-- ------------------------------------------------------------ El socio ve su tarjeta
select pruebas.como('00000000-0000-0000-0000-00000000000a');
do $$
declare r json := public.mi_resumen(); n int;
begin
  perform pruebas.anotar('El socio ve su saldo (560) y su nivel (Tomasito)',
    (r ->> 'saldo')::int = 560 and r ->> 'nivel' = 'tomasito', r::text);
  select count(*) into n from public.movimientos;
  perform pruebas.anotar('El socio ve su historial completo (3 compras + 1 canje)', n = 4, n || ' movimientos');
end $$;
select pruebas.volver();

-- ------------------------------------------------------------ Administrador
select pruebas.como('00000000-0000-0000-0000-00000000000d');
do $$
declare cod text := current_setting('pruebas.codigo_a');
begin
  perform public.alta_personal('socio.b@prueba.test', 'Socio B cajero', 'cajero', 'boedo');
  perform pruebas.anotar('Un admin SÍ puede dar de alta un cajero', true);
  begin
    perform public.ajustar_puntos(cod, 100, '', gen_random_uuid());
    perform pruebas.anotar('Un ajuste sin motivo se rechaza', false, 'aceptó');
  exception when others then perform pruebas.anotar('Un ajuste sin motivo se rechaza', true, sqlerrm); end;
  perform public.ajustar_puntos(cod, -60, 'Corrección de prueba', gen_random_uuid());
  perform pruebas.anotar('Un admin SÍ puede ajustar con motivo', true);
end $$;
select pruebas.volver();

-- ------------------------------------------------------------ Vencimiento e historial intocable
do $$
declare v_b uuid := '00000000-0000-0000-0000-00000000000b';
begin
  -- Simulamos una compra de hace 100 días (solo se puede como dueño de la base).
  insert into public.movimientos (socio_id, tipo, puntos, monto_pesos, local_id, referencia, creado_at)
  values (v_b, 'compra', 300, 30000, 'boedo', gen_random_uuid(), now() - interval '100 days');
  perform public.vencer_puntos(v_b);
  perform pruebas.anotar('Tras 90 días sin comprar, los puntos vencen (saldo 0)', public.saldo(v_b) = 0, public.saldo(v_b)::text);
  perform pruebas.anotar('El vencimiento queda registrado como movimiento',
    exists (select 1 from public.movimientos where socio_id = v_b and tipo = 'vencimiento' and puntos = -300));
  perform pruebas.anotar('Socia A (compró hace instantes) NO pierde puntos',
    public.saldo('00000000-0000-0000-0000-00000000000a') = 500, public.saldo('00000000-0000-0000-0000-00000000000a')::text);

  begin
    update public.movimientos set puntos = 99999 where socio_id = v_b;
    perform pruebas.anotar('Nadie puede editar el historial (ni el dueño de la base)', false, 'pudo');
  exception when others then perform pruebas.anotar('Nadie puede editar el historial (ni el dueño de la base)', true, sqlerrm); end;
end $$;

select n, ok, prueba, detalle from pruebas.resultados order by n;
rollback;
