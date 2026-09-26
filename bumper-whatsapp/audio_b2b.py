"""Sonido de la Story B2B para ferreterías (9 s). Los tiempos coinciden con b2b.html.

    python3 audio_b2b.py  ->  sfx-b2b.wav (48 kHz, estéreo)

Grilla a 150 BPM: negra = 0,4 s, corchea = 0,2 s, arrancando en 0,2 s.
"""
import numpy as np
from sfx_lib import (Mix, bell, chord_stab, clank, filt, hat, impact, kick, noise, pad, pluck,
                     pop, snap, thud, tick, tt, whoosh)

m = Mix(9.0)
BEAT = 0.4

# Escena 1: titular + góndola que se llena de cajas
m.place(whoosh(0.28, 400, 6000), 0.0, 0.5, pan=-0.3)
m.place(impact(0.9), 0.2, 0.9)
m.place(whoosh(0.3, 250, 3000), 0.2, 0.35, pan=0.3)
m.place(clank(), 0.45, 0.45, verb=0.2)
for k, t in enumerate((0.6, 0.8, 1.0, 1.2, 1.4, 1.6)):
    m.place(thud(150 - 8 * (k % 3)), t, 0.75, pan=(-0.25, 0.0, 0.25)[k % 3])
    m.place(tick(0.03), t, 0.18, pan=(-0.25, 0.0, 0.25)[k % 3])
m.place(snap(), 1.6, 0.35, pan=0.2)          # cambio de titular

# beat + bajo hasta la cortina final
kicks = np.arange(0.2 + BEAT, 5.6, BEAT)
for tk in kicks:
    if abs(tk - 3.0) > 1e-6:                 # en 3.0 va el golpe de transición
        m.place(kick(), tk, 0.75)
for th in np.arange(0.4, 5.7, BEAT / 2):
    off = abs(((th - 0.2) / (BEAT / 2)) % 2 - 1) < 1e-6
    m.place(hat(), th, 0.2 if off else 0.07, pan=0.35 if off else -0.35)
m.bass_line([82.41, 82.41, 164.8, 82.41, 98.0, 82.41, 110.0, 123.5], 0.6, 5.6, BEAT / 2, kicks, gain=0.32)

# transición a la escena 2
m.place(whoosh(0.24, 800, 7000, "rise"), 2.76, 0.6, pan=-0.3)
m.place(impact(0.8), 3.0, 0.75)

# tarjetas: entran cada 0,6 s, contador del +25
for t, pan in ((3.4, -0.3), (4.0, 0.3), (4.6, -0.3)):
    m.place(whoosh(0.16, 1500, 7000, "rise"), t - 0.12, 0.35, pan=pan)
    m.place(snap(), t + 0.02, 0.55, pan=pan * 0.5)
for n in range(1, 26):
    p = 1 - np.sqrt(1 - n / 25)              # inversa del ease power2.out
    m.place(tick(0.02), 3.46 + p * 0.45, 0.08, pan=-0.2)

# subida + cortina blanca + golpe de marca
m.place(whoosh(0.56, 300, 9000, "rise"), 5.44, 0.55)
m.place(whoosh(0.26, 1500, 8000), 5.74, 0.5, pan=0.4)
m.place(impact(1.8), 6.0, 1.0, verb=0.3)
m.place(chord_stab([164.8, 246.9, 329.6, 415.3, 493.9, 659.3], 2.8), 6.02, 0.55, verb=0.5)

# tipeo del número + confirmación + mensaje enviado
phone = "+54 9 11 3762-2288"
t0, per = 6.35, 0.022
for k in range(len(phone)):
    m.place(tick(0.02), t0 + k * per, 0.1, pan=-0.3 + 0.6 * k / len(phone))
type_end = t0 + len(phone) * per
m.place(bell(1318.5), type_end + 0.1, 0.35, verb=0.5)
m.place(bell(1975.5), type_end + 0.16, 0.2, pan=0.3, verb=0.5)
m.place(filt(noise(0.5), "highpass", 6000) * np.sin(np.pi * tt(0.5) / 0.5) ** 2, type_end + 0.08, 0.12, pan=0.2)
m.place(pop(500, 1400), type_end + 0.22, 0.4, pan=0.3, verb=0.25)

# colchón que sostiene el cierre + pulsos suaves con cada anillo del botón
m.place(pad([164.8, 246.9, 329.6, 415.3], 3.0), 6.0, 0.35, verb=0.3)
for t in (type_end + 0.8, type_end + 1.5):
    m.place(pluck(1318.5, 0.6, 0.12), t, 0.1, pan=0.2, verb=0.5)

m.write("sfx-b2b.wav")
