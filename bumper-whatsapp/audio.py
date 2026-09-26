"""Diseño de sonido del bumper (6 s), 100 % sintetizado: sin música ni samples con derechos.

    python3 audio.py  ->  sfx.wav (48 kHz, estéreo)

Los tiempos coinciden con el timeline de index.html.
"""
import wave
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

SR = 48000
DUR = 6.0
N = int(SR * DUR)
rng = np.random.default_rng(7)
L = np.zeros(N)
R = np.zeros(N)
VL = np.zeros(N)   # envío a reverb
VR = np.zeros(N)


def tt(d):
    return np.arange(int(d * SR)) / SR


def noise(d):
    return rng.uniform(-1, 1, int(d * SR))


def filt(x, kind, fc, order=2):
    return sosfilt(butter(order, fc, btype=kind, fs=SR, output="sos"), x)


def sweep_lp(x, f0, f1):
    """Low-pass de un polo con corte variable en el tiempo (exponencial f0 -> f1)."""
    fc = f0 * (f1 / f0) ** np.linspace(0, 1, len(x))
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    z = 0.0
    for n in range(len(x)):
        z = (1 - a[n]) * x[n] + a[n] * z
        y[n] = z
    return y


def phase(f):
    return 2 * np.pi * np.cumsum(f) / SR


def saw(ph):
    return 2 * ((ph / (2 * np.pi)) % 1.0) - 1


def place(sig, t, gain=1.0, pan=0.0, verb=0.0):
    i = int(round(t * SR))
    if i >= N:
        return
    s = sig[: N - i] * gain
    gl = np.sqrt(0.5 * (1 - pan)) * 1.4142
    gr = np.sqrt(0.5 * (1 + pan)) * 1.4142
    L[i:i + len(s)] += s * gl
    R[i:i + len(s)] += s * gr
    if verb:
        VL[i:i + len(s)] += s * gl * verb
        VR[i:i + len(s)] += s * gr * verb


# ---------- instrumentos ----------
def kick(d=0.45, f_lo=48, f_hi=150):
    t = tt(d)
    body = np.sin(phase(f_lo + f_hi * np.exp(-t / 0.035))) * np.exp(-t / 0.16)
    click = filt(noise(d) * np.exp(-t / 0.004), "highpass", 2500) * 0.35
    return np.tanh(1.6 * (body + click))


def impact(d=1.6):
    t = tt(d)
    k = kick(d, 36, 170) * 1.1
    sub = np.sin(phase(np.full(len(t), 38.0))) * np.exp(-t / 0.55) * 0.6
    crash = filt(noise(d), "lowpass", 5000) * np.exp(-t / 0.22) * 0.45
    return np.tanh(1.3 * (k + sub + crash))


def hat(d=0.07):
    t = tt(d)
    return filt(noise(d), "highpass", 7500) * np.exp(-t / 0.018)


def whoosh(d, f0=300, f1=5000, shape="swell"):
    t = tt(d)
    x = filt(noise(d), "highpass", 150)
    x = sweep_lp(x, f0, f1)
    env = np.sin(np.pi * t / d) ** 2 if shape == "swell" else (t / d) ** 2.2
    return x * env * 3.0


def tick(d=0.04):
    t = tt(d)
    return (filt(noise(d), "highpass", 3000) * np.exp(-t / 0.003) * 0.7
            + np.sin(phase(np.full(len(t), 2200.0))) * np.exp(-t / 0.008) * 0.4)


def env_ar(t, a=0.015, r=0.06):
    d = t[-1]
    return np.clip(t / a, 0, 1) * np.clip((d - t) / r, 0, 1)


def drill(d=0.3):
    t = tt(d)
    f = 70 + 140 * (1 - np.exp(-t / 0.08))
    ph = phase(f)
    x = saw(ph) * 0.6 + saw(ph * 2.01) * 0.3 + filt(noise(d), "bandpass", [800, 3000]) * 0.25
    x *= 1 + 0.35 * np.sin(2 * np.pi * 28 * t)
    return filt(x, "lowpass", 2400) * env_ar(t)


def grinder(d=0.3):
    t = tt(d)
    f = 380 + 900 * (1 - np.exp(-t / 0.07))
    x = np.sin(phase(f)) * 0.5 + saw(phase(f * 0.5)) * 0.2 + filt(noise(d), "highpass", 4000) * 0.35
    return x * env_ar(t)


def sawblade(d=0.32):
    t = tt(d)
    whine = np.sin(phase(220 + 500 * (1 - np.exp(-t / 0.06)))) * 0.45
    ring = sum(np.sin(2 * np.pi * 900 * k * t) * np.exp(-t / (0.2 / k)) for k in (1, 2.76, 5.4)) * 0.25
    return (whine + ring + filt(noise(d), "bandpass", [2000, 6000]) * 0.2) * env_ar(t, 0.005, 0.08)


def welder(d=0.3):
    t = tt(d)
    imp = (rng.random(len(t)) < 0.006) * rng.uniform(0.4, 1, len(t))
    crackle = filt(imp, "highpass", 1500) * 3
    buzz = filt(np.sign(np.sin(2 * np.pi * 100 * t)), "lowpass", 900) * 0.2
    return (crackle + buzz) * env_ar(t, 0.005, 0.05)


def bass_note(f, d=0.24):
    t = tt(d)
    ph = phase(np.full(len(t), f))
    x = saw(ph) * 0.6 + np.sin(ph * 0.5) * 0.7
    cutoff = 250 + 1100 * np.exp(-t / 0.05)
    x = sweep_lp(x, cutoff[0], cutoff[-1])
    return x * np.exp(-t / 0.18) * np.clip((d - t) / 0.02, 0, 1)


def pop(f0=500, f1=1400, d=0.12):
    t = tt(d)
    return np.sin(phase(f0 + (f1 - f0) * np.clip(t / 0.07, 0, 1))) * np.exp(-t / 0.045)


def pluck(f, d=0.5, tau=0.15):
    t = tt(d)
    return (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t)) * np.exp(-t / tau)


def chord_stab(freqs, d=2.3):
    t = tt(d)
    out = np.zeros(len(t))
    for k, f in enumerate(freqs):
        delay = int(k * 0.028 * SR)
        v = sum(saw(phase(np.full(len(t), f * det))) for det in (0.996, 1.0, 1.004)) / 3
        v = filt(v, "lowpass", 3200) * np.exp(-t / 0.9) * np.clip(t / 0.004, 0, 1)
        out[delay:] += v[: len(t) - delay]
    return out / len(freqs)


def bell(f, d=1.3):
    t = tt(d)
    return sum(a * np.sin(2 * np.pi * f * m * t) * np.exp(-t / (0.7 / m ** 0.5))
               for m, a in ((1, 1), (2.0, 0.5), (3.01, 0.3), (4.1, 0.15))) / 2


# ---------- timeline ----------
# Escena 1: barrido + golpe del titular + beat a 120 BPM
place(whoosh(0.3, 400, 6000), 0.0, 0.5, pan=-0.3)
place(impact(0.9), 0.24, 0.9)
for i, tk in enumerate(np.arange(0.25, 3.0, 0.5)):
    place(kick(), tk, 0.8 if i else 0.0)
for th in np.arange(0.5, 3.3, 0.25):
    if abs((th - 0.25) % 0.5) > 1e-6:
        place(hat(), th, 0.22, pan=0.35)
    else:
        place(hat(0.04), th, 0.08, pan=-0.35)

# bajo en corcheas con compresión lateral del bombo
notes = [82.41, 82.41, 164.8, 82.41, 98.0, 82.41, 110.0, 123.5]
bass = np.zeros(N)
for k, tb in enumerate(np.arange(0.25, 3.25, 0.25)):
    s = bass_note(notes[k % len(notes)])
    i = int(tb * SR)
    bass[i:i + len(s)] += s
duck = np.ones(N)
tN = np.arange(N) / SR
for tk in np.arange(0.25, 3.0, 0.5):
    m = tN >= tk
    duck[m] *= 1 - 0.75 * np.exp(-(tN[m] - tk) / 0.09)
bass *= duck
L += bass * 0.35
R += bass * 0.35

# herramientas (cada una con su sonido)
T = [0.5, 0.8125, 1.125, 1.4375]
for t0, fx, g, pan in zip(T, (drill, grinder, sawblade, welder), (0.5, 0.32, 0.4, 0.55), (-0.2, 0.2, -0.1, 0.15)):
    place(tick(), t0, 0.5, pan=pan)
    place(fx(), t0, g, pan=pan, verb=0.15)

# transición a la escena 2
place(whoosh(0.22, 800, 7000, "rise"), 1.58, 0.6)
place(impact(0.8), 1.8, 0.7)

# chat: enviado, escribiendo, recibido
place(pop(500, 1400), 2.2, 0.45, pan=0.25, verb=0.25)
for k, tc in enumerate((2.44, 2.53, 2.63, 2.71)):
    place(tick(0.02), tc, 0.12, pan=-0.2 + 0.1 * k)
place(pluck(1046.5), 2.78, 0.3, pan=-0.2, verb=0.35)
place(pluck(1568.0), 2.85, 0.3, pan=-0.2, verb=0.35)

# subida + cortina blanca + golpe de marca
place(whoosh(0.5, 300, 9000, "rise"), 3.0, 0.55)
place(whoosh(0.26, 1500, 8000), 3.24, 0.5, pan=0.4)
place(impact(1.8), 3.5, 1.0, verb=0.3)
place(chord_stab([164.8, 246.9, 329.6, 415.3, 493.9, 659.3]), 3.52, 0.55, verb=0.5)

# tipeo del número + confirmación
phone = "+54 9 11 3762-2288"
for k in range(len(phone)):
    place(tick(0.02), 3.86 + k * 0.022, 0.1, pan=-0.3 + 0.6 * k / len(phone))
type_end = 3.86 + len(phone) * 0.022
place(bell(1318.5), type_end + 0.1, 0.35, verb=0.5)
place(bell(1975.5), type_end + 0.16, 0.2, pan=0.3, verb=0.5)
place(filt(noise(0.5), "highpass", 6000) * np.sin(np.pi * tt(0.5) / 0.5) ** 2, type_end + 0.08, 0.12, pan=0.2)

# ---------- reverb + master ----------
ir_t = tt(1.4)
irL = filt(noise(1.4), "lowpass", 6000) * np.exp(-ir_t / 0.38)
irR = filt(noise(1.4), "lowpass", 6000) * np.exp(-ir_t / 0.38)
irL /= np.sqrt(np.sum(irL ** 2))
irR /= np.sqrt(np.sum(irR ** 2))
L += fftconvolve(VL, irL)[:N] * 0.9
R += fftconvolve(VR, irR)[:N] * 0.9

mix = np.stack([L, R], axis=1)
mix = filt(mix.T, "highpass", 28).T
mix /= np.max(np.abs(mix))          # saturación suave, no aplastar
drive = 1.6
mix = np.tanh(mix * drive) / np.tanh(drive)
fade = np.clip((DUR - tN) / 0.25, 0, 1)[:, None]
mix *= fade
mix *= 0.95 / np.max(np.abs(mix))

with wave.open("sfx.wav", "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((mix * 32767).astype("<i2").tobytes())
print("sfx.wav", DUR, "s")
