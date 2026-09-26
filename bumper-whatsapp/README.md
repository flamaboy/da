# Bumper WhatsApp · Versa Máquinas

Video de 6 s, vertical 1080×1920 (Reels, Stories, TikTok y estados de WhatsApp), que invita a escribir al **+54 9 11 3762-2288**.

**Video final:** [`out/versa-whatsapp-bumper.mp4`](out/versa-whatsapp-bumper.mp4). Es H.264 + AAC, 30 fps, con el audio normalizado a −14 LUFS.

## Guion

| Tiempo | Escena |
|---|---|
| 0 – 1,8 s | «¿Qué máquina necesitás?»: pasan Taladros → Amoladoras → Sierras → Soldadoras, cada una con su sonido |
| 1,8 – 3,5 s | «Escribinos por WhatsApp»: chat con una consulta y la respuesta «Te asesoramos al toque» |
| 3,5 – 6 s | Cierre con el logo, el botón de WhatsApp (el número se tipea) y «Elegí #VersaMaquinas» |

## Editar y volver a renderizar

- Los textos, el número y los tiempos están en `index.html`. El número está en la constante `PHONE`.
- Abrí `index.html` en el navegador para ver la animación en loop. Con `index.html?t=4.5` se ve un cuadro fijo.
- El sonido sale de `audio.py`. Es 100 % sintetizado, sin música con derechos. Si cambiás los tiempos del video, cambiá también los de este archivo.

```bash
pip install numpy scipy            # para el audio
python3 audio.py                   # genera sfx.wav
npm i -g playwright                # Chromium para renderizar
FFMPEG=/ruta/a/ffmpeg node render.js   # genera out/versa-whatsapp-bumper.mp4
```

`render.js` captura la animación a 60 fps y la exporta a 30 fps mezclando cuadros vecinos, lo que da un leve motion blur.
