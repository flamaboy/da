// Corre las pruebas en una base de datos de mentira dentro de esta compu (sin tocar Supabase).
// Uso (lo hace Claude): npm i @electric-sql/pglite  y después  node correr_en_esta_compu.js
// Arma un "Supabase de mentira" mínimo (esquema auth, roles) y corre la migración y las pruebas.
const { PGlite } = require('@electric-sql/pglite');
const fs = require('fs');
(async () => {
  const db = new PGlite();
  await db.exec(`
    create role anon nologin; create role authenticated nologin;
    create schema auth;
    create table auth.users (id uuid primary key, email text, raw_user_meta_data jsonb);
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(nullif(current_setting('request.jwt.claims', true), '')::json ->> 'sub', '')::uuid $$;
    grant usage on schema auth to anon, authenticated;
    grant execute on function auth.uid() to anon, authenticated;
    grant usage on schema public to anon, authenticated;
  `);
  // Se aplican todas las migraciones en orden, menos la del vencimiento diario
  // (usa pg_cron, que solo existe en Supabase de verdad).
  const carpeta = require('path').join(__dirname, '..', 'migraciones');
  for (const archivo of fs.readdirSync(carpeta).sort()) {
    if (!archivo.endsWith('.sql') || archivo.includes('vencimiento_diario')) continue;
    await db.exec(fs.readFileSync(require('path').join(carpeta, archivo), 'utf8'));
    console.log('Migración aplicada sin errores: ' + archivo);
  }
  const res = await db.exec(fs.readFileSync(require('path').join(__dirname, 'pruebas_seguridad.sql'), 'utf8'));
  const tabla = res.find(r => r.fields && r.fields.some(f => f.name === 'prueba'));
  let fallas = 0;
  for (const f of tabla.rows) { if (!f.ok) fallas++; console.log(`${f.ok ? 'OK  ' : 'FALLA'} ${String(f.n).padStart(2)}. ${f.prueba}  → ${f.detalle||''}`); }
  console.log(`\n${tabla.rows.length - fallas}/${tabla.rows.length} pruebas pasaron.`);
})().catch(e => { console.error('ERROR:', e.message); process.exit(1); });
