-- =====================================================================
--  Vencimiento diario de puntos
--
--  Por qué: los puntos de un socio vencen si pasa 90 días sin comprar.
--  Eso ya se revisa cada vez que el socio entra o el cajero lo escanea,
--  pero además lo corremos una vez por día para todos, así el saldo que
--  se ve en cualquier reporte está siempre al día.
--  Hora: 06:00 UTC = 03:00 de Buenos Aires, cuando no hay nadie cargando compras.
-- =====================================================================
create extension if not exists pg_cron;

select cron.schedule(
  'vencer-puntos-diario',
  '0 6 * * *',
  $$ select public.vencer_puntos_de_todos(); $$
);
