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
  await db.exec(fs.readFileSync(require('path').join(__dirname, '..', 'migraciones', '001_club_de_puntos.sql'), 'utf8'));
  console.log('Migración 001 aplicada sin errores.');
  const res = await db.exec(fs.readFileSync(require('path').join(__dirname, 'pruebas_seguridad.sql'), 'utf8'));
  const tabla = res.find(r => r.fields && r.fields.some(f => f.name === 'prueba'));
  let fallas = 0;
  for (const f of tabla.rows) { if (!f.ok) fallas++; console.log(`${f.ok ? 'OK  ' : 'FALLA'} ${String(f.n).padStart(2)}. ${f.prueba}  → ${f.detalle||''}`); }
  console.log(`\n${tabla.rows.length - fallas}/${tabla.rows.length} pruebas pasaron.`);
})().catch(e => { console.error('ERROR:', e.message); process.exit(1); });
