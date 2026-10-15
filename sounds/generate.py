#!/usr/bin/python3 -I
"""Makes the notification sounds (regular/*.wav, urgent/*.wav) from scratch: no samples, so no licences to track.

  python3 sounds/generate.py      rewrites the .wav files next to this script

Soft sine/synth tones with a little room. Regular ones peak at -18 dBFS (noticed, not startling), urgent at -12 dBFS.
hypr/scripts/sounds picks and plays them.
"""
import math, os, struct, wave

SR = 48000
HERE = os.path.dirname(os.path.abspath(__file__))


def note(freq, dur, kind="sine", start=0.0, attack=0.004, decay=0.12, amp=1.0, glide=None):
    """One tone: a short attack (no click) and an exponential decay. glide: pitch ratio reached after 60 ms."""
    buf = [0.0] * int((start + dur) * SR)
    phase = mphase = 0.0
    for i in range(int(dur * SR)):
        t = i / SR
        f = freq if glide is None else freq * (glide ** min(t / 0.06, 1.0))
        env = min(t / attack, 1.0) * math.exp(-t / decay)
        if kind == "sine":        # with a trace of the octave, a bit rounder than a pure sine
            s = math.sin(phase) + 0.12 * math.sin(2 * phase)
        elif kind == "tri":       # band-limited triangle: retro, but not harsh
            s = sum(((-1) ** k) * math.sin((2 * k + 1) * phase) / (2 * k + 1) ** 2 for k in range(4))
        elif kind == "detune":    # two sines 0.6 % apart: a slow synth shimmer
            s = 0.5 * (math.sin(phase) + math.sin(mphase))
            mphase += 2 * math.pi * f * 1.006 / SR
        phase += 2 * math.pi * f / SR
        buf[int(start * SR) + i] = s * env * amp
    return buf


def mix(*bufs):
    out = [0.0] * max(len(b) for b in bufs)
    for b in bufs:
        for i, v in enumerate(b):
            out[i] += v
    return out


def reverb(buf, wet=0.18, tail=0.35):
    """A small room: four parallel comb filters."""
    n = len(buf) + int(tail * SR)
    x = buf + [0.0] * (n - len(buf))
    out = x[:]
    for d_ms, g in ((29.7, 0.55), (37.1, 0.5), (41.1, 0.45), (43.7, 0.4)):
        d = int(d_ms / 1000 * SR)
        c = [0.0] * n
        for i in range(n):
            c[i] = x[i] + (g * c[i - d] if i >= d else 0.0)
        for i in range(n):
            out[i] += wet * 0.25 * c[i]
    return out


def write(path, buf, peak_db):
    fade = int(0.03 * SR)
    for i in range(fade):
        buf[-1 - i] *= i / fade
    g = 10 ** (peak_db / 20) / (max(abs(v) for v in buf) or 1.0)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(v * g * 32767)) for v in buf))


E5, Fs5, G5, A5, B5, D6, E6, A6 = 659.26, 739.99, 783.99, 880.0, 987.77, 1174.7, 1318.5, 1760.0

REGULAR = {
    "plip": lambda: reverb(mix(note(E5, .22, start=0, decay=.06), note(B5, .3, start=.07, decay=.08))),
    "drop": lambda: reverb(note(A5, .3, decay=.07, glide=1.5), wet=.25),
    "tick": lambda: reverb(note(E6, .2, "detune", decay=.05), wet=.2),
    "retro": lambda: reverb(mix(note(A5, .15, "tri", 0, decay=.04), note(D6, .25, "tri", .06, decay=.07))),
    "glass": lambda: reverb(mix(note(A6, .25, start=0, decay=.06), note(E6, .35, start=.05, decay=.09, amp=.7)), wet=.35, tail=.5),
}
URGENT = {
    "double-plip": lambda: reverb(mix(note(B5, .2, start=0, decay=.05), note(E6, .2, start=.07, decay=.05),
                                      note(B5, .2, start=.2, decay=.05), note(E6, .3, start=.27, decay=.08))),
    "plip-fall": lambda: reverb(mix(note(E5, .22, start=0, decay=.06), note(B5, .22, start=.08, decay=.06),
                                    note(G5, .4, start=.16, decay=.12))),
    "synth-fall": lambda: reverb(mix(note(B5, .35, "detune", 0, decay=.12), note(E5, .55, "detune", .15, decay=.18)), wet=.25),
    "arpeggio": lambda: reverb(mix(note(E5, .15, "tri", 0, decay=.05), note(G5, .15, "tri", .07, decay=.05),
                                   note(B5, .15, "tri", .14, decay=.05), note(Fs5, .4, "tri", .21, decay=.12))),
    "pulse": lambda: reverb(mix(*[note(B5, .18, "detune", .14 * k, decay=.05) for k in range(3)])),
}

if __name__ == "__main__":
    for kind, sounds, peak in (("regular", REGULAR, -18), ("urgent", URGENT, -12)):
        for name, make in sounds.items():
            write(os.path.join(HERE, kind, name + ".wav"), make(), peak)
            print(f"{kind}/{name}.wav")
