"""Sonido del bumper para consumidor final (6 s). Los tiempos coinciden con index.html.

    python3 audio.py  ->  sfx.wav (48 kHz, estéreo)
"""
import numpy as np
from sfx_lib import (Mix, bell, chord_stab, drill, filt, grinder, hat, impact, kick, noise,
                     pluck, pop, sawblade, tick, tt, welder, whoosh)

m = Mix(6.0)

# Escena 1: barrido + golpe del titular + beat a 120 BPM
m.place(whoosh(0.3, 400, 6000), 0.0, 0.5, pan=-0.3)
m.place(impact(0.9), 0.24, 0.9)
kicks = np.arange(0.25, 3.0, 0.5)
for i, tk in enumerate(kicks):
    m.place(kick(), tk, 0.8 if i else 0.0)
for th in np.arange(0.5, 3.3, 0.25):
    if abs((th - 0.25) % 0.5) > 1e-6:
        m.place(hat(), th, 0.22, pan=0.35)
    else:
        m.place(hat(0.04), th, 0.08, pan=-0.35)
m.bass_line([82.41, 82.41, 164.8, 82.41, 98.0, 82.41, 110.0, 123.5], 0.25, 3.25, 0.25, kicks)

# herramientas (cada una con su sonido)
T = [0.5, 0.8125, 1.125, 1.4375]
for t0, fx, g, pan in zip(T, (drill, grinder, sawblade, welder), (0.5, 0.32, 0.4, 0.55), (-0.2, 0.2, -0.1, 0.15)):
    m.place(tick(), t0, 0.5, pan=pan)
    m.place(fx(), t0, g, pan=pan, verb=0.15)

# transición a la escena 2
m.place(whoosh(0.22, 800, 7000, "rise"), 1.58, 0.6)
m.place(impact(0.8), 1.8, 0.7)

# chat: enviado, escribiendo, recibido
m.place(pop(500, 1400), 2.2, 0.45, pan=0.25, verb=0.25)
for k, tc in enumerate((2.44, 2.53, 2.63, 2.71)):
    m.place(tick(0.02), tc, 0.12, pan=-0.2 + 0.1 * k)
m.place(pluck(1046.5), 2.78, 0.3, pan=-0.2, verb=0.35)
m.place(pluck(1568.0), 2.85, 0.3, pan=-0.2, verb=0.35)

# subida + cortina blanca + golpe de marca
m.place(whoosh(0.5, 300, 9000, "rise"), 3.0, 0.55)
m.place(whoosh(0.26, 1500, 8000), 3.24, 0.5, pan=0.4)
m.place(impact(1.8), 3.5, 1.0, verb=0.3)
m.place(chord_stab([164.8, 246.9, 329.6, 415.3, 493.9, 659.3]), 3.52, 0.55, verb=0.5)

# tipeo del número + confirmación
phone = "+54 9 11 3762-2288"
for k in range(len(phone)):
    m.place(tick(0.02), 3.86 + k * 0.022, 0.1, pan=-0.3 + 0.6 * k / len(phone))
type_end = 3.86 + len(phone) * 0.022
m.place(bell(1318.5), type_end + 0.1, 0.35, verb=0.5)
m.place(bell(1975.5), type_end + 0.16, 0.2, pan=0.3, verb=0.5)
m.place(filt(noise(0.5), "highpass", 6000) * np.sin(np.pi * tt(0.5) / 0.5) ** 2, type_end + 0.08, 0.12, pan=0.2)

m.write("sfx.wav")
