"""Edit native Godot footage into a 75 s trailer and a worn Happyland advert.

Prerequisites: FFmpeg, numpy; media_capture.tscn renders into TEMP/after-play-media.
The four local German TTS takes are generated separately by System.Speech.
Authoring files and raw footage never enter the player package.
"""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'games/kinderparadies'
ASSETS = PROJECT / 'assets'
WORK = Path(os.environ['TEMP']) / 'after-play-media'
OUT = PROJECT / 'build/trailer'
FILM = ASSETS / 'cinema-film'
RATE = 48000
# The installed FFmpeg 8.1.2 build produced invalid Theora qpi packets even for
# testsrc2. Use the checksum-verified portable 7.1 authoring binary when present.
COMPAT = ROOT / 'tools/art-source/media-ffmpeg/ffmpeg-compat.exe'
FFMPEG = str(COMPAT) if COMPAT.is_file() else shutil.which('ffmpeg')
FFPROBE = shutil.which('ffprobe')
RNG = np.random.default_rng(2100)


def run(args, name):
    OUT.mkdir(parents=True, exist_ok=True)
    with (OUT / (name + '.log')).open('w', encoding='utf-8') as log:
        subprocess.run([FFMPEG, '-hide_banner', '-y', *map(str, args)], stdout=log, stderr=log, check=True)


def read(path, start=0, duration=None):
    args = [FFMPEG, '-v', 'error', '-ss', str(start), '-i', str(path)]
    if duration is not None:
        args += ['-t', str(duration)]
    result = subprocess.run(args + ['-f', 'f32le', '-ar', str(RATE), '-ac', '2', 'pipe:1'], capture_output=True, check=True)
    return np.frombuffer(result.stdout, dtype='<f4').reshape(-1, 2).copy()


def save(path, data):
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(2); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes((np.clip(data, -.99, .99) * 32767).astype('<i2').tobytes())


def rms(data):
    return float(np.sqrt(np.mean(data.astype(np.float64) ** 2)))


def normal(data, level=.12):
    return data * (level / max(rms(data), 1e-5))


def place(mix, data, at, gain=1):
    start = round(at * RATE); count = min(len(data), len(mix) - start)
    if count <= 0:
        return
    clip = data[:count].copy() * gain
    edge = min(round(.012 * RATE), count // 2)
    if edge:
        clip[:edge] *= np.linspace(0, 1, edge)[:, None]
        clip[-edge:] *= np.linspace(1, 0, edge)[:, None]
    mix[start:start+count] += clip


def tone(freq, duration, bell=False):
    t = np.arange(round(duration * RATE), dtype=np.float32) / RATE
    if bell:
        signal = (np.sin(t*freq*2*np.pi) + .35*np.sin(t*freq*4.01*np.pi) + .12*np.sin(t*freq*6.07*np.pi))*np.exp(-t*3)
    else:
        signal = np.sin(2*np.pi*(freq*t+12*(1-np.exp(-t*18))/18))*np.exp(-t*8)
    return np.column_stack([signal, signal])


def trailer_audio():
    mix = np.zeros((75*RATE, 2), np.float32)
    t = np.arange(len(mix), dtype=np.float32) / RATE
    music = normal(read(ASSETS/'menu/abandoned-arcade.mp3', duration=75), .115)
    envelope = np.interp(np.arange(len(music))/RATE, [0,2,14,23,35,44,55,59.7,59.85,62.4,63,70,74,75],
                         [.04,.18,.40,.68,.85,1.1,1.4,1.6,0,0,1,.9,.5,0])
    mix[:len(music)] += music * envelope[:, None]
    box = normal(read(ASSETS/'party/musicbox.mp3', duration=18), .055)
    box *= np.interp(np.arange(len(box))/RATE, [0,1,10,18], [0,1,.75,0])[:, None]
    place(mix, box, 0)
    air = read(ASSETS/'ambience/ventilation.ogg', duration=75)
    if len(air) < len(mix):
        air = np.tile(air, (int(np.ceil(len(mix)/len(air))), 1))[:len(mix)]
    mix += normal(air, .006)[:len(mix)]
    # A restrained low pulse grows from a slow heartbeat into a faster cut rhythm.
    for start, end, interval, gain in [(20,35,1.5,.045),(35,44,.75,.055),(44,55,.5,.065),(55,59.7,.25,.07)]:
        for at in np.arange(start, end, interval):
            place(mix, tone(43,.55), float(at), gain)
    for at in [19.65,31.6,42.6,54.6,58.8,62.35]:
        dur = .75
        n = round(dur*RATE); noise=RNG.normal(0,.03,(n,2)).astype(np.float32)
        noise *= np.linspace(0,1,n)[:, None]**2
        place(mix, noise, at)
    for at, file, level, limit in [
        (2.6, 'intro/chime.wav', .075, 1.5),
        (13.2, 'ambience/children-laugh.ogg', .024, 3),
        (20.0, 'scares-v260/dry-impact.wav', .13, .8),
        (23.5, 'annex/stir-pot.wav', .025, 3.5),
        (28.1, 'annex/projector.wav', .02, 3.8),
        (32.0, 'ambience-v193/metal-door.wav', .095, .9),
        (40.1, 'door.ogg', .055, 1.2),
        (44.3, 'ambience-v180/floor-creak.wav', .055, 1.3),
        (47.1, 'ambience/children-cry.ogg', .035, 2.8),
        (55.05, 'ambience-v193/ghost-run.wav', .065, 1),
        (60.43, 'scares-v260/ragged-scream.wav', .20, .65),
        (62.8, 'scares-v260/bass-roar.wav', .085, 1.0),
    ]:
        place(mix, normal(read(ASSETS/file, duration=limit), level), at)
    # Clear negative space immediately before and after the short attack.
    gate = np.interp(t, [0,.2,59.7,59.8,60.35,60.4,61.18,61.23,62.35,62.5,74,75], [0,1,1,0,0,1,1,0,0,1,1,0])
    mix *= gate[:, None]
    save(WORK/'trailer-mix.wav', np.tanh(mix*.9))
    run(['-i', WORK/'trailer-mix.wav', '-af', 'loudnorm=I=-16:TP=-1.5:LRA=9', '-ar', RATE,
         '-c:a', 'pcm_s24le', OUT/'After-Play-Trailer-Mix.wav'], 'trailer-audio')


def film_audio():
    mix = np.zeros((34*RATE,2),np.float32)
    # Original simple major-key fairground waltz, deliberately aged in the master.
    notes = [72,76,79,76,74,77,81,77,71,74,79,74,72,76,79,84]
    for k in range(72):
        midi=notes[k%len(notes)]; at=k*.46
        place(mix,tone(440*2**((midi-69)/12),1.4,True),at,.055)
        if k%3==0: place(mix,tone(440*2**(((48 if k%12<6 else 43)-69)/12),1.0,True),at,.04)
    for index,at in enumerate([1.2,8.5,17.2,26.1]):
        voice=read(WORK/f'advert-voice-{index}.wav')
        place(mix,normal(voice,.19),at)
    t=np.arange(len(mix),dtype=np.float32)/RATE
    mix *= (1+.018*np.sin(t*2*np.pi*3.1))[:,None]
    mix += RNG.normal(0,.004,mix.shape).astype(np.float32)
    mix *= np.minimum(np.minimum(t/.2,(34-t)/.8),1)[:,None]
    save(WORK/'advert-mix.wav',mix)
    run(['-i', WORK/'advert-mix.wav','-af','highpass=f=330,lowpass=f=3100,asoftclip=type=tanh,aecho=0.8:0.4:45:0.06,loudnorm=I=-21:TP=-4:LRA=5',
         '-t',34,'-ar',24000,'-ac',1,'-c:a','libvorbis','-q:a',3,FILM/'happyland-advert.ogg'],'advert-audio')


def stamp(seconds):
    ticks=round(seconds*100)
    return f'{ticks//360000}:{ticks//6000%60:02}:{ticks//100%60:02}.{ticks%100:02}'


def subtitles(film=False):
    header = '''[Script Info]
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
ScaledBorderAndShadow: yes
YCbCr Matrix: TV.709

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Main,Oswald,72,&H00DBE6EC,&H000000FF,&H00101513,&H90000000,-1,0,0,0,100,100,6,0,1,1,2,5,100,100,50,1
Style: Small,Oswald,29,&H00CAD3D3,&H000000FF,&H00101513,&H90000000,0,0,0,0,100,100,5,0,1,1,1,5,100,100,50,1
Style: Title,Oswald,194,&H00DBE6EC,&H000000FF,&H00101513,&H90000000,-1,0,0,0,100,100,17,0,1,0,0,5,100,100,50,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
'''
    rows=[]
    def text(start,end,content,style='Main',x=960,y=540,extra=''):
        rows.append(f'Dialogue: 0,{stamp(start)},{stamp(end)},{style},,0,0,0,,{{\\pos({x},{y})\\fad(280,280){extra}}}{content}')
    if film:
        text(.3,4.7,'HAPPYLAND',extra=r'\fs112\fsp8\c&H9FF4FF&')
        text(.5,4.7,'HIER BEGINNT DEIN ABENTEUER.', 'Small', y=660,extra=r'\fs34\fsp2')
        text(6.5,10.6,'SPIELEN. STAUNEN. LACHEN.',y=870,extra=r'\fs47\fsp2')
        text(18.3,22.6,'DEIN GEBURTSTAG. DEIN TAG.',y=870,extra=r'\fs47\fsp2')
        text(28.8,33.3,'HAPPYLAND',extra=r'\fs112\fsp8\c&H9FF4FF&')
        text(29,33.3,'GROSSE ABENTEUER FÜR KLEINE GÄSTE.', 'Small',y=660,extra=r'\fs32\fsp1')
    else:
        text(7.5,11.7,'ERINNERE DICH AN DIESEN ORT.','Small',y=925,extra=r'\fs32\fsp5')
        text(20.25,22.75,'DU HAST DIE NACHTSCHICHT.',extra=r'\fs65\fsp8')
        text(32.25,34.75,'13 RUNDGÄNGE.',extra=r'\fs105\fsp11')
        text(32.5,34.75,'MERKE DIR JEDES DETAIL.','Small',y=675)
        text(35.5,39.6,'NORMAL? GRÜN.','Small',x=610,y=932,extra=r'\c&HA4CCA1&\fs35\fsp4')
        text(35.5,39.6,'ANOMALIE? ROT.','Small',x=1310,y=932,extra=r'\c&H7F80D1&\fs35\fsp4')
        text(43.05,43.95,'EIN FEHLER REICHT.',extra=r'\fs75\fsp8\fad(100,100)')
        text(62.85,69.6,'AFTER PLAY','Title',y=490,extra=r'\fscx98\fscy98\t(0,4500,\fscx102\fscy102)')
        text(63.7,69.6,'DREIZEHN RUNDGÄNGE. KEINE ZWEITE SICHERHEIT.','Small',y=666,extra=r'\fs27\fsp4')
        text(70.1,74.8,'DEINE NACHTSCHICHT WARTET.',extra=r'\fs64\fsp6')
        text(70.4,74.8,'JETZT FÜR WINDOWS & WEB','Small',y=655,extra=r'\fs32\c&HABC0AE&')
        text(70.4,74.8,'EIN HORRORSPIEL VON KYOKO','Small',y=805,extra=r'\fs23\fsp4')
        text(70.4,74.8,'Musik: Abandoned Arcade · turbulentmicrogenres466','Small',y=973,extra=r'\fs18\fsp1\c&H83918A&')
    path=WORK/('advert.ass' if film else 'trailer.ass')
    path.write_text(header+'\n'.join(rows)+'\n',encoding='utf-8')
    return path


def filter_path(path):
    return str(path.resolve()).replace('\\','/').replace(':',r'\:').replace("'",r"\'")


def build_film():
    FILM.mkdir(parents=True,exist_ok=True)
    film_audio()
    ass=subtitles(True)
    filters=("crop=ih*4/3:ih,scale=640:480,fps=15,eq=saturation=0.57:contrast=0.84:brightness=0.035:gamma=1.08,"
             "noise=alls=12:allf=t+u,vignette=PI/5,"
             f"ass=filename='{filter_path(ass)}':fontsdir='{filter_path(WORK/'fonts')}',"
             "drawbox=x=98:y=0:w=1:h=ih:color=white@0.13:t=fill:enable='lt(mod(t,2.7),0.12)',"
             "drawbox=x=461:y=0:w=1:h=ih:color=black@0.2:t=fill:enable='lt(mod(t,4.3),0.15)',"
             "fade=t=in:st=0:d=0.3,fade=t=out:st=33.2:d=0.8,setsar=1")
    run(['-i',WORK/'film-raw.avi','-an','-t',34,'-vf',filters,'-c:v','libtheora','-q:v',5,'-pix_fmt','yuv420p',FILM/'happyland-advert.ogv'],'advert-video')
    run(['-i',FILM/'happyland-advert.ogv','-i',FILM/'happyland-advert.ogg','-t',34,'-c:v','libx264','-preset','medium','-crf',20,'-c:a','aac','-b:a','128k','-movflags','+faststart',OUT/'Happyland-Alter-Werbefilm.mp4'],'advert-preview')
    (FILM/'LICENSE.txt').write_text('Happyland archival advert: original moving native game-world capture, edit, lettering, major-key waltz and ageing effects produced for After Play. German announcement generated locally using Microsoft Hedda Desktop speech synthesis. Uses the existing game environment and its asset licenses; does not relicense imported assets. Raw footage and production scripts are excluded from player packages.\n',encoding='utf-8')
    print('Created 34 s 4:3 Happyland film, spatial audio and MP4 preview.',flush=True)


def build_trailer():
    trailer_audio()
    ass=subtitles()
    # The nostalgic cold open uses the same optional film players can discover.
    graph=(f"[0:v]scale=1920:1080:flags=lanczos,setsar=1,fps=30,eq=contrast=1.035:gamma=1.10:saturation=0.94,vignette=PI/6[game];"
           "[1:v]scale=1440:1080,pad=1920:1080:240:0:black,fps=30,setsar=1[old];"
           f"[game][old]overlay=0:0:enable='lt(t,2)':eof_action=pass,ass=filename='{filter_path(ass)}':fontsdir='{filter_path(WORK/'fonts')}',"
           "fade=t=out:st=74.6:d=0.4,format=yuv420p[v]")
    run(['-i',WORK/'trailer-raw.avi','-i',OUT/'Happyland-Alter-Werbefilm.mp4','-i',OUT/'After-Play-Trailer-Mix.wav',
         '-filter_complex_threads',2,'-filter_complex',graph,'-map','[v]','-map','2:a:0','-t',75,
         '-c:v','libx264','-preset','medium','-crf',17,'-profile:v','high','-level','4.1','-pix_fmt','yuv420p',
         '-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709','-c:a','aac','-b:a','256k','-ar',48000,
         '-movflags','+faststart','-metadata','title=After Play – Offizieller Trailer','-metadata','artist=Kyoko',
         OUT/'After-Play-Trailer-1080p.mp4'],'trailer-master')
    run(['-ss',66,'-i',OUT/'After-Play-Trailer-1080p.mp4','-frames:v',1,OUT/'After-Play-Trailer-Poster.jpg'],'trailer-poster')
    run(['-i',OUT/'After-Play-Trailer-1080p.mp4','-vf',"fps=1/5,scale=384:216,tile=5x3",'-frames:v',1,OUT/'Trailer-Kontaktbogen.jpg'],'trailer-contact')
    video=OUT/'After-Play-Trailer-1080p.mp4'
    metadata=json.loads(subprocess.run([FFPROBE,'-v','error','-show_format','-show_streams','-of','json',str(video)],capture_output=True,text=True,encoding='utf-8',check=True).stdout)
    metadata['sha256']=hashlib.file_digest(video.open('rb'),'sha256').hexdigest()
    (OUT/'trailer-metadata.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (OUT/'MEDIEN-INFO.txt').write_text('After Play – Offizieller Trailer\n75 Sekunden · 1920 × 1080 · 30 FPS · H.264/AAC · 16:9\nDeutsche Texteinblendungen, echte bewegte native Spielszenen, Musik und Sounddesign. Das geheime Ende wird nicht gezeigt.\n\nMusik: vom Ersteller bereitgestelltes Abandoned Arcade (turbulentmicrogenres466), Musikbox sowie Soundeffekte aus dem Spiel gemäß den bestehenden Lizenzhinweisen. Zusätzliche Puls-/Übergangsklänge sind projektintern erzeugt. Keine neue CC0-Lizenz für die bereitgestellten Musikaufnahmen.\n\nDer separate 34-Sekunden-Werbefilm ist fiktives Happyland-Archivmaterial und kann im Kino freiwillig abgespielt werden.\n',encoding='utf-8')
    print('Created 75 s 1080p trailer, audio master, poster, contact sheet and metadata.',flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--only',choices=['film','trailer','all'],default='all');args=parser.parse_args()
    WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    (WORK/'fonts').mkdir(exist_ok=True);shutil.copy2(ASSETS/'Oswald.ttf',WORK/'fonts/Oswald.ttf')
    if args.only in ['film','all']: build_film()
    if args.only in ['trailer','all']: build_trailer()
