"""Instrumentos y mezcla para el diseño de sonido de los bumpers.

Todo es sintetizado (sin música ni samples con derechos). Lo usan audio.py y audio_b2b.py.
"""
import wave
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

SR = 48000
rng = np.random.default_rng(7)


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


def env_ar(t, a=0.015, r=0.06):
    d = t[-1]
    return np.clip(t / a, 0, 1) * np.clip((d - t) / r, 0, 1)


# ---------- percusión y efectos ----------
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


def snap(d=0.25):
    """Golpe seco tipo snare para textos que entran de costado."""
    t = tt(d)
    body = np.sin(phase(np.full(len(t), 190.0))) * np.exp(-t / 0.04) * 0.6
    rattle = filt(noise(d), "bandpass", [1200, 6000]) * np.exp(-t / 0.07)
    return np.tanh(1.4 * (body + rattle))


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


def thud(f=140, d=0.3):
    """Caja de cartón que cae sobre un estante."""
    t = tt(d)
    body = np.sin(phase(f * 0.5 + f * 0.5 * np.exp(-t / 0.03))) * np.exp(-t / 0.07)
    card = filt(noise(d), "lowpass", 900) * np.exp(-t / 0.035) * 0.8
    return np.tanh(1.5 * (body + card))


def clank(d=0.6):
    """Estantería metálica que se asienta."""
    t = tt(d)
    ring = sum(a * np.sin(2 * np.pi * 180 * m * t) * np.exp(-t / (0.25 / m))
               for m, a in ((1, 0.5), (2.31, 0.4), (3.93, 0.3), (5.12, 0.2)))
    return np.tanh(1.2 * (ring + kick(d, 55, 120) * 0.6))


# ---------- herramientas ----------
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


# ---------- tonales ----------
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


def pad(freqs, d, attack=0.35):
    """Colchón suave para sostener el cierre."""
    t = tt(d)
    v = sum(np.sin(phase(np.full(len(t), f * det))) for f in freqs for det in (0.997, 1.003))
    v = filt(v / (2 * len(freqs)), "lowpass", 2500)
    return v * np.clip(t / attack, 0, 1) * (1 + 0.08 * np.sin(2 * np.pi * 3 * t))


def bell(f, d=1.3):
    t = tt(d)
    return sum(a * np.sin(2 * np.pi * f * m * t) * np.exp(-t / (0.7 / m ** 0.5))
               for m, a in ((1, 1), (2.0, 0.5), (3.01, 0.3), (4.1, 0.15))) / 2


# ---------- mezcla ----------
class Mix:
    def __init__(self, dur):
        self.dur = dur
        self.N = int(SR * dur)
        self.L, self.R = np.zeros(self.N), np.zeros(self.N)
        self.VL, self.VR = np.zeros(self.N), np.zeros(self.N)   # envío a reverb

    def place(self, sig, t, gain=1.0, pan=0.0, verb=0.0):
        i = int(round(t * SR))
        if i >= self.N:
            return
        s = sig[: self.N - i] * gain
        gl = np.sqrt(0.5 * (1 - pan)) * 1.4142
        gr = np.sqrt(0.5 * (1 + pan)) * 1.4142
        self.L[i:i + len(s)] += s * gl
        self.R[i:i + len(s)] += s * gr
        if verb:
            self.VL[i:i + len(s)] += s * gl * verb
            self.VR[i:i + len(s)] += s * gr * verb

    def bass_line(self, notes, start, end, step, kicks, gain=0.35):
        """Bajo en corcheas con compresión lateral (se agacha con cada bombo)."""
        bass = np.zeros(self.N)
        for k, tb in enumerate(np.arange(start, end, step)):
            s = bass_note(notes[k % len(notes)], step * 0.96)
            i = int(tb * SR)
            bass[i:i + len(s)] += s[: self.N - i]
        tN = np.arange(self.N) / SR
        duck = np.ones(self.N)
        for tk in kicks:
            m = tN >= tk
            duck[m] *= 1 - 0.75 * np.exp(-(tN[m] - tk) / 0.09)
        bass *= duck * gain
        self.L += bass
        self.R += bass

    def write(self, path):
        ir_t = tt(1.4)
        irs = []
        for _ in range(2):
            ir = filt(noise(1.4), "lowpass", 6000) * np.exp(-ir_t / 0.38)
            irs.append(ir / np.sqrt(np.sum(ir ** 2)))
        L = self.L + fftconvolve(self.VL, irs[0])[: self.N] * 0.9
        R = self.R + fftconvolve(self.VR, irs[1])[: self.N] * 0.9

        mix = filt(np.stack([L, R]), "highpass", 28)
        mix /= np.max(np.abs(mix))          # saturación suave, no aplastar
        drive = 1.6
        mix = np.tanh(mix * drive) / np.tanh(drive)
        tN = np.arange(self.N) / SR
        mix *= np.clip((self.dur - tN) / 0.25, 0, 1)
        mix *= 0.95 / np.max(np.abs(mix))

        with wave.open(path, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((mix.T * 32767).astype("<i2").tobytes())
        print(path, self.dur, "s")
