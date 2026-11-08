"""Rework of all jumpscare voices and the horse's pursuit foley (4.2.1).

Replaces games/kinderparadies/assets/quality-v410/audio/{family}-{1..4}.ogg,
{family}-lead.ogg for every ScareBank family/voice, plus joint-{1..4}.ogg
(the horse's wet pursuit sound). File names and the output folder are
unchanged, so no GDScript or asset path needs to change.

Sources: the project's own existing credited recordings (Ogrebane CC0
monster-N.wav voices, Joseph SARDIN/Kenney CC0 impacts and surfaces, already
used throughout this project) plus "80 CC0 creature SFX" by rubberduck
(https://opengameart.org/content/80-cc0-creature-sfx, CC0 1.0), downloaded to
tools/art-source/creature-sfx-cc0/. Both sources are CC0; no attribution is
legally required, but both are credited in the shipped license notes anyway.
"""
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
A = ROOT / 'games/kinderparadies/assets'
CREATURE = ROOT / 'tools/art-source/creature-sfx-cc0'
OUT = A / 'quality-v410/audio'
OUT.mkdir(parents=True, exist_ok=True)
FF = shutil.which('ffmpeg')
assert FF
RATE = 32000
rng = np.random.default_rng(421)
report = {}


def read(path):
    result = subprocess.run([FF, '-v', 'error', '-i', str(path), '-ac', '1', '-ar', str(RATE), '-f', 'f32le', '-'],
                             capture_output=True, check=True)
    x = np.frombuffer(result.stdout, '<f4').astype(float)
    peak = np.max(np.abs(x))
    return x / max(.001, peak)


def band(x, low, high):
    """Soft band-pass: a highpass-like roll-off below `low`, lowpass above `high`."""
    f = np.fft.rfftfreq(len(x), 1 / RATE)
    lowpass = 1. / np.sqrt(1 + (f / high) ** 8)
    if low > 0:
        response = (f * f / (f * f + low * low)) * lowpass
    else:
        response = lowpass
    return np.fft.irfft(np.fft.rfft(x) * response, len(x))


def resample(src, speed, offset=0.):
    """Linear-interpolated speed change (speed>1 shortens & raises pitch)."""
    n = max(1, int((len(src) - 1 - offset * RATE) / speed))
    idx = offset * RATE + np.arange(n) * speed
    idx = np.clip(idx, 0, len(src) - 1.001)
    return np.interp(idx, np.arange(len(src)), src)


def add(dst, src, time, gain, speed=1., offset=0.):
    piece = resample(src, speed, offset)
    start = round(time * RATE)
    n = min(len(piece), len(dst) - start)
    if n < 1:
        return
    piece = piece[:n].copy()
    fade = min(n // 4, round(.015 * RATE))
    if fade:
        piece[:fade] *= np.linspace(0, 1, fade)
        piece[-fade:] *= np.linspace(1, 0, fade)
    dst[start:start + n] += piece * gain


def saturate(x, drive):
    """Soft-clip aggression without harsh digital clipping."""
    return np.tanh(x * drive) / np.tanh(drive)


def tail(x, taps):
    """A short multi-tap delay standing in for room/throat reverb."""
    out = x.copy()
    for delay, gain, damp in taps:
        shifted = np.zeros_like(x)
        n = round(delay * RATE)
        if n < len(x):
            shifted[n:] = x[:len(x) - n]
        if damp:
            shifted = band(shifted, 0, damp)
        out += shifted * gain
    return out


def sub(x, drop=.62, gain=.4, cutoff=260):
    """A slowed, low-passed duplicate mixed in quietly for weight."""
    thin = resample(x, drop)
    out = np.zeros_like(x)
    n = min(len(thin), len(out))
    out[:n] = thin[:n]
    return band(out, 0, cutoff) * gain


def write(name, x, peak_db, drive=1.0):
    if drive > 1.0:
        x = saturate(x, drive)
    x = band(x, 40, 12000)
    fade = min(len(x) // 4, round(.018 * RATE))
    if fade:
        x[:fade] *= np.linspace(0, 1, fade)
        x[-fade:] *= np.linspace(1, 0, fade)
    x *= 10 ** (peak_db / 20) / max(.001, np.max(np.abs(x)))
    path = OUT / (name + '.ogg')
    subprocess.run([FF, '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '1', '-i', '-',
                     '-c:a', 'libvorbis', '-q:a', '5', str(path)], input=x.astype('<f4').tobytes(), check=True)
    report[name] = {'seconds': round(len(x) / RATE, 3), 'peak_dbfs': peak_db,
                     'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


# ---------------------------------------------------------------- sources
voices = {i: read(ROOT / f'tools/art-source/v300/monster-{i}.wav') for i in range(1, 11)}
cloth = read(A / 'polish/impact-cloth.wav')
metal = read(A / 'ambience-v193/duct-stress.wav')
wood = read(A / 'surfaces/footstep_wood_002.ogg')
plastic = read(A / 'polish/impact-plastic.wav')

creature = {name: read(CREATURE / f'{name}.ogg') for name in [
    'roar_01', 'roar_02', 'roar_03', 'scream_01', 'scream_02', 'grunt_01', 'grunt_02', 'grunt_03',
    'grunt_04', 'grunt_05', 'howl', 'hurt_01', 'hurt_02', 'hurt_03', 'hurt_04', 'hurt_05',
    'monster_01', 'monster_02', 'monster_03', 'monster_04', 'monster_05', 'monster_06', 'monster_07',
    'burble_01', 'burble_02', 'breath', 'cute_03', 'cute_06',
]}

# ---------------------------------------------------------------- the three "voice" scares
# horse (horse_contact / ceiling_horse_hunt, catches 1-2): the explicit ask — bigger,
# nastier, louder than before. A size layer, a wet gurgling undertone, the existing
# clang-against-metal accent kept for continuity, and a sub layer for weight.
for variant in range(1, 5):
    x = np.zeros(round(RATE * 1.28))
    offset = .03 * (variant - 1)
    add(x, voices[3], 0, 1., 1.42 + variant * .03, offset)
    add(x, creature['roar_01' if variant % 2 else 'roar_03'], .01, .62, .92 + variant * .02)
    wet = saturate(band(creature['burble_01' if variant % 2 else 'burble_02'], 90, 900), 2.6)
    add(x, wet, .05, .40, .62 - variant * .01)
    add(x, metal, .06, .12, 1.35)
    x += sub(x, .58, .5, 240)
    x = tail(x, [(.045, .22, 2600), (.10, .12, 1800)])
    write(f'horse-{variant}', x, -1.2, drive=1.6)
lead = np.zeros(round(RATE * .80))
add(lead, creature['breath'], .0, .3, .85)
add(lead, voices[3], .22, .12, 1.0, .2)
write('horse-lead', lead, -15.)

# granny (roaming human visitors): deliberately kept close to a real human voice —
# no pitch-down or monster layer — but fuller and a touch louder, with a short
# presence tail instead of staying completely dry.
for variant in range(1, 5):
    x = np.zeros(round(RATE * 1.05))
    offset = .035 * (variant - 1)
    add(x, voices[7], 0, 1., 1., offset)
    add(x, voices[2], .012, .22, 1.01, offset * .6)
    x = band(x, 170, 6300)
    x = tail(x, [(.05, .14, 3200)])
    write(f'granny-{variant}', x, -3.5)
lead = np.zeros(round(RATE * .7))
add(lead, voices[7], 0, .22, .97)
write('granny-lead', lead, -16.)

# door (wrong-door death): harder, more percussive slam.
for variant in range(1, 5):
    x = np.zeros(round(RATE * .86))
    offset = .025 * (variant - 1)
    add(x, wood, 0, .95, .88)
    add(x, metal, .015, .22, 1.3)
    add(x, voices[8], .022, 1., .85 + variant * .028, offset)
    add(x, cloth, .12, .16)
    write(f'door-{variant}', x, -2.2, drive=1.3)
lead = np.zeros(round(RATE * .7))
add(lead, wood, 0, .3, .9)
add(lead, metal, .1, .1, 1.1)
write('door-lead', lead, -15.)

# ---------------------------------------------------------------- the ten "family" scares
FAMILY = {}


def family(name, build, peak, drive=1.2, duration=1.30, lead_build=None, lead_peak=-15.):
    for variant in range(1, 5):
        x = np.zeros(round(RATE * duration))
        build(x, variant)
        write(f'{name}-{variant}', x, peak, drive)
    lead = np.zeros(round(RATE * .75))
    (lead_build or (lambda l, v: None))(lead, 1)
    write(f'{name}-lead', lead, lead_peak)


# charge (rush/ambush/pursuit/crossing/door_death-adjacent): the single loudest, most
# aggressive roar, now actually sized like one — a roar, a harsher scream riding on
# top, a sub layer and a short throat-reverb tail.
def charge_build(x, variant):
    offset = .02 * (variant - 1)
    add(x, creature['roar_02'], 0, 1., .80 + variant * .02, offset)
    add(x, creature['scream_01' if variant % 2 else 'scream_02'], .02, .55, 1.1 + variant * .02)
    add(x, voices[8], .01, .35, .95 + variant * .02, offset)
    x += sub(x, .55, .42, 220)
    x[:] = tail(x, [(.05, .20, 3000), (.11, .09, 2000)])
family('charge', charge_build, -1.0, drive=1.7, duration=1.35,
       lead_build=lambda l, v: (add(l, creature['breath'], 0, .3, .7), add(l, metal, .1, .08, .9), add(l, cloth, .02, .3, .8)))

# crowd (queue/throne burst): several distinct throats layered with slight timing
# offsets, instead of one voice doubled.
def crowd_build(x, variant):
    add(x, creature['scream_01'], 0, .85, .97 + variant * .015)
    add(x, creature['monster_03'], .035, .7, 1.05 + variant * .02)
    add(x, voices[6], .07, .6, 1.0 + variant * .02)
    add(x, creature['howl'], .09, .4, .9)
    x[:] = tail(x, [(.06, .18, 2600)])
family('crowd', crowd_build, -1.8, drive=1.4, duration=1.35,
       lead_build=lambda l, v: (add(l, creature['burble_01'], 0, .25, .9), add(l, cloth, .02, .3, .8)))

# clown (kitchen clown, also used by the opened-jaw lunge): manic, cracked, with the
# existing kitchen metal-clang kept for continuity.
def clown_build(x, variant):
    offset = .018 * (variant - 1)
    add(x, voices[5], .015, 1., .98 + variant * .025, offset)
    add(x, creature['scream_02'], .02, .55, 1.25 + variant * .03)
    add(x, creature['grunt_02'], .0, .35, 1.4)
    add(x, metal, .1, .14, 1.8)
    add(x, cloth, .025, .18)
    x[:] = tail(x, [(.04, .15, 3400)])
family('clown', clown_build, -1.4, drive=1.6,
       lead_build=lambda l, v: (add(l, cloth, .01, .5, .7), add(l, metal, .13, .18, 1.1)))

# ossuary (vent/ceiling dweller): raspy, skeletal, now with a wet rattle under it.
def ossuary_build(x, variant):
    high = creature['monster_04' if variant % 2 else 'monster_05']
    t = np.arange(len(x)) / RATE
    pitched = np.interp(t * 1.5, np.arange(len(high)) / RATE, high, right=0)
    previous = np.concatenate(([0], pitched[:-1]))
    x[:] = (pitched - previous * .62) * .8
    add(x, creature['burble_02'], .02, .4, .7)
    add(x, metal, .05, .14, 1.6)
    x[:] = tail(x, [(.07, .22, 2000)])
family('ossuary', ossuary_build, -1.8, drive=1.5,
       lead_build=lambda l, v: (add(l, cloth, .01, .4, .7), add(l, creature['breath'], .18, .18, 1., .2)))

# crawler (tube crawler): wet, muffled, close and guttural.
def crawler_build(x, variant):
    offset = .02 * (variant - 1)
    add(x, creature['hurt_03' if variant % 2 else 'hurt_05'], 0, .9, .78 + variant * .02, offset)
    add(x, creature['burble_01'], .03, .55, .55)
    add(x, cloth, .08, .2)
    x[:] = band(x, 220, 2800)
family('crawler', crawler_build, -2.4, drive=1.4,
       lead_build=lambda l, v: (add(l, cloth, .01, .5, .75), add(l, creature['burble_02'], .15, .15, .7)))

# window (glass): a sharp shock plus a brittle crack transient.
def window_build(x, variant):
    t = np.arange(len(x)) / RATE
    crack = band(rng.standard_normal(len(x)), 1800, 9000) * np.exp(-t / .02)
    x += crack * .5
    add(x, creature['scream_02' if variant % 2 else 'scream_01'], .006, .8, 1.3 + variant * .02)
    add(x, metal, .01, .22, 2.0)
    x[:] = tail(x, [(.05, .1, 4000)])
family('window', window_build, -1.6, drive=1.5,
       lead_build=lambda l, v: (add(l, cloth, .01, .4, .7), add(l, metal, .13, .2, 1.3)))

# fall (ceiling drop): a falling whoosh, a hard impact thud, a scream at landing.
def fall_build(x, variant):
    t = np.arange(len(x)) / RATE
    noise = rng.standard_normal(len(x))
    whoosh = band(noise, 1400, 6000) * np.exp(-((t - .25) / .22) ** 2) * .5
    whoosh += band(noise, 150, 900) * np.exp(-((t - .4) / .2) ** 2) * .35
    x += whoosh
    add(x, wood, .42, .8, .55)
    add(x, metal, .42, .35, .5)
    add(x, creature['scream_01' if variant % 2 else 'monster_02'], .43, .6, 1.1)
    x += sub(x, .5, .3, 150)
family('fall', fall_build, -1.8, drive=1.4, duration=1.30,
       lead_build=lambda l, v: (add(l, wood, .05, .3, .9), add(l, metal, .13, .1, .8)))

# rabbit (plush mascot gone wrong): a toy pitched impossibly low, an uncanny edge.
def rabbit_build(x, variant):
    offset = .02 * (variant - 1)
    add(x, voices[1], .03, .85, 1.05 + variant * .02, offset)
    add(x, creature['cute_03' if variant % 2 else 'cute_06'], 0, .6, .45)
    add(x, plastic, .14, .22)
    x[:] = band(x, 150, 5200)
family('rabbit', rabbit_build, -1.8, drive=1.3,
       lead_build=lambda l, v: (add(l, cloth, .01, .4, .8), add(l, plastic, .15, .15, 1.1)))

# crocodile (snapping jaw): a low aggressive hiss-roar with a hard wood/plastic snap.
def crocodile_build(x, variant):
    offset = .02 * (variant - 1)
    add(x, creature['roar_03'], 0, .9, .74 + variant * .02, offset)
    add(x, voices[10], .015, .6, .79 + variant * .025, offset)
    add(x, wood, .02, .45)
    add(x, plastic, .02, .3)
    x += sub(x, .55, .4, 180)
family('crocodile', crocodile_build, -1.4, drive=1.5,
       lead_build=lambda l, v: (add(l, wood, .02, .3, .7), add(l, plastic, .14, .15, 1.0)))

# whisper (default ambient dread): stays the quiet one on purpose — breathy, close,
# unsettling rather than loud.
def whisper_build(x, variant):
    add(x, creature['breath'], 0, .7, .85 + variant * .01)
    add(x, voices[7], .05, .3, .7, .1)
    add(x, cloth, .1, .15, .8)
    x[:] = band(x, 90, 2200)
family('whisper', whisper_build, -8.0, drive=1.0,
       lead_build=lambda l, v: add(l, creature['breath'], 0, .3, .8), lead_peak=-20.)

# ---------------------------------------------------------------- horse pursuit foley
# joint-N.ogg: the recurring sound while the horse's head moves during a chase.
# Previously a thin pitched metal creak; now a wet, organic, slightly nauseating
# breath/gurgle, distinct from every other creature's dry mechanical foley.
for variant in range(1, 5):
    x = np.zeros(round(RATE * .70))
    offset = .02 * variant
    add(x, creature['breath'], 0, .7, .92 + variant * .03, offset)
    add(x, creature['burble_01' if variant % 2 else 'burble_02'], .03, .55, .60 + variant * .02)
    add(x, metal, .05, .05, 1.5)
    x[:] = band(x, 120, 2600)
    # A light bitcrush-style step quantising adds a nasty, slightly diseased texture.
    steps = 22
    x[:] = np.round(x * steps) / steps
    write(f'joint-{variant}', x, -9.0, drive=1.1)

(OUT.parent / 'audio-provenance.json').write_text(json.dumps({
    'author': 'Ogrebane; Joseph SARDIN; Kenney; rubberduck ("80 CC0 creature SFX"); original project edits',
    'license': 'Existing credited CC0 recordings plus CC0 1.0 (rubberduck pack); original sound design',
    'sources': ['https://opengameart.org/content/monster-sound-effects-pack',
                'https://opengameart.org/content/80-cc0-creature-sfx'],
}, indent=2), encoding='utf-8')
print('SCARE AUDIO V421', json.dumps({k: v['seconds'] for k, v in report.items()}))
