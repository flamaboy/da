# Bumpers WhatsApp · Versa Máquinas

Hay dos piezas verticales de 1080×1920, H.264 + AAC a 30 fps, con el audio normalizado a unos −14 LUFS. Las dos invitan a escribir al **+54 9 11 3762-2288**.

| Pieza | Público | Duración | Archivo |
|---|---|---|---|
| Bumper consumidor | Cliente final (Reels, Stories, TikTok) | 6 s | [`out/versa-whatsapp-bumper.mp4`](out/versa-whatsapp-bumper.mp4) |
| Story B2B | Ferreterías y revendedores | 7 s | [`out/versa-whatsapp-b2b-stories.mp4`](out/versa-whatsapp-b2b-stories.mp4) |

## Story B2B para ferreterías (`b2b.html`)

| Tiempo | Escena |
|---|---|
| 0 – 2,2 s | «¿Tenés una ferretería?» → «Sumá Versa a tu negocio», mientras una góndola se llena de cajas Versa al ritmo del beat |
| 2,2 – 4,2 s | «Vendé con respaldo»: +25 años de trayectoria · Línea completa (eléctricas, neumáticas y jardín) · Servicio técnico |
| 4,2 – 7 s | Cierre: «¿Querés ser revendedor?», el botón de WhatsApp con el número, el mensaje sugerido «Hola, tengo una ferretería 👋» y «te pasamos las condiciones comerciales» |

Los textos clave quedan dentro de la zona segura de Stories: se dejan libres unos 270 px arriba y 380 px abajo. Con `b2b.html?guides` se ven esas franjas marcadas.

## Bumper consumidor (`index.html`)

| Tiempo | Escena |
|---|---|
| 0 – 1,8 s | «¿Qué máquina necesitás?»: pasan Taladros → Amoladoras → Sierras → Soldadoras, cada una con su sonido |
| 1,8 – 3,5 s | «Escribinos por WhatsApp»: chat con una consulta y la respuesta «Te asesoramos al toque» |
| 3,5 – 6 s | Cierre con el logo, el botón de WhatsApp (el número se tipea) y «Elegí #VersaMaquinas» |

## Editar y volver a renderizar

- Los textos, el número (constante `PHONE`) y los tiempos están en el HTML de cada pieza.
- Abrí el HTML en el navegador para ver la animación en loop. Con `?t=4.5` se ve un cuadro fijo.
- El sonido es 100 % sintetizado, sin música con derechos. Los instrumentos están en `sfx_lib.py`. Los tiempos de cada pieza están en `audio.py` (consumidor) y `audio_b2b.py` (B2B). Si cambiás los tiempos del video, cambiá también los del audio.

```bash
pip install numpy scipy                 # para el audio
python3 audio.py && python3 audio_b2b.py   # genera sfx.wav y sfx-b2b.wav
npm i -g playwright                     # Chromium para renderizar
export FFMPEG=/ruta/a/ffmpeg
node render.js                                                                          # consumidor
node render.js --page b2b.html --audio sfx-b2b.wav --out versa-whatsapp-b2b-stories.mp4  # B2B
```

`render.js` captura la animación a 60 fps y la exporta a 30 fps mezclando cuadros vecinos, lo que da un leve motion blur.
