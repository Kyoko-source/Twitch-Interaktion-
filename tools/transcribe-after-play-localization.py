"""Offline caption preparation using the existing local Whisper model cache."""
from pathlib import Path
import json,subprocess
import numpy as np
from faster_whisper import WhisperModel

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'tools/art-source/after-play-narration/localization-transcript.json'
model=WhisperModel('small',device='cpu',compute_type='int8',cpu_threads=8,
 download_root=str(ROOT/'tools/art-source/whisper-models'),local_files_only=True)
files=['intro/chef.mp3','cinema-film/happyland-advert.ogg']
result={}
for name in files:
 pcm=subprocess.run([str(ROOT/'tools/art-source/media-ffmpeg/ffmpeg-compat.exe'),'-v','error','-i',str(ROOT/'games/kinderparadies/assets'/name),'-f','f32le','-ar','16000','-ac','1','pipe:1'],capture_output=True,check=True).stdout
 audio=np.frombuffer(pcm,dtype=np.float32).copy()
 segments,info=model.transcribe(audio,language='de',beam_size=5,word_timestamps=True,vad_filter=True)
 rows=[]
 for s in segments:
  row=dict(start=s.start,end=s.end,text=s.text.strip(),words=[dict(start=w.start,end=w.end,text=w.word,probability=w.probability) for w in s.words or []]);rows.append(row)
  print(name,round(s.start,2),round(s.end,2),s.text,flush=True)
 result[name]=dict(duration=info.duration,segments=rows)
 OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
