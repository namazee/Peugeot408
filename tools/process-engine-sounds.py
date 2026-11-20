"""Turns the CC0 / public-domain engine recordings into the Engine starts pack.

    python tools/process-engine-sounds.py <folder with the downloaded files>

Reads tools/engine-sounds.json (id, name, file, optional start/length in seconds, source and licence).
For each recording: decode with ffmpeg (Remotion's bundled one is found automatically; set FFMPEG to
override), mix to mono, find where the sound starts (or use "start"), keep at most 5 seconds, fade in
and out, bring it to the same loudness as the synthesised packs (RMS about -17 dBFS, peaks limited),
and write Resources/Sounds/<id>.m4a. The licence of every file is recorded in ASSETS-LICENSES.md.
"""

import json
import math
import os
import pathlib
import struct
import subprocess
import sys
import tempfile
import wave

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Resources" / "Sounds"
MANIFEST = ROOT / "tools" / "engine-sounds.json"
RATE = 44_100
MAX_SECONDS = 5.0
TARGET_RMS = 0.14
PEAK_LIMIT = 0.92


def ffmpeg_path():
    if os.environ.get("FFMPEG"):
        return os.environ["FFMPEG"]
    for name in ("compositor-win32-x64-msvc/ffmpeg.exe", "compositor-darwin-arm64/ffmpeg", "compositor-darwin-x64/ffmpeg", "compositor-linux-x64-gnu/ffmpeg"):
        candidate = ROOT / "remotion" / "node_modules" / "@remotion" / name
        if candidate.exists():
            return str(candidate)
    return "ffmpeg"


def decode(path):
    tmp = pathlib.Path(tempfile.gettempdir()) / "p408-engine-decode.wav"
    subprocess.run([ffmpeg_path(), "-y", "-loglevel", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE), "-f", "wav", "-c:a", "pcm_s16le", str(tmp)], check=True)
    with wave.open(str(tmp), "rb") as file:
        frames = file.readframes(file.getnframes())
    tmp.unlink()
    return [v / 32768 for v in struct.unpack(f"<{len(frames) // 2}h", frames)]


def onset(samples, window=0.05):
    """First moment the level rises above 15% of the loudest 50 ms window."""
    n = int(window * RATE)
    levels = [math.sqrt(sum(s * s for s in samples[i:i + n]) / n) for i in range(0, max(len(samples) - n, 1), n)]
    top = max(levels) or 1
    for index, level in enumerate(levels):
        if level > 0.15 * top:
            return max(index * n - int(0.12 * RATE), 0)
    return 0


def process(entry, folder):
    samples = decode(folder / entry["file"])
    start = int(entry["start"] * RATE) if "start" in entry else onset(samples)
    length = int(min(entry.get("length", MAX_SECONDS), MAX_SECONDS) * RATE)
    clip = samples[start:start + length]
    fade_in, fade_out = int(0.02 * RATE), int(0.35 * RATE)
    for i in range(min(fade_in, len(clip))):
        clip[i] *= i / fade_in
    for i in range(min(fade_out, len(clip))):
        clip[-1 - i] *= i / fade_out
    rms = math.sqrt(sum(s * s for s in clip) / len(clip)) or 1
    peak = max(abs(s) for s in clip) or 1
    scale = min(TARGET_RMS / rms, PEAK_LIMIT / peak)
    tmp = pathlib.Path(tempfile.gettempdir()) / f"p408-{entry['id']}.wav"
    with wave.open(str(tmp), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in clip))
    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run([ffmpeg_path(), "-y", "-loglevel", "error", "-i", str(tmp), "-c:a", "aac", "-b:a", "128k", "-f", "mp4", "-movflags", "+faststart",
                    str(OUT / f"{entry['id']}.m4a")], check=True)
    tmp.unlink()
    print(f"{entry['id']}.m4a  {len(clip) / RATE:.1f}s  from {start / RATE:.2f}s  (gain {scale:.2f})")


if __name__ == "__main__":
    folder = pathlib.Path(sys.argv[1])
    for entry in json.loads(MANIFEST.read_text(encoding="utf-8")):
        process(entry, folder)
