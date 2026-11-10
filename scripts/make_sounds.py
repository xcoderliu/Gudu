#!/usr/bin/env python3
"""Original, offline sound design: water, rounded gulps, and an airy relieved sigh.

No recordings, voices, downloaded assets, or third-party synthesis dependencies.
The 15-second soundtrack follows DrinkingTimeline's animation beats.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Gudu" / "Resources"


def envelope(time, duration, attack=0.08, release=0.2):
    return max(0, min(1, time / attack, (duration - time) / release))


def add_noise(buffer, start, duration, amplitude, seed, breath=False):
    rng = random.Random(seed)
    low, base = 0.0, 0.0
    for index in range(int(duration * RATE)):
        time = index / RATE
        noise = rng.uniform(-1, 1)
        low += (0.14 if breath else 0.31) * (noise - low)
        base += (0.018 if breath else 0.045) * (noise - base)
        gudu = 0.76 + 0.24 * math.sin(time * 2 * math.pi * (3 if breath else 23)) ** 2
        shape = math.sin(math.pi * time / duration) ** (0.8 if breath else 0.35)
        value = (low - base) * amplitude * shape * gudu
        if breath:
            # A very quiet warm resonance supports the breath without words.
            value += math.sin(2 * math.pi * (145 * time - 13 * time * time)) * 0.009 * shape
        target = int(start * RATE) + index
        if target < len(buffer):
            buffer[target] += value * envelope(time, duration)


def add_drop(buffer, start, duration, frequency, amplitude, gulp=False):
    phase = 0.0
    rng = random.Random(int(start * 1000))
    filtered = 0.0
    for index in range(int(duration * RATE)):
        time = index / RATE
        p = time / duration
        pitch = frequency * (1 - 0.65 * p) + 23 * math.sin(p * math.pi)
        phase += 2 * math.pi * pitch / RATE
        shape = math.sin(math.pi * p) ** (1.3 if gulp else 0.6) * math.exp(-p * (1 if gulp else 4))
        filtered += 0.12 * (rng.uniform(-1, 1) - filtered)
        value = math.sin(phase) * 0.68 + math.sin(phase * 1.87) * 0.16 + filtered * (0.8 if gulp else 0.2)
        target = int(start * RATE) + index
        if target < len(buffer):
            buffer[target] += value * amplitude * shape * envelope(time, duration, 0.012, 0.03)


def add_shimmer(buffer, start, amplitude):
    for index in range(int(0.8 * RATE)):
        time = index / RATE
        shape = math.sin(math.pi * time / 0.8) ** 0.8 * math.exp(-time * 3)
        value = sum(math.sin(2 * math.pi * freq * time) for freq in (659.25, 987.77, 1318.51)) / 3
        target = int(start * RATE) + index
        if target < len(buffer):
            buffer[target] += value * shape * amplitude


def write(filename, samples):
    OUTPUT.mkdir(exist_ok=True)
    peak = max(abs(sample) for sample in samples)
    gain = min(1, 0.72 / max(peak, 0.001))
    pcm = b"".join(struct.pack("<h", round(max(-1, min(1, sample * gain)) * 32767)) for sample in samples)
    with wave.open(str(OUTPUT / filename), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(pcm)
    print(f"Generated {filename}: {len(samples) / RATE:.1f}s, peak {peak:.3f}")


ritual = [0.0] * (15 * RATE)
add_noise(ritual, 1.45, 2.95, 0.31, 42)
for start, frequency in [(1.6, 1400), (2.15, 1100), (2.85, 1250), (3.6, 1000), (4.45, 1450), (4.7, 1700)]:
    add_drop(ritual, start, 0.14, frequency, 0.05)
for start, frequency in [(7.15, 370), (7.75, 330), (8.35, 300)]:
    add_drop(ritual, start, 0.29, frequency, 0.19, gulp=True)
add_noise(ritual, 10.65, 1.55, 0.48, 7, breath=True)
add_shimmer(ritual, 11.8, 0.043)
write("HydrationRitual.wav", ritual)

satisfied = [0.0] * int(1.1 * RATE)
add_noise(satisfied, 0, 0.9, 0.32, 8, breath=True)
add_shimmer(satisfied, 0.2, 0.04)
write("Satisfied.wav", satisfied)
