# Web de Burger Couple

La página pública de Burger Couple. Este archivo está escrito para Mati, no
para un programador: explica qué hace la web, cómo se publica, qué decidimos
y por qué, qué falta y qué trampas conocidas tiene.

_Última actualización: 25/09/2026._

---

## Qué hace la página hoy

Es una sola página, larga, pensada primero para el celular. De arriba abajo:

1. **Portada**: "Burgers para fetichistas", con la ilustración del brindis
   dentro de un marco tipo pantalla de TV, y dos botones: *Ver los ejemplares*
   (baja al menú) y *Pedir por Rappi* (baja a los locales).
2. **Cinta que se mueve** tipo zócalo de televisión, con frases de la marca.
3. **Menú** ("Los ejemplares"): todas las hamburguesas con sus ingredientes,
   copiados de la carta de junio de 2026. **Sin precios** (ver decisiones).
   También la Box, el menú almuerzo, las entradas y el Menú La Bendi, y un
   aviso de alérgenos.
4. **Locales**: los cinco, cada uno con su color, su dirección y un botón
   *Cómo llegar* que abre Google Maps. Recoleta figura como cerrado por
   refacciones. Boedo figura como abierto, con la etiqueta "Nuevo".
5. **Historia**: Víctor y Dana, Loco Piña y la línea de tiempo desde 2017.
6. **Pie**: redes sociales.

Las **ilustraciones en duotono** de las cartas están repartidas por la página
como "figuritas" en círculos de color, al lado de los títulos (Menú,
Especiales, Veggies, Locales, Historia y pie).

Además tiene:
- **Página de error** ("Loco Piña se comió esta página"), que aparece si
  alguien entra a una dirección que no existe.
- **Vista previa para compartir**: cuando se manda el link por WhatsApp o
  Instagram aparece una imagen con el logo, la frase y el brindis.
- **Datos para Google**: título y descripción con los cinco barrios, y una
  ficha "invisible" que le dice a Google que somos cinco restaurantes y
  dónde están.

**Todo lo que dice "A CONFIRMAR"** (con borde punteado) es un dato que
todavía no tenemos. Está así a propósito, para que nadie lo tome como real.

---

## Cómo publicar

### Una sola vez: tener la carpeta en tu Mac

La carpeta vive en GitHub (`flamaboy/da`). La forma más cómoda de tenerla en
la Mac y recibir cada cambio es **GitHub Desktop** (gratis): *File → Clone
repository → flamaboy/da*. Cada vez que Claude hace cambios, apretás
**Fetch origin** y después **Pull**.

> Bajar la carpeta como ZIP desde la web de GitHub también funciona, pero
> puede hacer que el Mac no deje abrir el `desplegar.command` (ver trampas).

### Una sola vez: el token de Cloudflare

El script te lo pide la primera vez que lo abrís. Son dos datos:

**El token** (una "llave" que le da permiso al script para publicar):
1. Entrá a <https://dash.cloudflare.com> con tu cuenta (la misma de BC OS).
2. Arriba a la derecha, tocá el ícono de tu perfil → **Profile** (Perfil).
3. En el menú de la izquierda: **API Tokens** → botón **Create Token**.
4. Abajo de todo: **Create Custom Token** → **Get started**.
5. **Token name**: `web burger couple` (es para reconocerlo).
6. **Permissions**: elegí `Account` → `Cloudflare Pages` → `Edit`.
7. **Account Resources**: `Include` → tu cuenta.
8. **Continue to summary** → **Create Token**.
9. Copiá el token: **Cloudflare lo muestra una sola vez**.

**El Account ID** (el número de tu cuenta): en <https://dash.cloudflare.com>,
entrá a tu cuenta; aparece en la página principal, a la derecha, como
"Account ID", con un botón para copiarlo. (Cloudflare cambia su panel
seguido: si no lo encontrás, mandale una captura a Claude.)

Usá **un token nuevo, solo para esta web**, no el de BC OS. Así, si algún día
hay que anularlo, BC OS sigue funcionando.

Los dos datos quedan guardados en un archivo oculto de esta carpeta,
`.cloudflare-credenciales`, que solo tu usuario puede leer y que **nunca** se
sube a GitHub ni se publica. Si algún día hay que cambiar el token, borrá ese
archivo y la próxima vez el script te lo vuelve a pedir.

### Cada vez que quieras publicar

1. Abrí la carpeta en el Finder.
2. Doble clic en **`desplegar.command`**.
3. Se abre una ventana negra que va contando lo que hace. Al final dice
   **✅ PUBLICADO** con la dirección de la web y la abre en el navegador.
4. Apretá Enter para cerrar la ventana.

La primera vez tarda un poco más porque descarga la herramienta de Cloudflare.

La dirección de la web es **https://burgercouple-web.pages.dev**. Esa es la
que se comparte. Ojo con la que tiene un código al principio (ver trampa 1 bis).

---

## Cómo está armada

```
desplegar.command    ← el botón de publicar (doble clic)
README.md            ← este archivo
respaldos/           ← copias de seguridad antes de cada tanda de cambios
sitio/               ← LA WEB: todo lo que está acá se publica, y nada más
   index.html        ← la página (textos, menú, locales)
   estilos.css       ← colores, tipografías y diseño
   404.html          ← página de error
   imagenes/         ← logos, fotos de hamburguesas, ilustraciones
   fuentes/          ← las cuatro tipografías
   robots.txt, sitemap.xml   ← para Google
   _headers          ← instrucciones para Cloudflare (seguridad y velocidad)
   version.txt       ← la fecha de la última publicación (la usa el script)
```

**Solo se publica la carpeta `sitio/`.** El README, los respaldos, el script
y el token nunca salen a internet.

---

## Decisiones que tomamos y por qué

| Decisión | Por qué |
|---|---|
| **Página estática, sin base de datos** | La web solo muestra información. Así es más rápida, más barata y tiene menos cosas que se puedan romper. La base de datos (Supabase) entra en la etapa 2, para el club de puntos. |
| **Cloudflare Pages, no Workers** | El PDF de marca proponía Next.js + Workers, que es mucho más pesado. Para una página estática, Pages es lo más simple, y es lo que ya usás en BC OS. |
| **Primero informativa, club después** | El club necesita saber cómo se registran las ventas en los locales. Si no, cualquiera podría sumarse puntos falsos. |
| **Sin precios en la web** | Cambian seguido: un precio viejo genera reclamos. Viven en Rappi y en la carta de cada local. |
| **Pedidos por Rappi, reservas por WhatsApp** | Es como funciona hoy. Los botones están listos, falta cargar los links (A CONFIRMAR). |
| **Estética del PDF de marca y de las cartas** | Rosa, violeta y turquesa, el damero, el estallido y las ilustraciones en duotono. Tipografías: Erica One (títulos gritones), Bricolage Grotesque (títulos), Instrument Sans (texto) y DM Mono (datos). El PDF aclara que son de prototipo y no oficiales. |
| **Logo sacado de las cartas en PDF** | Viene en vector (no se pixela). No es el archivo maestro del diseñador, pero es el mismo dibujo. |
| **Cada local con su color** | Como sus cartas: La Mansión violeta, La Tercera celeste, Los 90's naranja. Boedo (turquesa) y Recoleta (amarillo) todavía no tienen carta: los elegimos de la paleta. |
| **Ilustraciones de famosos sin nombres** | Se usan las de las cartas, tal cual, a pedido de Mati. |
| **Ilustraciones como figuritas repartidas, no en una franja aparte** | Mati prefirió que decoren toda la página. Van en círculos (el motivo "duotono" del PDF) que las recortan, así nunca tapan textos ni botones. |
| **Loco Piña sin foto** | Ninguna ilustración de la carta es seguro que sea Víctor. Cuando haya una foto aprobada, se agrega. |
| **Tipografías servidas desde nuestra web** | Evita conectarse a Google Fonts: con mala señal, cada conexión de más se nota. |
| **Nada de JavaScript** | La página no necesita ningún programa para funcionar: carga más rápido y anda en cualquier celular. |
| **La cinta se queda quieta si el celular pide "reducir movimiento"** | Accesibilidad: lo pide el PDF de marca. |
| **Horarios y teléfonos no se le informan a Google hasta confirmarlos** | Si le damos un dato falso, Google lo muestra en grande. |

---

## Qué falta

**Datos (los tiene que pasar Mati):**
- [ ] Horarios de cada local.
- [ ] Link de Rappi de cada local.
- [ ] WhatsApp o teléfono de cada local (para reservas).
- [ ] Dirección exacta de Boedo, y su nombre si tiene uno propio.
- [ ] Contacto general: mail, WhatsApp de la marca, TikTok.
- [ ] Fotos originales en buena calidad. Las de las cartas son chicas
      (unos 200 píxeles): en el celular andan, en pantallas grandes se ven
      algo blandas.
- [ ] Logo maestro del diseñador (SVG o AI).
- [ ] Información de alérgenos por producto (hoy hay un aviso general).

**Publicación:**
- [ ] Crear el token de Cloudflare y hacer la primera publicación.
- [ ] Más adelante: conectar un dominio propio (por ejemplo `burgercouple.com.ar`).

**Mejoras para después:**
- [ ] Una página por local (ayuda a aparecer en Google con "hamburguesas + barrio").
- [ ] Etapa 2: club de puntos con Supabase.

---

## Trampas conocidas

**1. Las dos direcciones de Cloudflare (la que nos mordió en BC OS).**
Cloudflare le da una dirección a cada "rama" del proyecto. Por eso existen
`burgercouple-web.pages.dev` y también `main.burgercouple-web.pages.dev`.
Si el script publica en una rama que no es la "de producción", solo se
actualiza una de las dos y la otra queda congelada en una versión vieja.
**Cómo lo resolvimos:**
- El script publica siempre en la rama `main`.
- Antes de publicar, le pregunta a Cloudflare cuál es la rama de producción,
  y si no es `main`, la corrige.
- Después de publicar, abre las dos direcciones y comprueba que las dos
  muestren la misma versión. Si una quedó vieja, te avisa con ⚠️ en vez de
  decir ✅.
La dirección que se comparte es siempre la **sin** `main.` adelante.

**1 bis. La tercera dirección: la "foto fija" de cada publicación.**
Además, cada vez que publicás, Cloudflare crea una dirección con un código
al principio, por ejemplo `e3590b06.burgercouple-web.pages.dev`, y la muestra
en la ventana mientras publica. **Esa dirección queda congelada para siempre
en esa versión.** Sirve para comparar versiones viejas, pero **nunca se
comparte**. La primera publicación (25/09/2026) quedó en
`e3590b06.burgercouple-web.pages.dev`. El mensaje final del script ahora lo
avisa.

**2. El token puede tocar todos los proyectos de la cuenta, incluido BC OS.**
Cloudflare no deja limitar un token a un solo proyecto de Pages. Por eso el
nombre del proyecto (`burgercouple-web`) está escrito una sola vez dentro del
script, y el script solo trabaja sobre ese nombre. No borra nada.

**3. "No se puede abrir desplegar.command porque es de un desarrollador no identificado".**
El Mac lo dice la primera vez, sobre todo si bajaste la carpeta como ZIP.
Solución: **clic derecho → Abrir → Abrir**. Solo hace falta una vez. Si en
cambio dice "no tenés permiso", pedile a Claude el comando para arreglarlo
(pasa cuando el ZIP pierde el permiso de "ejecutable").

**4. Hace falta Node.js en la Mac.**
Es el programa que usa la herramienta de Cloudflare. Si no está, el script te
avisa y abre la página para bajarlo (botón "LTS").

**5. Una imagen reemplazada puede tardar hasta una semana en verse en algunos celulares.**
Para que la web cargue rápido, los celulares guardan las imágenes una semana.
Si reemplazamos una imagen con **el mismo nombre**, algunos pueden seguir
viendo la vieja. Por eso, cuando cambiemos una imagen, conviene usar un nombre
nuevo.

**6. WhatsApp e Instagram guardan la vista previa del link.**
Si cambiamos la imagen para compartir, WhatsApp puede seguir mostrando la
vieja durante un tiempo. No es un error de la web.

---

## Respaldos

Antes de cada tanda de cambios, Claude copia lo que va a tocar a
`respaldos/` en una carpeta con la fecha. Para volver atrás, ver
`respaldos/LEEME.md`.

## Historial

- **25/09/2026**: primera versión. Página única con menú, locales, Canal
  Fetiche e historia; script de publicación con la verificación de las dos
  direcciones. Se borró el portfolio personal que había en la carpeta (a
  pedido de Mati; se puede recuperar del historial de GitHub).
- **25/09/2026**: primera publicación, hecha por Mati desde su Mac.
- **25/09/2026**: se sacó la franja "Canal Fetiche"; sus seis ilustraciones
  quedaron repartidas por la página como figuritas. Respaldo en
  `respaldos/2026-09-25_*_quitar-canal-fetiche/`.
