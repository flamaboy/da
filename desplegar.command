#!/bin/bash
# =====================================================================
#  desplegar.command — publica la web de Burger Couple en Cloudflare
#
#  Cómo se usa: doble clic desde el Finder. Nada más.
#  La primera vez te pide el token de Cloudflare y lo guarda en un
#  archivo privado de esta carpeta; las siguientes veces ya no pregunta.
#
#  (Para pruebas: "./desplegar.command --prueba" arma todo pero NO publica.)
# =====================================================================

# Por qué no usamos "set -e": preferimos atrapar cada error a mano y
# explicarlo en castellano, en vez de que la ventana se cierre de golpe.
set -u

# El Finder abre este archivo desde tu carpeta de usuario, no desde esta
# carpeta. Sin esta línea, el script no encontraría la carpeta "sitio".
cd "$(dirname "$0")" || exit 1

# ---------------------------------------------------------------------
#  Datos fijos
# ---------------------------------------------------------------------
# El nombre del proyecto está escrito acá y en ningún otro lado, a propósito:
# el token de Cloudflare da permiso sobre TODOS los proyectos de la cuenta
# (incluido BC OS), así que el script solo puede apuntar a este nombre.
# No lo cambies sin hablarlo antes.
PROYECTO="burgercouple-web"

# La rama "de producción". El script publica SIEMPRE en esta rama y además
# se asegura de que Cloudflare la tenga configurada como producción.
# Así, burgercouple-web.pages.dev y main.burgercouple-web.pages.dev muestran
# siempre lo mismo (la trampa que nos mordió en BC OS; ver README).
RAMA="main"

# Versión fija de la herramienta oficial de Cloudflare (wrangler).
# Fija y no "la última", para que una actualización de Cloudflare no nos
# cambie el comportamiento de un día para el otro.
VERSION_WRANGLER="4.139.0"

# Archivo privado con el token. Está en .gitignore y con permisos 600
# (solo tu usuario lo puede leer). Nunca se publica ni se sube a GitHub.
CREDENCIALES=".cloudflare-credenciales"

API="https://api.cloudflare.com/client/v4"
MODO_PRUEBA=0
[ "${1:-}" = "--prueba" ] && MODO_PRUEBA=1

# ---------------------------------------------------------------------
#  Funciones de ayuda
# ---------------------------------------------------------------------
# Deja la ventana abierta al terminar, así llegás a leer el resultado.
# (Si no hay nadie mirando, como en una prueba automática, no espera.)
pausa_y_salir() {
  echo
  if [ -t 0 ]; then read -r -p "Apretá Enter para cerrar esta ventana." _; fi
  exit "${1:-0}"
}
error() { echo; echo "❌  $1"; pausa_y_salir 1; }
paso()  { echo; echo "▶  $1"; }

# Lee un dato de una respuesta de Cloudflare (que viene en formato JSON).
# Usamos node porque ya hace falta para publicar, y así no dependemos de
# herramientas que la Mac no trae de fábrica.
leer_json() {
  node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      try { const v = process.argv[1].split(".").reduce((o, k) => o == null ? o : o[k], JSON.parse(s));
            process.stdout.write(v == null ? "" : String(v)); } catch (e) { process.stdout.write(""); }
    });' "$1"
}

echo "================================================"
echo "   Publicar la web de Burger Couple"
echo "================================================"
[ "$MODO_PRUEBA" = 1 ] && echo "   (MODO PRUEBA: arma todo pero no publica)"

# ---------------------------------------------------------------------
#  1. Chequeos previos
# ---------------------------------------------------------------------
paso "Revisando que esté todo lo necesario..."
[ -f "sitio/index.html" ] || error "No encuentro la carpeta 'sitio' con la página. ¿Moviste este archivo fuera de la carpeta del proyecto?"

if ! command -v node >/dev/null 2>&1 || ! command -v npx >/dev/null 2>&1; then
  echo "Falta instalar Node.js, el programa que usa la herramienta de Cloudflare."
  echo "Instalalo desde https://nodejs.org (botón verde 'LTS'), y después volvé a hacer doble clic acá."
  command -v open >/dev/null 2>&1 && open "https://nodejs.org"
  pausa_y_salir 1
fi
command -v curl >/dev/null 2>&1 || error "Falta el programa curl (viene con la Mac; si no está, avisale a Claude)."
echo "   Node $(node --version) y curl: OK"

# ---------------------------------------------------------------------
#  2. Token de Cloudflare
# ---------------------------------------------------------------------
paso "Buscando el token de Cloudflare..."
if [ -n "${CLOUDFLARE_API_TOKEN:-}" ] && [ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
  # Si ya viene cargado de afuera (lo usa Claude para probar desde la nube),
  # no se escribe ningún archivo.
  TOKEN="$CLOUDFLARE_API_TOKEN"; CUENTA="$CLOUDFLARE_ACCOUNT_ID"
  echo "   Usando el token cargado en el entorno."
else
  if [ ! -f "$CREDENCIALES" ]; then
    [ -t 0 ] || error "No hay token guardado y no hay nadie para escribirlo. Hacé doble clic en el archivo desde el Finder."
    echo "Es la primera vez: necesito dos datos de Cloudflare (el README explica dónde sacarlos)."
    echo "Lo que pegues no se ve en pantalla: es normal, es por seguridad."
    read -r -s -p "   Pegá el TOKEN y apretá Enter: " TOKEN; echo
    read -r -p "   Pegá el ACCOUNT ID y apretá Enter: " CUENTA
    [ -n "$TOKEN" ] && [ -n "$CUENTA" ] || error "Quedó algún dato vacío. Volvé a hacer doble clic y probá de nuevo."
    # umask 077 hace que el archivo nazca privado, sin un instante en que otro lo pueda leer.
    ( umask 077; printf 'CLOUDFLARE_API_TOKEN=%s\nCLOUDFLARE_ACCOUNT_ID=%s\n' "$TOKEN" "$CUENTA" > "$CREDENCIALES" )
    echo "   Guardado en $CREDENCIALES (privado, no se publica)."
  fi
  # Se reaplica en cada publicación por si alguien copió la carpeta y se perdieron los permisos.
  chmod 600 "$CREDENCIALES"
  TOKEN="$(grep '^CLOUDFLARE_API_TOKEN=' "$CREDENCIALES" | cut -d= -f2- | tr -d '[:space:]')"
  CUENTA="$(grep '^CLOUDFLARE_ACCOUNT_ID=' "$CREDENCIALES" | cut -d= -f2- | tr -d '[:space:]')"
  [ -n "$TOKEN" ] && [ -n "$CUENTA" ] || error "El archivo $CREDENCIALES está incompleto. Borralo y volvé a hacer doble clic para cargar los datos de nuevo."
  echo "   Token encontrado (permisos del archivo: solo vos)."
fi

# Red de seguridad: si por algún motivo el archivo del token NO estuviera
# ignorado por git, frenamos antes de que termine subido a GitHub.
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git check-ignore -q "$CREDENCIALES" || error "El archivo $CREDENCIALES no está protegido en .gitignore. No publico hasta que eso se arregle (avisale a Claude)."
fi

# ---------------------------------------------------------------------
#  3. Proyecto en Cloudflare (y la trampa de las dos direcciones)
# ---------------------------------------------------------------------
if [ "$MODO_PRUEBA" = 1 ]; then
  DIRECCION="$PROYECTO.pages.dev"
  paso "Modo prueba: salteo la conexión con Cloudflare."
else
  paso "Conectando con Cloudflare (proyecto: $PROYECTO)..."
  AUTH=(-H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json")
  RESPUESTA="$(curl -sS "${AUTH[@]}" "$API/accounts/$CUENTA/pages/projects/$PROYECTO")" \
    || error "No me pude conectar con Cloudflare. ¿Hay internet?"

  if [ "$(printf '%s' "$RESPUESTA" | leer_json success)" != "true" ]; then
    CODIGO="$(printf '%s' "$RESPUESTA" | leer_json errors.0.code)"
    if [ "$CODIGO" = "8000007" ]; then
      # 8000007 = "el proyecto no existe". Pasa solo la primera vez: lo creamos
      # ya con "main" como rama de producción, que es lo que evita la trampa.
      echo "   El proyecto todavía no existe: lo creo."
      RESPUESTA="$(curl -sS "${AUTH[@]}" -X POST "$API/accounts/$CUENTA/pages/projects" \
        --data "{\"name\":\"$PROYECTO\",\"production_branch\":\"$RAMA\"}")"
      [ "$(printf '%s' "$RESPUESTA" | leer_json success)" = "true" ] \
        || error "Cloudflare no me dejó crear el proyecto: $(printf '%s' "$RESPUESTA" | leer_json errors.0.message)"
    else
      error "Cloudflare rechazó el pedido: $(printf '%s' "$RESPUESTA" | leer_json errors.0.message). Revisá que el token tenga el permiso 'Cloudflare Pages: Edit' y que el Account ID sea el correcto."
    fi
  fi

  PRODUCCION="$(printf '%s' "$RESPUESTA" | leer_json result.production_branch)"
  if [ "$PRODUCCION" != "$RAMA" ]; then
    # Si alguien cambió la rama de producción desde el panel, la volvemos a
    # "main". Si no, publicaríamos en una dirección y la otra quedaría vieja.
    echo "   La rama de producción era '$PRODUCCION'; la corrijo a '$RAMA'."
    RESPUESTA="$(curl -sS "${AUTH[@]}" -X PATCH "$API/accounts/$CUENTA/pages/projects/$PROYECTO" \
      --data "{\"production_branch\":\"$RAMA\"}")"
    [ "$(printf '%s' "$RESPUESTA" | leer_json success)" = "true" ] || error "No pude corregir la rama de producción."
  fi

  # La dirección exacta la decide Cloudflare (si el nombre ya estaba tomado,
  # le agrega letras al final). Por eso la leemos y no la escribimos a mano.
  DIRECCION="$(printf '%s' "$RESPUESTA" | leer_json result.subdomain)"
  [ -n "$DIRECCION" ] || DIRECCION="$PROYECTO.pages.dev"
  echo "   Proyecto listo. Dirección: https://$DIRECCION"
fi

# ---------------------------------------------------------------------
#  4. Preparar una copia para publicar
# ---------------------------------------------------------------------
# Trabajamos sobre una copia temporal para no tocar los archivos originales:
# en la copia se reemplazan los marcadores __DIRECCION__, __VERSION__ y __FECHA__.
paso "Preparando los archivos..."
VERSION="$(date +%Y-%m-%d_%H%M%S)"
FECHA="$(date +%Y-%m-%d)"
COPIA="$(mktemp -d)/sitio"
cp -R sitio "$COPIA" || error "No pude copiar la carpeta sitio."

node -e '
  const fs = require("fs"), path = require("path");
  const [dir, direccion, version, fecha] = process.argv.slice(1);
  (function recorrer(d) {
    for (const f of fs.readdirSync(d)) {
      const p = path.join(d, f);
      if (fs.statSync(p).isDirectory()) { recorrer(p); continue; }
      if (!/\.(html|txt|xml)$/.test(f)) continue;
      const t = fs.readFileSync(p, "utf8");
      const n = t.split("__DIRECCION__").join(direccion).split("__VERSION__").join(version).split("__FECHA__").join(fecha);
      if (n !== t) fs.writeFileSync(p, n);
    }
  })(dir);' "$COPIA" "$DIRECCION" "$VERSION" "$FECHA" || error "No pude preparar los archivos."

# Controles de seguridad antes de publicar nada:
if grep -rq "__DIRECCION__\|__VERSION__\|__FECHA__" "$COPIA"; then
  error "Quedó algún marcador sin reemplazar. No publico una web a medio armar."
fi
if grep -rqF "$TOKEN" "$COPIA"; then
  error "¡El token apareció dentro de los archivos a publicar! Freno todo. Avisale a Claude."
fi
echo "   Versión $VERSION lista ($(find "$COPIA" -type f | wc -l | tr -d ' ') archivos)."

if [ "$MODO_PRUEBA" = 1 ]; then
  echo
  echo "✅  Prueba terminada: todo armado en $COPIA, sin publicar."
  pausa_y_salir 0
fi

# ---------------------------------------------------------------------
#  5. Publicar
# ---------------------------------------------------------------------
paso "Publicando (la primera vez tarda un poco más porque descarga la herramienta de Cloudflare)..."
CLOUDFLARE_API_TOKEN="$TOKEN" CLOUDFLARE_ACCOUNT_ID="$CUENTA" WRANGLER_SEND_METRICS=false CI=true \
  npx --yes "wrangler@$VERSION_WRANGLER" pages deploy "$COPIA" \
    --project-name "$PROYECTO" --branch "$RAMA" \
    --commit-dirty=true --commit-message "Publicación $VERSION" \
  || error "La publicación falló. Copiá el texto de arriba y pasáselo a Claude."

# ---------------------------------------------------------------------
#  6. Verificar las DOS direcciones
# ---------------------------------------------------------------------
# No alcanza con que Cloudflare diga "listo": pedimos el archivo version.txt
# a las dos direcciones y comprobamos que ambas tengan ESTA versión.
paso "Comprobando que las dos direcciones muestren esta versión..."
PRINCIPAL="https://$DIRECCION"
RAMA_URL="https://$RAMA.$DIRECCION"
OK_PRINCIPAL=0; OK_RAMA=0
for intento in 1 2 3 4 5 6 7 8 9 10 11 12; do
  [ "$(curl -s "$PRINCIPAL/version.txt?v=$intento" | tr -d '[:space:]')" = "$VERSION" ] && OK_PRINCIPAL=1
  [ "$(curl -s "$RAMA_URL/version.txt?v=$intento" | tr -d '[:space:]')" = "$VERSION" ] && OK_RAMA=1
  [ "$OK_PRINCIPAL" = 1 ] && [ "$OK_RAMA" = 1 ] && break
  sleep 5
done

echo "$VERSION  $PRINCIPAL  principal=$OK_PRINCIPAL rama=$OK_RAMA" >> publicaciones.log

echo
if [ "$OK_PRINCIPAL" = 1 ] && [ "$OK_RAMA" = 1 ]; then
  echo "================================================"
  echo "✅  PUBLICADO. Las dos direcciones muestran la versión $VERSION:"
  echo
  echo "     $PRINCIPAL        ← esta es la que se comparte"
  echo "     $RAMA_URL   (copia técnica, igual a la de arriba)"
  echo "================================================"
  command -v open >/dev/null 2>&1 && [ "$(uname)" = "Darwin" ] && open "$PRINCIPAL"
  pausa_y_salir 0
else
  echo "⚠️  Se publicó, pero después de un minuto no todas las direcciones muestran la versión nueva:"
  echo "     $PRINCIPAL  → $([ "$OK_PRINCIPAL" = 1 ] && echo 'OK' || echo 'TODAVÍA VIEJA')"
  echo "     $RAMA_URL  → $([ "$OK_RAMA" = 1 ] && echo 'OK' || echo 'TODAVÍA VIEJA')"
  echo "   A veces Cloudflare tarda unos minutos más. Si en 10 minutos sigue igual, avisale a Claude."
  pausa_y_salir 1
fi
