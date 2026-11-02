# Background music for the ShapePrompt demo video — composed in code, no samples.
# A little dragon's workshop: harp arpeggios, soft bells, a warm pad and bass,
# in D minor with a lift to F major. Usage: python3 tool/compose_music.py out.wav SECONDS
import sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import fftconvolve

out = sys.argv[1]
SECONDS = float(sys.argv[2])
SR = 44100
BPM = 80
BEAT = 60 / BPM
BAR = 4 * BEAT
BARS = int(np.ceil(SECONDS / BAR))
L = np.zeros(int((BARS * BAR + 4) * SR)); R = np.zeros_like(L)

def hz(m): return 440 * 2 ** ((m - 69) / 12)

def put(sig, start, pan=0.0):
    i = int(start * SR); j = min(i + len(sig), len(L)); sig = sig[:j - i]
    L[i:j] += sig * (1 - pan) / 2 ** 0.5
    R[i:j] += sig * (1 + pan) / 2 ** 0.5

def harp(m, vel):
    """Plucked string: bright attack, harmonics fade fast, the body rings."""
    t = np.arange(int(2.8 * SR)) / SR
    f = hz(m); s = np.zeros_like(t)
    for k in range(1, 7):
        s += np.sin(2 * np.pi * k * f * t) * np.exp(-t * (1.6 + 1.4 * k)) / k ** 1.3
    return s * np.minimum(1, t / 0.003) * vel

def bell(m, vel):
    """Small glass bell: inharmonic partials, long shimmering tail."""
    t = np.arange(int(3.5 * SR)) / SR
    f = hz(m); s = np.zeros_like(t)
    for ratio, amp, dec in ((1, 1, 1.2), (2.76, 0.45, 2.2), (5.40, 0.25, 3.5), (8.93, 0.12, 5)):
        s += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t * dec)
    s *= 1 + 0.03 * np.sin(2 * np.pi * 5 * t)
    return s * np.minimum(1, t / 0.002) * vel

def pad(m, dur, vel):
    t = np.arange(int((dur + 1.8) * SR)) / SR
    f = hz(m); s = np.zeros_like(t)
    for cents in (-6, 0, 6):
        fc = f * 2 ** (cents / 1200)
        s += np.sin(2 * np.pi * fc * t) + 0.2 * np.sin(2 * np.pi * 2 * fc * t)
    env = np.minimum(1, t / 1.6) * np.where(t < dur, 1, np.exp(-(t - dur) * 2))
    return s * env * vel / 3

def bass(m, dur, vel):
    t = np.arange(int((dur + 0.8) * SR)) / SR
    s = np.sin(2 * np.pi * hz(m) * t) + 0.25 * np.sin(2 * np.pi * 2 * hz(m) * t)
    env = np.minimum(1, t / 0.04) * np.exp(-t * 0.45) * np.where(t < dur, 1, np.exp(-(t - dur) * 5))
    return s * env * vel

CH = {
    'Dm': ([62, 65, 69, 74], 38), 'Bb': ([58, 62, 65, 70], 34),
    'F':  ([60, 65, 69, 72], 41), 'C':  ([60, 64, 67, 72], 36),
    'Gm': ([62, 67, 70, 74], 43), 'A':  ([61, 64, 69, 73], 33),
}
A_PROG = ['Dm', 'Bb', 'F', 'C']
B_PROG = ['Gm', 'Bb', 'F', 'A']
SCALE = [74, 77, 79, 81, 84, 86]        # D minor pentatonic, upper octave

rng = np.random.default_rng(11)
for bar in range(BARS):
    t0 = bar * BAR
    left = BARS - bar
    if bar < 3: sec = 'intro'
    elif left <= 3: sec = 'outro'
    elif (bar // 12) % 2 == 1: sec = 'B'
    else: sec = 'A'
    name = (B_PROG if sec == 'B' else A_PROG)[bar % 4]
    notes, root = CH[name]
    for n in notes:
        put(pad(n, BAR, 0.045), t0)
    if sec in ('A', 'B'):
        put(bass(root, BAR * 0.9, 0.2), t0)
        # harp: up and down the chord in eighths
        arp = [notes[0], notes[1], notes[2], notes[3], notes[3] + 12, notes[3], notes[2], notes[1]]
        for i, m in enumerate(arp):
            put(harp(m + 12, 0.07 * (1.2 if i == 0 else 1)), t0 + i * BEAT / 2, pan=-0.4 + 0.1 * i)
    if sec == 'B' or (sec == 'A' and bar % 4 in (1, 3) and bar > 6):
        # bells: a short tune from the chord, sparkling over the harp
        pcs = {n % 12 for n in notes}
        idx = [i for i, m in enumerate(SCALE) if m % 12 in pcs] or [0]
        k = int(rng.choice(idx))
        for beat in ([0, 1.5, 3] if rng.random() < 0.5 else [0, 2, 2.5]):
            put(bell(SCALE[k], 0.09), t0 + beat * BEAT, pan=0.3)
            k = int(np.clip(k + rng.choice([-1, 1, 2]), 0, len(SCALE) - 1))
    if sec == 'intro':
        put(bell(notes[-1] + 12, 0.08), t0 + BEAT, pan=0.2)
    if sec == 'outro':
        put(bell(notes[0] + 12, 0.08), t0, pan=-0.2)

def impulse(seed):
    t = np.arange(int(2.8 * SR)) / SR
    n = np.random.default_rng(seed).standard_normal(len(t)) * np.exp(-t / 0.6)
    n = np.convolve(n, np.ones(10) / 10, mode='same')
    return n / np.abs(n).sum() * 40
wetL = fftconvolve(L, impulse(1))[:len(L)]
wetR = fftconvolve(R, impulse(2))[:len(R)]
mix = np.stack([L + 0.4 * wetL, R + 0.4 * wetR], axis=1)

total = int(SECONDS * SR)
mix = mix[:total]
t = np.arange(total) / SR
fade = np.minimum(1, t / 1.5) * np.clip((t[-1] - t) / 4, 0, 1)
mix *= fade[:, None]
mix *= 10 ** (-3 / 20) / np.abs(mix).max()
wavfile.write(out, SR, (mix * 32767).astype(np.int16))
print(f'{out}: {total / SR:.1f} s, {BARS} bars')
