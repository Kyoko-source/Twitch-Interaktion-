import React,{useEffect,useRef,useState} from 'react';
import {Mic,Square,Play,Save,Upload,Trash2} from 'lucide-react';
import {voiceWav} from './FarmAudio';
import {requestId} from '../economy/useGameRewards';

function microphoneError(err) {
  if(err.name==='NotAllowedError')return 'Mikrofonfreigabe fehlt. Erlaube das Mikrofon in deinem Browser und in den Datenschutzeinstellungen deines Systems oder wähle eine Audiodatei.';
  if(err.name==='NotFoundError')return 'Kein Mikrofon gefunden. Verbinde eines oder wähle eine Audiodatei.';
  if(err.name==='NotReadableError')return 'Das Mikrofon lässt sich nicht öffnen. Prüfe, ob eine andere App es exklusiv verwendet, oder wähle ein anderes Mikrofon.';
  if(err.name==='OverconstrainedError')return 'Das ausgewählte Mikrofon ist nicht mehr verfügbar. Wähle ein anderes Mikrofon oder das Standardmikrofon.';
  return err.message;
}

export function VoiceRecorder({animal,species,audio,onBeforeRecording,onSave,disabled}) {
  const [recording,setRecording]=useState(false),[testing,setTesting]=useState(false),[preparing,setPreparing]=useState(false),[elapsed,setElapsed]=useState(0),[candidate,setCandidate]=useState(null),[name,setName]=useState('Meine Stimme'),[allSpecies,setAllSpecies]=useState(false),[error,setError]=useState('');
  const [devices,setDevices]=useState([]),[deviceId,setDeviceId]=useState(''),[inputName,setInputName]=useState(''),[signal,setSignal]=useState(false),[level,setLevel]=useState(0);
  const recorder=useRef(null),stream=useRef(null),timer=useRef(null),clock=useRef(null),alive=useRef(true),canvas=useRef(null),frame=useRef(null),preview=useRef(null),source=useRef(null),monitor=useRef(null),lock=useRef(false),input=useRef(null),latestLevel=useRef(0),heard=useRef(false);
  const active=recording||testing;
  function stopTracks(){
    stream.current?.getTracks().forEach(track=>track.stop());stream.current=null;
    clearTimeout(timer.current);clearInterval(clock.current);cancelAnimationFrame(frame.current);
    source.current?.disconnect();source.current=null;monitor.current?.disconnect();monitor.current=null;
  }
  async function refreshDevices(){
    try{const list=await navigator.mediaDevices?.enumerateDevices();if(alive.current)setDevices((list||[]).filter(device=>device.kind==='audioinput'&&device.deviceId&&device.deviceId!=='default'));}catch{/* Recording still works without device enumeration. */}
  }
  useEffect(()=>{
    alive.current=true;refreshDevices();navigator.mediaDevices?.addEventListener?.('devicechange',refreshDevices);
    return()=>{alive.current=false;navigator.mediaDevices?.removeEventListener?.('devicechange',refreshDevices);stopTracks();if(recorder.current?.state==='recording')recorder.current.stop();preview.current?.pause();};
  },[]);
  useEffect(()=>{if(!candidate)return;return()=>URL.revokeObjectURL(candidate.url);},[candidate]);
  async function prepare(blob){
    if(!alive.current)return;setPreparing(true);
    try{const context=await audio.unlock(),result=await voiceWav(context,blob);if(alive.current)setCandidate({...result,url:URL.createObjectURL(result.blob),requestId:requestId()});}
    catch(err){if(alive.current)setError(err.message);}
    finally{if(alive.current)setPreparing(false);}
  }
  function stop(){
    if(recorder.current?.state==='recording'){if(alive.current)setPreparing(true);recorder.current.stop();}
    stopTracks();if(alive.current){setRecording(false);setTesting(false);setLevel(0);}
  }
  async function capture(testOnly=false){
    if(lock.current)return;lock.current=true;preview.current?.pause();setError('');setPreparing(true);
    if(!testOnly)setCandidate(null);
    setSignal(false);setLevel(0);heard.current=false;latestLevel.current=0;
    try{
      const context=await audio.unlock();await onBeforeRecording();
      if(!window.isSecureContext||!navigator.mediaDevices?.getUserMedia)throw new Error('Für dein Mikrofon öffne die Farm über HTTPS. Alternativ kannst du eine Audiodatei wählen.');
      if(!testOnly&&!window.MediaRecorder)throw new Error('Dieser Browser kann nicht aufnehmen. Wähle eine Audiodatei oder verwende einen aktuellen Browser.');
      // Speech noise gates can remove quiet voices, humming and odd animal sounds.
      const mic=await navigator.mediaDevices.getUserMedia({audio:{...(deviceId?{deviceId:{exact:deviceId}}:{}),echoCancellation:false,noiseSuppression:false,autoGainControl:false}});
      if(!alive.current){mic.getTracks().forEach(track=>track.stop());return;}
      stream.current=mic;setInputName(mic.getAudioTracks()[0]?.label||'Standardmikrofon');refreshDevices();
      if(context.state==='suspended')await context.resume();
      if(!alive.current){stopTracks();return;}
      if(!testOnly){
        const mime=['audio/webm;codecs=opus','audio/mp4','audio/webm'].find(type=>MediaRecorder.isTypeSupported(type));
        const next=new MediaRecorder(mic,mime?{mimeType:mime}:undefined),chunks=[];let failed=false;recorder.current=next;
        next.ondataavailable=event=>{if(event.data.size)chunks.push(event.data);};
        next.onstop=()=>{stopTracks();if(alive.current){setRecording(false);if(!failed)prepare(new Blob(chunks,{type:next.mimeType}));}};
        next.onerror=()=>{failed=true;stopTracks();if(alive.current){setRecording(false);setPreparing(false);setError('Die Aufnahme wurde unterbrochen. Bitte erneut versuchen.');}};
        next.start();
      }
      const analyser=context.createAnalyser();analyser.fftSize=512;
      source.current=context.createMediaStreamSource(mic);monitor.current=context.createGain();monitor.current.gain.value=0;
      source.current.connect(analyser);analyser.connect(monitor.current).connect(context.destination);
      const values=new Float32Array(analyser.fftSize);
      const draw=()=>{
        if(!alive.current||!stream.current)return;
        analyser.getFloatTimeDomainData(values);let peak=0;for(const value of values)peak=Math.max(peak,Math.abs(value));
        latestLevel.current=Math.min(100,Math.round(Math.sqrt(peak)*100));if(peak>=.0008)heard.current=true;
        const ctx=canvas.current?.getContext('2d');
        if(ctx){ctx.clearRect(0,0,320,52);ctx.strokeStyle='#a9d3aa';ctx.lineWidth=2;ctx.beginPath();values.forEach((value,i)=>{const y=26-Math.max(-1,Math.min(1,value*8))*24;if(i)ctx.lineTo(i/values.length*320,y);else ctx.moveTo(0,y);});ctx.stroke();}
        frame.current=requestAnimationFrame(draw);
      };
      setRecording(!testOnly);setTesting(testOnly);setPreparing(false);setElapsed(0);const started=performance.now();
      clock.current=setInterval(()=>{setElapsed(Math.min(testOnly?10:4,(performance.now()-started)/1000));setLevel(latestLevel.current);setSignal(heard.current);},100);
      timer.current=setTimeout(stop,testOnly?10000:4000);draw();
    }catch(err){stopTracks();if(recorder.current?.state==='recording'){recorder.current.onstop=null;recorder.current.stop();}if(alive.current){setRecording(false);setTesting(false);setPreparing(false);setError(microphoneError(err));}}
    finally{lock.current=false;}
  }
  async function save(){if(lock.current||!candidate)return;lock.current=true;setPreparing(true);setError('');try{await onSave(candidate.blob,{name:name.trim()||'Meine Stimme',animal_id:animal.id,all_species:allSpecies,request_id:candidate.requestId});setCandidate(null);}catch(err){setError(err.message);}finally{lock.current=false;setPreparing(false);}}
  const blocked=disabled||preparing||active;
  return <div className="farmRecorder">
    <label>Mikrofon<select aria-label="Mikrofon auswählen" value={deviceId} onChange={event=>{setDeviceId(event.target.value);setInputName('');setError('');setSignal(false);}} disabled={blocked}><option value="">Standardmikrofon (Browser)</option>{devices.map((device,index)=><option key={device.deviceId} value={device.deviceId}>{device.label||`Mikrofon ${index+1}`}</option>)}</select></label>
    <button type="button" className="farmSecondary" disabled={disabled||preparing||recording} onClick={()=>testing?stop():capture(true)}>{testing?<Square size={16}/>:<Mic size={16}/>} {testing?'Mikrofontest stoppen':'Mikrofon testen'}</button>
    <div className={`farmWave ${active?'isRecording':''}`}><span className="farmRecordDot"/><canvas ref={canvas} width="320" height="52" aria-label="Mikrofonpegel"/><time>{active?elapsed.toFixed(1):candidate?candidate.duration.toFixed(1):'0.0'} / {testing?'10':'4'} s</time></div>
    {active&&<div className="farmMicStatus"><meter aria-label="Mikrofonlautstärke" min="0" max="100" value={level}/><p role="status">{signal?'Ton kommt an.':elapsed<1?'Sprich jetzt in dein Mikrofon.':'Noch kein Ton: Prüfe die Stummschalttaste oder wähle ein anderes Mikrofon.'}</p></div>}
    {inputName&&<p className="farmCaption">Eingang: {inputName}</p>}
    <button type="button" className="farmPrimary" onClick={()=>recording?stop():capture()} disabled={disabled||preparing||testing}>{recording?<Square size={18}/>:<Mic size={18}/>} {recording?'Aufnahme stoppen':preparing?'Wird vorbereitet …':'Sound aufnehmen'}</button>
    <p className="farmCaption">Bis zu 4 Sekunden. Leise Aufnahmen werden automatisch verstärkt. Beim Mikrofontest wird nichts gespeichert.</p>
    {candidate&&<label>Name der Aufnahme<input maxLength={40} value={name} onChange={event=>setName(event.target.value)} disabled={blocked}/></label>}
    <div className="farmRecorderActions"><button type="button" className="farmSecondary" disabled={!candidate||blocked} onClick={()=>{preview.current?.pause();preview.current=new Audio(candidate.url);preview.current.volume=.65;preview.current.play().catch(()=>setError('Die Vorschau konnte nicht gestartet werden.'));}}><Play size={16}/> Anhören</button><button type="button" className="farmSecondary" disabled={!candidate||blocked} onClick={save}><Save size={16}/> Stimme speichern</button></div>
    <label className="farmCheck"><input type="checkbox" checked={allSpecies} onChange={event=>setAllSpecies(event.target.checked)} disabled={blocked}/>Für alle {species?.plural||'Tiere dieser Art'} verwenden</label>
    <input type="file" accept="audio/*" hidden ref={input} onChange={async event=>{const file=event.target.files?.[0];event.target.value='';if(!file)return;if(file.size>10*1024*1024){setError('Bitte eine Audiodatei unter 10 MB wählen.');return;}setError('');try{await onBeforeRecording();await prepare(file);}catch(err){setError(err.message);}}}/>
    <button type="button" className="farmTextButton" disabled={blocked} onClick={()=>input.current?.click()}><Upload size={14}/> Audiodatei wählen (erste 4 Sekunden)</button>
    {candidate&&<button type="button" className="farmTextButton" disabled={blocked} onClick={()=>{preview.current?.pause();setCandidate(null);}}><Trash2 size={14}/> Aufnahme verwerfen</button>}
    {error&&<p className="farmError" role="alert">{error}</p>}
  </div>;
}
