"""Generates the bundled synthesised connect sounds (original, made from scratch, standard library only).

    python tools/make-sounds.py                 # all packs
    python tools/make-sounds.py arcade pings    # only some packs

Every sound is made here from sine, square, saw and noise oscillators; nothing is sampled or copied,
so they are owned by the project (see ASSETS-LICENSES.md). Sounds are loudness-matched (same RMS,
peaks limited), written as 44.1 kHz mono WAV, then encoded to AAC .m4a with ffmpeg (Remotion's
bundled ffmpeg is found automatically; set FFMPEG to use another). The engine-start pack is made
from CC0 recordings by tools/process-engine-sounds.py instead.
"""

import math
import os
import pathlib
import random
import struct
import subprocess
import sys
import tempfile
import wave

RATE = 44_100
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Resources" / "Sounds"
TARGET_RMS = 0.14   # about -17 dBFS: every sound sits at about the same loudness
PEAK_LIMIT = 0.92


def ffmpeg_path():
    if os.environ.get("FFMPEG"):
        return os.environ["FFMPEG"]
    for name in ("compositor-win32-x64-msvc/ffmpeg.exe", "compositor-darwin-arm64/ffmpeg", "compositor-darwin-x64/ffmpeg", "compositor-linux-x64-gnu/ffmpeg"):
        candidate = ROOT / "remotion" / "node_modules" / "@remotion" / name
        if candidate.exists():
            return str(candidate)
    return "ffmpeg"


def envelope(t, attack, decay_time, total):
    """Fast attack, exponential decay, short fade at the end to avoid clicks."""
    level = t / attack if t < attack else math.exp(-(t - attack) / decay_time)
    return level * max(min(1.0, (total - t) / 0.03), 0.0)


def bell(freq, start, length, decay, partials=((1, 1.0), (2.0, 0.45), (3.01, 0.25), (4.2, 0.12), (5.4, 0.06))):
    """A struck-bell voice: inharmonic partials, each decaying a little faster than the last."""
    def voice(t):
        local = t - start
        if local < 0 or local > length:
            return 0.0
        return sum(amp * math.sin(2 * math.pi * freq * ratio * local) * envelope(local, 0.004, decay / (1 + i * 0.6), length)
                   for i, (ratio, amp) in enumerate(partials))
    return voice


def pad(freq, start, length, attack=0.25, release=0.6, bright=0.2):
    """Soft rounded tone with a slow attack (sine + a little octave)."""
    def voice(t):
        local = t - start
        if local < 0 or local > length:
            return 0.0
        level = min(local / attack, 1.0) * max(min((length - local) / release, 1.0), 0.0)
        return level * ((1 - bright) * math.sin(2 * math.pi * freq * local) + bright * math.sin(2 * math.pi * freq * 2 * local + 0.3))
    return voice


def square_note(freq, start, length, duty=0.5, decay=None):
    """8-bit style square wave with a short click-free gate."""
    def voice(t):
        local = t - start
        if local < 0 or local > length:
            return 0.0
        p = (freq * local) % 1.0
        level = min(local / 0.003, 1.0) * max(min((length - local) / 0.01, 1.0), 0.0)
        if decay:
            level *= math.exp(-local / decay)
        return level * (1.0 if p < duty else -1.0) * 0.5
    return voice


def glide(f0, f1, start, length, shape=lambda x: x, wave_fn=math.sin, attack=0.05, release=0.2):
    """A tone whose pitch moves from f0 to f1 (exponentially), phase-continuous."""
    state = {"phase": 0.0}

    def voice(t):
        local = t - start
        if local < 0 or local > length:
            return 0.0
        freq = f0 * (f1 / f0) ** shape(local / length)
        state["phase"] += freq / RATE
        level = min(local / attack, 1.0) * max(min((length - local) / release, 1.0), 0.0)
        return level * wave_fn(2 * math.pi * state["phase"])
    return voice


def noise_sweep(start, length, f0, f1, seed, level_curve=lambda x: math.sin(math.pi * x)):
    """Filtered noise whose cutoff sweeps from f0 to f1 (a whoosh / airlock hiss)."""
    rng = random.Random(seed)
    state = {"lp": 0.0, "lp2": 0.0}

    def voice(t):
        local = t - start
        if local < 0 or local > length:
            return 0.0
        x = local / length
        a = 1 - math.exp(-2 * math.pi * f0 * (f1 / f0) ** x / RATE)
        state["lp"] += a * (rng.uniform(-1, 1) - state["lp"])
        state["lp2"] += a * (state["lp"] - state["lp2"])
        return level_curve(x) * state["lp2"] * 2.5
    return voice


def render(name, duration, voices, post=None):
    samples = []
    for i in range(int(duration * RATE)):
        t = i / RATE
        value = sum(v(t) for v in voices)
        samples.append(post(t, value) if post else value)
    # Loudness match: same RMS for every sound, peaks limited.
    rms = math.sqrt(sum(s * s for s in samples) / len(samples)) or 1.0
    peak = max(abs(s) for s in samples) or 1.0
    scale = min(TARGET_RMS / rms, PEAK_LIMIT / peak)
    fade = int(0.012 * RATE)
    for i in range(min(fade, len(samples))):
        samples[-1 - i] *= i / fade
    tmp = pathlib.Path(tempfile.gettempdir()) / f"p408-{name}.wav"
    with wave.open(str(tmp), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / f"{name}.m4a"
    subprocess.run([ffmpeg_path(), "-y", "-loglevel", "error", "-i", str(tmp), "-c:a", "aac", "-b:a", "128k", "-f", "mp4", "-movflags", "+faststart", str(target)], check=True)
    tmp.unlink()
    (OUT / f"{name}.wav").unlink(missing_ok=True)
    print(f"{name}.m4a  {duration:.1f}s")


def engine(duration, rpm_curve, seed, cylinders=4):
    """Engine-style rev: firing pulses (saw + harmonics) whose rate follows rpm_curve(t), plus intake noise."""
    rng = random.Random(seed)
    state = {"phase": 0.0, "lp": 0.0}

    def voice(t):
        rpm = rpm_curve(t)
        state["phase"] += rpm / 60 * cylinders / 2 / RATE
        p = state["phase"] % 1.0
        tone = 0.6 * (2 * p - 1) + 0.3 * math.sin(math.pi * state["phase"]) + 0.2 * math.sin(4 * math.pi * state["phase"])
        state["lp"] += 0.08 * (rng.uniform(-1, 1) - state["lp"])
        load = min(1.0, rpm / 6500)
        level = min(t / 0.05, 1.0) * min((duration - t) / 0.25, 1.0)
        return level * (tone * (0.5 + 0.5 * load) + state["lp"] * 0.6 * load)
    return voice


def tri(x):
    return 2 / math.pi * math.asin(math.sin(x))


def sq(x):
    return 1.0 if math.sin(x) > 0 else -1.0


# MARK: - Packs

def classic():
    render("chime-bright", 2.2, [bell(1318.5, 0.0, 2.2, 0.55), bell(1661.2, 0.14, 2.06, 0.55), bell(1975.5, 0.28, 1.92, 0.7)])
    render("chime-soft", 2.5, [bell(523.25, 0.0, 2.5, 0.9), bell(783.99, 0.22, 2.28, 0.9)])
    render("welcome-tone", 3.0, [pad(f, i * 0.18, 3.0 - i * 0.18) for i, f in enumerate([523.25, 659.25, 783.99, 1046.5])])

    def rev_curve(t):
        if t < 0.35:
            return 900
        if t < 0.95:
            x = (t - 0.35) / 0.6
            return 900 + 5100 * (1 - (1 - x) ** 2)
        return 1100 + 4900 * math.exp(-(t - 0.95) / 0.35)
    render("rev-sport", 2.6, [engine(2.6, rev_curve, seed=408)])

    def blip_curve(t):
        base = 1000
        for start in (0.25, 0.85):
            if t >= start:
                local = t - start
                base += 3800 * (local / 0.12 if local < 0.12 else math.exp(-(local - 0.12) / 0.18))
        return min(base, 6200)
    render("rev-blip", 2.0, [engine(2.0, blip_curve, seed=2025)])
    render("goodbye", 2.2, [bell(783.99, 0.0, 2.2, 0.8), bell(523.25, 0.25, 1.95, 0.9)])


def ev():
    render("ev-rise", 2.4, [noise_sweep(0, 2.4, 300, 6000, 11, lambda x: math.sin(math.pi * x) ** 1.5), glide(180, 720, 0.2, 2.0, release=0.5)])
    render("ev-pulse", 2.6, [glide(55, 110, 0, 2.6, attack=0.6, release=0.8), pad(220, 0.3, 2.3, attack=0.5), pad(330, 0.5, 2.1, attack=0.5)])
    render("ev-glide", 2.2, [glide(440, 880, 0, 1.1, shape=lambda x: x * x), glide(660, 1320, 0.4, 1.4, shape=lambda x: x * x, release=0.5),
                             noise_sweep(0, 1.6, 800, 4000, 12)])
    render("ev-hum", 2.6, [glide(300, 2400, 0, 2.6, shape=math.sqrt, wave_fn=tri, attack=0.2, release=0.6),
                           glide(150, 1200, 0, 2.6, shape=math.sqrt, attack=0.2, release=0.6)])


def luxury():
    render("lux-duet", 2.6, [pad(392.0, 0, 2.6, attack=0.08, release=1.6, bright=0.1), pad(587.33, 0.35, 2.25, attack=0.08, release=1.5, bright=0.1)])
    render("lux-bloom", 3.0, [pad(f, 0.05 * i, 3.0 - 0.05 * i, attack=0.7, release=1.2) for i, f in enumerate([261.63, 329.63, 392.0, 493.88])])
    render("lux-glass", 2.4, [bell(1046.5, 0, 2.4, 1.2, partials=((1, 1.0), (2.76, 0.3), (5.4, 0.1))), bell(1567.98, 0.3, 2.1, 1.2, partials=((1, 0.8), (2.76, 0.2)))])
    render("lux-velvet", 2.8, [pad(130.81, 0, 2.8, attack=0.4, release=1.4, bright=0.05), pad(196.0, 0.15, 2.65, attack=0.4, release=1.4, bright=0.1),
                               pad(261.63, 0.3, 2.5, attack=0.5, release=1.4, bright=0.15)])
    render("lux-arrival", 2.6, [bell(f, 0.22 * i, 2.6 - 0.22 * i, 0.9, partials=((1, 1.0), (2.0, 0.3), (3.0, 0.1))) for i, f in enumerate([987.77, 783.99, 659.25])])
    render("lux-crest", 3.0, [pad(f, 0.15 * i, 3.0 - 0.15 * i, attack=0.1, release=1.5, bright=0.25) for i, f in enumerate([349.23, 440.0, 523.25, 659.25])])


def arcade():
    render("arc-coin", 0.7, [square_note(987.77, 0, 0.08), square_note(1318.51, 0.08, 0.55, decay=0.25)])
    render("arc-levelup", 1.4, [square_note(f, 0.11 * i, 0.12 if i < 5 else 0.6, duty=0.25) for i, f in enumerate([523.25, 659.25, 783.99, 1046.5, 1318.51, 1567.98])])
    render("arc-powerup", 1.2, [glide(200, 1600, 0, 1.1, wave_fn=sq, attack=0.01, release=0.1)],
           post=lambda t, v: v * (0.6 + 0.4 * math.sin(2 * math.pi * 18 * t)))
    render("arc-start", 1.3, [square_note(f, d, l) for f, d, l in [(392.0, 0, 0.1), (523.25, 0.12, 0.1), (659.25, 0.24, 0.1), (783.99, 0.36, 0.1), (1046.5, 0.5, 0.7)]])
    render("arc-1up", 1.0, [square_note(f, 0.1 * i, 0.1 if i < 5 else 0.4, duty=0.125) for i, f in enumerate([659.25, 783.99, 1318.51, 1046.5, 1174.66, 1567.98])])
    render("arc-chain", 1.1, [square_note(400 * 1.19 ** i, 0.08 * i, 0.07, duty=0.25) for i in range(12)])
    render("arc-pinball", 1.5, [bell(1760, 0, 1.5, 0.3, partials=((1, 1.0), (2.5, 0.3))), bell(2093, 0.12, 1.38, 0.3, partials=((1, 0.9),)),
                                bell(2637, 0.24, 1.26, 0.4, partials=((1, 0.8),)), square_note(130.81, 0, 0.15, decay=0.05)])
    render("arc-victory", 2.0, [square_note(f, d, l, duty=0.25) for f, d, l in [(523.25, 0, 0.12), (523.25, 0.14, 0.12), (523.25, 0.28, 0.12), (523.25, 0.42, 0.3),
                                                                              (415.3, 0.74, 0.3), (466.16, 1.06, 0.3), (523.25, 1.38, 0.55)]])


def pings():
    render("ping-high", 1.4, [bell(1760, 0, 1.4, 0.5, partials=((1, 1.0), (3.0, 0.08)))])
    render("ping-mid", 1.6, [bell(880, 0, 1.6, 0.6, partials=((1, 1.0), (2.0, 0.1)))])
    render("ping-low", 1.8, [bell(440, 0, 1.8, 0.8, partials=((1, 1.0), (2.0, 0.15)))])
    render("ping-double", 1.6, [bell(1174.66, 0, 1.6, 0.4, partials=((1, 1.0),)), bell(1174.66, 0.18, 1.42, 0.5, partials=((1, 1.0),))])
    render("ping-glass", 1.8, [bell(2093, 0, 1.8, 0.9, partials=((1, 1.0), (2.76, 0.25), (5.4, 0.08)))])


def scifi():
    render("sf-airlock", 2.4, [noise_sweep(0, 0.5, 3000, 9000, 21, lambda x: 1 - x), noise_sweep(0.35, 2.0, 6000, 400, 22, lambda x: (1 - x) ** 2),
                               glide(90, 60, 0.3, 2.0, release=1.0)])
    render("sf-console", 1.6, [square_note(f, 0.13 * i, 0.09) for i, f in enumerate([1320, 990, 1760, 1320, 2200, 1650])])
    render("sf-warp", 2.6, [glide(80, 2400, 0, 1.8, shape=lambda x: x ** 3, wave_fn=tri, attack=0.3, release=0.15),
                            noise_sweep(1.6, 1.0, 9000, 300, 23, lambda x: (1 - x) ** 1.5)])
    render("sf-scan", 2.2, [glide(600, 1200, 0, 2.2, wave_fn=tri, release=0.4)],
           post=lambda t, v: v * (0.5 + 0.5 * (1 if (t * 6) % 1 < 0.5 else 0)))
    render("sf-power", 2.8, [glide(40, 160, 0, 2.8, shape=math.sqrt, wave_fn=lambda x: (x / math.pi % 2) - 1, attack=0.4, release=0.5),
                             glide(80, 320, 0, 2.8, shape=math.sqrt, attack=0.4, release=0.5), pad(640, 2.0, 0.8, attack=0.05, release=0.5)])
    render("sf-portal", 2.6, [glide(300, 900, 0, 2.6, attack=0.5, release=0.8)],
           post=lambda t, v: v * math.sin(2 * math.pi * (40 + 60 * t) * t))


PACKS = {"classic": classic, "ev": ev, "luxury": luxury, "arcade": arcade, "pings": pings, "scifi": scifi}

if __name__ == "__main__":
    for pack in (sys.argv[1:] or PACKS):
        PACKS[pack]()
