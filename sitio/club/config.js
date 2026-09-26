/*
  Conexión del club con Supabase (proyecto "burgercouple-club", NO el de BC OS).

  Estos dos datos son PÚBLICOS a propósito: cualquier web que usa Supabase los
  muestra. No abren nada por sí solos: lo que protege los puntos son las reglas
  de la base de datos (ver supabase/migraciones), que solo dejan a cada socio ver
  lo suyo y solo al personal cargar compras.
  La clave secreta de Supabase ("service_role") NUNCA va en la web.

  Mientras digan PENDIENTE, las páginas del club muestran un aviso de
  "todavía no está conectado" en vez de fallar.
*/
window.CLUB_CONFIG = {
  supabaseUrl: 'PENDIENTE',
  supabaseClave: 'PENDIENTE'
};
