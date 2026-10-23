"""Local-only narration analysis; audio is never uploaded to a service."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess
import numpy as np
from faster_whisper import WhisperModel

ROOT=Path(__file__).resolve().parents[1]
SOURCE=Path.home()/'Desktop/Horror Audio Marelle.wma'
OUT=ROOT/'tools/art-source/after-play-narration';OUT.mkdir(parents=True,exist_ok=True)
os.environ['HF_HUB_DISABLE_SYMLINKS_WARNING']='1'
model=WhisperModel('small',device='cpu',compute_type='int8',cpu_threads=8,download_root=str(ROOT/'tools/art-source/whisper-models'))
pcm=subprocess.run([shutil.which('ffmpeg'),'-v','error','-i',str(SOURCE),'-f','f32le','-ar','16000','-ac','1','pipe:1'],capture_output=True,check=True).stdout
samples=np.frombuffer(pcm,dtype=np.float32).copy()
segments,info=model.transcribe(samples,language='de',beam_size=5,word_timestamps=True,vad_filter=True,initial_prompt='After Play. Happyland. Kinderparadies. Marelle.')
result=[]
for segment in segments:
    row={'start':segment.start,'end':segment.end,'text':segment.text.strip(),'words':[{'start':w.start,'end':w.end,'text':w.word,'probability':w.probability} for w in segment.words or []]}
    result.append(row)
    print(f'[{segment.start:6.1f} - {segment.end:6.1f}] {segment.text}',flush=True)
    (OUT/'transcript.json').write_text(json.dumps({'source':SOURCE.name,'sha256':hashlib.file_digest(SOURCE.open('rb'),'sha256').hexdigest(),'duration':info.duration,'language':info.language,'method':'faster-whisper small CPU int8, local processing; automatic transcript requires editorial checking','segments':result},ensure_ascii=False,indent=2),encoding='utf-8')
print('Local narration analysis complete.',flush=True)
