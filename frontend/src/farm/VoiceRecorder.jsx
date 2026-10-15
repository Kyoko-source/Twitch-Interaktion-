import React,{useEffect,useRef,useState} from 'react';
import {Mic,Square,Play,Save,Upload,Trash2} from 'lucide-react';
import {voiceWav} from './FarmAudio';
import {requestId} from '../economy/useGameRewards';

export function VoiceRecorder({animal,species,audio,onBeforeRecording,onSave,disabled}) {
  const [recording,setRecording]=useState(false),[preparing,setPreparing]=useState(false),[elapsed,setElapsed]=useState(0),[candidate,setCandidate]=useState(null),[name,setName]=useState('Meine Stimme'),[allSpecies,setAllSpecies]=useState(false),[error,setError]=useState('');
  const recorder=useRef(null),stream=useRef(null),timer=useRef(null),clock=useRef(null),alive=useRef(true),canvas=useRef(null),frame=useRef(null),preview=useRef(null),source=useRef(null),lock=useRef(false),input=useRef(null);
  function stopTracks(){stream.current?.getTracks().forEach(track=>track.stop());stream.current=null;clearTimeout(timer.current);clearInterval(clock.current);cancelAnimationFrame(frame.current);source.current?.disconnect();}
  useEffect(()=>{alive.current=true;return()=>{alive.current=false;stopTracks();if(recorder.current?.state==='recording')recorder.current.stop();preview.current?.pause();};},[]);
  useEffect(()=>{if(!candidate)return;return()=>URL.revokeObjectURL(candidate.url);},[candidate]);
  async function prepare(blob){
    if(!alive.current)return;setPreparing(true);
    try{const context=await audio.unlock(),result=await voiceWav(context,blob);if(alive.current)setCandidate({...result,url:URL.createObjectURL(result.blob),requestId:requestId()});}
    catch(err){if(alive.current)setError(err.message);}
    finally{if(alive.current)setPreparing(false);}
  }
  function stop(){if(recorder.current?.state==='recording')recorder.current.stop();stopTracks();setRecording(false);}
  async function record(){
    if(lock.current)return;lock.current=true;preview.current?.pause();setError('');setCandidate(null);setPreparing(true);
    try{
      const context=await audio.unlock();await onBeforeRecording();
      if(!window.isSecureContext||!navigator.mediaDevices?.getUserMedia)throw new Error('Für dein Mikrofon öffne die Farm über HTTPS. Alternativ kannst du eine Audiodatei wählen.');
      if(!window.MediaRecorder)throw new Error('Dieser Browser kann nicht aufnehmen. Wähle eine Audiodatei oder verwende einen aktuellen Browser.');
      const mic=await navigator.mediaDevices.getUserMedia({audio:{echoCancellation:true,noiseSuppression:true,autoGainControl:true}});
      if(!alive.current){mic.getTracks().forEach(track=>track.stop());return;}
      stream.current=mic;
      const mime=['audio/webm;codecs=opus','audio/mp4','audio/webm'].find(type=>MediaRecorder.isTypeSupported(type));
      const next=new MediaRecorder(mic,mime?{mimeType:mime}:undefined),chunks=[];recorder.current=next;
      next.ondataavailable=event=>{if(event.data.size)chunks.push(event.data);};
      next.onstop=()=>{stopTracks();if(alive.current){setRecording(false);prepare(new Blob(chunks,{type:next.mimeType}));}};
      next.onerror=()=>{stopTracks();if(alive.current){setRecording(false);setError('Die Aufnahme wurde unterbrochen. Bitte erneut versuchen.');}};
      const analyser=context.createAnalyser();analyser.fftSize=256;source.current=context.createMediaStreamSource(mic);source.current.connect(analyser);
      const values=new Uint8Array(analyser.frequencyBinCount);
      const draw=()=>{if(!alive.current)return;const ctx=canvas.current?.getContext('2d');if(ctx){analyser.getByteTimeDomainData(values);ctx.clearRect(0,0,320,52);ctx.strokeStyle='#a9d3aa';ctx.lineWidth=2;ctx.beginPath();values.forEach((value,i)=>{const y=(value/255)*52;if(i)ctx.lineTo(i/values.length*320,y);else ctx.moveTo(0,y);});ctx.stroke();}frame.current=requestAnimationFrame(draw);};
      next.start();setRecording(true);setPreparing(false);setElapsed(0);const started=performance.now();
      clock.current=setInterval(()=>setElapsed(Math.min(4,(performance.now()-started)/1000)),100);timer.current=setTimeout(stop,4000);draw();
    }catch(err){stopTracks();if(alive.current){setPreparing(false);setError(err.name==='NotAllowedError'?'Mikrofonfreigabe fehlt. Erlaube das Mikrofon in deinem Browser oder wähle eine Audiodatei.':err.name==='NotFoundError'?'Kein Mikrofon gefunden. Verbinde eines oder wähle eine Audiodatei.':err.message);}}
    finally{lock.current=false;}
  }
  async function save(){if(lock.current||!candidate)return;lock.current=true;setPreparing(true);setError('');try{await onSave(candidate.blob,{name:name.trim()||'Meine Stimme',animal_id:animal.id,all_species:allSpecies,request_id:candidate.requestId});setCandidate(null);}catch(err){setError(err.message);}finally{lock.current=false;setPreparing(false);}}
  const blocked=disabled||preparing||recording;
  return <div className="farmRecorder">
    <div className={`farmWave ${recording?'isRecording':''}`}><span className="farmRecordDot"/><canvas ref={canvas} width="320" height="52" aria-label="Mikrofonpegel"/><time>{recording?elapsed.toFixed(1):candidate?candidate.duration.toFixed(1):'0.0'} / 4 s</time></div>
    <button type="button" className="farmPrimary" onClick={recording?stop:record} disabled={disabled||preparing}>{recording?<Square size={18}/>:<Mic size={18}/>} {recording?'Aufnahme stoppen':preparing?'Wird vorbereitet …':'Sound aufnehmen'}</button>
    <p className="farmCaption">Bis zu 4 Sekunden. Nur für deine Farm.</p>
    {candidate&&<label>Name der Aufnahme<input maxLength={40} value={name} onChange={event=>setName(event.target.value)} disabled={blocked}/></label>}
    <div className="farmRecorderActions"><button type="button" className="farmSecondary" disabled={!candidate||blocked} onClick={()=>{preview.current?.pause();preview.current=new Audio(candidate.url);preview.current.volume=.65;preview.current.play().catch(()=>setError('Die Vorschau konnte nicht gestartet werden.'));}}><Play size={16}/> Anhören</button><button type="button" className="farmSecondary" disabled={!candidate||blocked} onClick={save}><Save size={16}/> Stimme speichern</button></div>
    <label className="farmCheck"><input type="checkbox" checked={allSpecies} onChange={event=>setAllSpecies(event.target.checked)} disabled={blocked}/>Für alle {species?.plural||'Tiere dieser Art'} verwenden</label>
    <input type="file" accept="audio/*" hidden ref={input} onChange={async event=>{const file=event.target.files?.[0];event.target.value='';if(!file)return;if(file.size>10*1024*1024){setError('Bitte eine Audiodatei unter 10 MB wählen.');return;}setError('');await onBeforeRecording();await prepare(file);}}/>
    <button type="button" className="farmTextButton" disabled={blocked} onClick={()=>input.current?.click()}><Upload size={14}/> Audiodatei wählen (erste 4 Sekunden)</button>
    {candidate&&<button type="button" className="farmTextButton" disabled={blocked} onClick={()=>{preview.current?.pause();setCandidate(null);}}><Trash2 size={14}/> Aufnahme verwerfen</button>}
    {error&&<p className="farmError" role="alert">{error}</p>}
  </div>;
}
