"""Generates the bundled connect sounds (original, synthesised from scratch, standard library only).

    python tools/make-sounds.py

Writes 44.1 kHz 16-bit mono WAV files to Resources/Sounds/. Every sound is made here from sine,
saw and noise oscillators; nothing is sampled or copied, so they are owned by the project
(see ASSETS-LICENSES.md).
"""

import math
import pathlib
import random
import struct
import wave

RATE = 44_100
OUT = pathlib.Path(__file__).resolve().parent.parent / "Resources" / "Sounds"


def envelope(t, attack, decay_time, total):
    """Fast attack, exponential decay, short fade at the end to avoid clicks."""
    if t < attack:
        level = t / attack
    else:
        level = math.exp(-(t - attack) / decay_time)
    fade = min(1.0, (total - t) / 0.03)
    return level * max(fade, 0.0)


def bell(freq, start, length, decay, partials=((1, 1.0), (2.0, 0.45), (3.01, 0.25), (4.2, 0.12), (5.4, 0.06))):
    """A struck-bell voice: inharmonic partials, each decaying a little faster than the last."""
    def voice(t):
        local = t - start
        if local < 0 or local > length:
            return 0.0
        total = 0.0
        for index, (ratio, amp) in enumerate(partials):
            total += amp * math.sin(2 * math.pi * freq * ratio * local) * envelope(local, 0.004, decay / (1 + index * 0.6), length)
        return total
    return voice


def pad(freq, start, length):
    """Soft rounded tone with slow attack (sine + a little octave)."""
    def voice(t):
        local = t - start
        if local < 0 or local > length:
            return 0.0
        attack = min(local / 0.25, 1.0)
        release = min((length - local) / 0.6, 1.0)
        level = attack * max(release, 0.0)
        return level * (0.8 * math.sin(2 * math.pi * freq * local) + 0.2 * math.sin(2 * math.pi * freq * 2 * local + 0.3))
    return voice


def render(name, duration, voices, gain=0.8, post=None):
    samples = []
    for i in range(int(duration * RATE)):
        t = i / RATE
        value = sum(v(t) for v in voices)
        if post:
            value = post(t, value)
        samples.append(value)
    peak = max(abs(s) for s in samples) or 1.0
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s / peak * gain)) * 32767)) for s in samples))
    print(f"{name}.wav  {duration:.1f}s")


def engine(duration, rpm_curve, seed, gain=0.85):
    """Engine-style rev: firing pulses (saw + harmonics) whose rate follows rpm_curve(t), plus intake noise."""
    rng = random.Random(seed)
    phase = 0.0
    state = {"phase": 0.0, "lp": 0.0}

    def voice(t):
        rpm = rpm_curve(t)
        firing = rpm / 60 * 2          # 4-cylinder: 2 firings per revolution
        state["phase"] += firing / RATE
        p = state["phase"] % 1.0
        saw = 2 * p - 1
        tone = 0.6 * saw + 0.3 * math.sin(2 * math.pi * state["phase"] * 0.5) + 0.2 * math.sin(2 * math.pi * state["phase"] * 2)
        noise = rng.uniform(-1, 1)
        state["lp"] += 0.08 * (noise - state["lp"])
        load = min(1.0, rpm / 6500)
        level = min(t / 0.05, 1.0) * min((duration - t) / 0.25, 1.0)
        return level * (tone * (0.5 + 0.5 * load) + state["lp"] * 0.6 * load)
    return voice


def main():
    # 1. Bright chime: three-note rising bell (E6, G#6, B6).
    render("chime-bright", 2.2, [bell(1318.5, 0.0, 2.2, 0.55), bell(1661.2, 0.14, 2.06, 0.55), bell(1975.5, 0.28, 1.92, 0.7)], gain=0.7)

    # 2. Soft chime: two low bells, a fifth apart.
    render("chime-soft", 2.5, [bell(523.25, 0.0, 2.5, 0.9), bell(783.99, 0.22, 2.28, 0.9)], gain=0.65)

    # 3. Welcome tone: warm major arpeggio pad (C5 E5 G5 C6).
    notes = [523.25, 659.25, 783.99, 1046.5]
    render("welcome-tone", 3.0, [pad(f, i * 0.18, 3.0 - i * 0.18) for i, f in enumerate(notes)], gain=0.6)

    # 4. Sporty rev: idle, blip to 6,000 rpm, settle back.
    def rev_curve(t):
        if t < 0.35:
            return 900
        if t < 0.95:
            x = (t - 0.35) / 0.6
            return 900 + 5100 * (1 - (1 - x) ** 2)
        return 1100 + 4900 * math.exp(-(t - 0.95) / 0.35)
    render("rev-sport", 2.6, [engine(2.6, rev_curve, seed=408)], gain=0.85)

    # 5. Double blip: two short revs.
    def blip_curve(t):
        base = 1000
        for start in (0.25, 0.85):
            if t >= start:
                local = t - start
                base += 3800 * (local / 0.12 if local < 0.12 else math.exp(-(local - 0.12) / 0.18))
        return min(base, 6200)
    render("rev-blip", 2.0, [engine(2.0, blip_curve, seed=2025)], gain=0.85)

    # 6. Goodbye: soft falling two-note bell for the disconnect automation.
    render("goodbye", 2.2, [bell(783.99, 0.0, 2.2, 0.8), bell(523.25, 0.25, 1.95, 0.9)], gain=0.6)


if __name__ == "__main__":
    main()
