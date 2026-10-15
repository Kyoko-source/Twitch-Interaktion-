import React,{useEffect,useRef,useState} from 'react';
import {Coins,Mic,Pause,Play,PawPrint,ShoppingCart,Volume2,VolumeX,Trash2,Save} from 'lucide-react';
import {api} from '../api';
import {requestId} from '../economy/useGameRewards';
import {FarmAudio} from './FarmAudio';
import {VoiceRecorder} from './VoiceRecorder';
import {FarmScene} from './FarmScene';
import './farm.css';

const demoCatalog=[['sheep','Schaf','Schafe',1,8,40],['chicken','Huhn','Hühner',2,9,110],['duck','Ente','Enten',4,10,280],['pig','Schwein','Schweine',8,11,700],['cow','Kuh','Kühe',16,12,1800],['alpaca','Alpaka','Alpakas',32,13,4500]].map(([id,name,plural,income,interval,price],art)=>({id,name,plural,income,interval,price,art,owned:art===0?1:0}));
const empty={coins:0,earned:0,animals:[{id:'preview-sheep',species:'sheep',name:'Schaf 1',voice_id:null}],voices:[],catalog:demoCatalog,capacity:100};
const format=value=>Number(value).toLocaleString('de-DE');
function savedSettings(){try{return {...{enabled:true,volume:.65,density:'chaos'},...JSON.parse(localStorage.getItem('aviary-farm-audio')||'{}')};}catch{return {enabled:true,volume:.65,density:'chaos'};}}
export function AnimalArt({index=0}){return <span className="farmAnimalArt" aria-hidden="true" style={{backgroundPosition:`${(index%4)*100/3}% ${Math.floor(index/4)*50}%`}}/>;}

export function Quatschfarm({user}){
  const [farm,setFarm]=useState(empty),[loading,setLoading]=useState(Boolean(user)),[error,setError]=useState(''),[message,setMessage]=useState(''),[selected,setSelected]=useState(''),[running,setRunning]=useState(false),[busy,setBusy]=useState(false),[events,setEvents]=useState([]),[settings,setSettings]=useState(savedSettings),[query,setQuery]=useState(''),[attempt,setAttempt]=useState(0);
  const audio=useRef(null),lock=useRef(false),alive=useRef(true),runningRef=useRef(false),requests=useRef(new Map());
  if(!audio.current)audio.current=new FarmAudio();runningRef.current=running;
  const animal=farm.animals.find(entry=>entry.id===selected)||farm.animals[0],species=farm.catalog.find(entry=>entry.id===animal?.species),voice=farm.voices.find(entry=>entry.id===animal?.voice_id);
  const [editName,setEditName]=useState(''),[editVoice,setEditVoice]=useState(''),[editAll,setEditAll]=useState(false);
  useEffect(()=>{setEditName(animal?.name||'');setEditVoice(animal?.voice_id||'');setEditAll(false);},[animal?.id,animal?.name,animal?.voice_id]);
  useEffect(()=>{audio.current.settings(settings);try{localStorage.setItem('aviary-farm-audio',JSON.stringify(settings));}catch{}},[settings]);
  useEffect(()=>{alive.current=true;return()=>{alive.current=false;audio.current.dispose();if(runningRef.current)api('/api/farm/pause',{method:'POST',body:'{}'}).catch(()=>{});};},[]);
  useEffect(()=>{
    if(!user){setLoading(false);return;}let active=true;setLoading(true);setError('');
    api('/api/farm').then(result=>{if(active){setFarm(result);setSelected(result.animals[0]?.id||'');}}).catch(err=>{if(active)setError(err.message);}).finally(()=>{if(active)setLoading(false);});
    return()=>{active=false;};
  },[user?.username,attempt]);
  async function pause(){setRunning(false);audio.current.stop();if(user&&runningRef.current){try{const next=await api('/api/farm/pause',{method:'POST',body:'{}'});if(alive.current)setFarm(next);}catch(err){if(alive.current)setMessage(err.message);}}}
  useEffect(()=>{
    const stop=()=>{if(document.hidden)pause();};document.addEventListener('visibilitychange',stop);return()=>document.removeEventListener('visibilitychange',stop);
  },[user?.username]);
  useEffect(()=>{
    if(!running||!user)return;let cancelled=false,inFlight=false;
    const tick=async()=>{if(inFlight||document.hidden)return;inFlight=true;try{const result=await api('/api/farm/tick',{method:'POST',body:'{}'});if(cancelled)return;setFarm(result);setEvents(result.events||[]);if(!result.running){setRunning(false);audio.current.stop();setMessage('Die Farm ist pausiert. Starte sie, wenn du weiterspielen möchtest.');return;}for(const event of result.events||[])audio.current.play(event.voice_id).catch(()=>{if(alive.current)setMessage('Eine Stimme konnte nicht geladen werden. Deine Coins sind gespeichert.');});}catch(err){if(!cancelled)setMessage(`Verbindung unterbrochen: ${err.message}`);}finally{inFlight=false;}};
    const timer=setInterval(tick,1000);return()=>{cancelled=true;clearInterval(timer);};
  },[running,user?.username]);
  async function action(task){if(lock.current)return;lock.current=true;setBusy(true);setMessage('');try{await task();}catch(err){if(alive.current)setMessage(err.message);}finally{lock.current=false;if(alive.current)setBusy(false);}}
  function toggle(){if(running){pause();return;}action(async()=>{await audio.current.unlock();const next=await api('/api/farm/start',{method:'POST',body:'{}'});if(alive.current){setFarm(next);setRunning(true);setMessage('Deine Farm läuft. Jeder Ruf bringt Farm-Coins.');}});}
  function buy(item){action(async()=>{
    const voiceId=animal?.voice_id||farm.voices[0]?.id||null,signature=JSON.stringify([item.id,voiceId]);
    if(!requests.current.has(signature))requests.current.set(signature,requestId());
    const next=await api('/api/farm/buy',{method:'POST',body:JSON.stringify({species:item.id,voice_id:voiceId,request_id:requests.current.get(signature)})});
    requests.current.delete(signature);if(alive.current){setFarm(next);setSelected(next.bought_id);setMessage(`${item.name} eingezogen! Du kannst ihm jetzt eine eigene Stimme geben.`);}
  });}
  async function saveVoice(blob,params){const next=await api(`/api/farm/voices?${new URLSearchParams({...params,all_species:String(params.all_species)})}`,{method:'POST',headers:{'Content-Type':'audio/wav'},body:blob});if(alive.current){setFarm(next);setMessage('Stimme gespeichert. Dein Tier ist bereit für seinen Auftritt.');}audio.current.load(next.saved_voice_id).catch(()=>{});}
  function changeAnimal(){action(async()=>{const next=await api(`/api/farm/animals/${animal.id}`,{method:'PATCH',body:JSON.stringify({name:editName.trim()||species.name,voice_id:editVoice||null,all_species:editAll})});if(alive.current){setFarm(next);setMessage('Name und Stimme gespeichert.');}});}
  function deleteVoice(id){action(async()=>{audio.current.stop();const next=await api(`/api/farm/voices/${id}`,{method:'DELETE'});audio.current.buffers.delete(id);if(alive.current){setFarm(next);setMessage('Aufnahme gelöscht. Betroffene Tiere warten auf eine neue Stimme.');}});}
  const nextSheep=farm.catalog[0],progress=Math.min(100,farm.coins/nextSheep.price*100),canStart=farm.animals.some(entry=>entry.voice_id);
  const filtered=farm.animals.filter(entry=>entry.name.toLowerCase().includes(query.toLowerCase()));
  return <section className="farmGame" data-status={running?'play':'paused'} aria-label="Quatschfarm">
    <header className="farmHeader"><div className="farmBrand"><h2>Quatschfarm</h2><p>Deine Tiere. Deine Stimmen. Dein Chaos.</p></div>
      <dl className="farmCounters"><div><Coins size={25}/><dt>Farm-Coins</dt><dd data-testid="farm-coins">{format(farm.coins)}</dd></div><div><PawPrint size={25}/><dt>Tiere</dt><dd>{farm.animals.length} <small>/ 100</small></dd></div></dl>
      <button type="button" className="farmMute" aria-label={settings.enabled?'Farm stummschalten':'Farm-Sound einschalten'} aria-pressed={settings.enabled} onClick={()=>setSettings(current=>({...current,enabled:!current.enabled}))}>{settings.enabled?<Volume2/>:<VolumeX/>}</button>
      <button type="button" className="farmPrimary farmStart" disabled={!user||loading||Boolean(error)||busy||(!running&&!canStart)} onClick={toggle}>{running?<Pause size={19}/>:<Play size={19} fill="currentColor"/>}{running?'Farm pausieren':'Farm starten'}</button>
    </header>
    {!user&&<p className="farmNotice">Melde dich an, damit dein Bauernhof und deine Tierstimmen gespeichert bleiben. <a href="#login">Anmelden</a></p>}
    {!window.isSecureContext&&<p className="farmNotice">Für Mikrofonaufnahmen bitte <a href={`https://${location.host}${location.pathname}${location.hash}`}>die Farm sicher über HTTPS öffnen</a> und dort einmal anmelden.</p>}
    {loading&&<p className="farmNotice">Dein Bauernhof lädt …</p>}
    {error&&<p className="farmError" role="alert">{error} <button type="button" className="farmSecondary" onClick={()=>setAttempt(value=>value+1)}>Farm erneut laden</button></p>}
    {message&&<p className="farmNotice" role="status">{message}</p>}
    <div className="farmMainGrid"><div className="farmFieldPanel"><FarmScene animals={farm.animals} catalog={farm.catalog} selected={animal?.id} onSelect={setSelected} running={running} events={events}/>
      <footer className="farmFieldFooter"><span><Coins size={20}/> Jeder Ruf bringt Coins. Neue Tiere bringen mehr.</span><div><span>Nächstes Schaf <b>{format(nextSheep.price)} Coins</b></span><progress max="100" value={progress} aria-label="Fortschritt zum nächsten Schaf"/><small>{format(farm.coins)} / {format(nextSheep.price)}</small></div></footer>
    </div>
    <aside className="farmStudio"><h3><Mic size={24}/> Dein Soundstudio</h3><div className="farmSelectedAnimal"><AnimalArt index={species?.art}/><div><strong>{animal?.name}</strong><p>Bringt {species?.income} {species?.income===1?'Coin':'Coins'} alle {species?.interval} Sekunden</p><small>{voice?voice.name:'Gib deinem Tier eine Stimme.'}</small></div></div>
      {animal&&<VoiceRecorder key={animal.id} animal={animal} species={species} audio={audio.current} onBeforeRecording={pause} onSave={saveVoice} disabled={!user||loading||Boolean(error)||busy}/>} 
      <div className="farmAudioSettings"><label>Lautstärke<input type="range" min="0" max="1" step="0.05" value={settings.volume} onChange={event=>setSettings(current=>({...current,volume:Number(event.target.value)}))}/></label><label>Sounddichte<select value={settings.density} onChange={event=>setSettings(current=>({...current,density:event.target.value}))}><option value="quiet">Ruhig · bis zu 6 Stimmen</option><option value="chaos">Chaos · alle Tierstimmen</option></select></label></div>
      <p className="farmCaption">Farm-Coins gehören nur zu diesem Spiel. Deine Tiere verdienen, solange die Farm hier läuft. Beim Wechsel in einen anderen Tab pausiert sie.</p>
    </aside></div>
    <div className="farmLowerGrid"><section className="farmShop"><h3><ShoppingCart size={23}/> Neue Freunde für deine Farm</h3><div className="farmShopRail">{farm.catalog.map(item=><article key={item.id} className={item.id==='sheep'?'isSheep':''}><AnimalArt index={item.art}/><h4>{item.name}</h4><p>{item.income} {item.income===1?'Coin':'Coins'} / {item.interval} s</p><strong><Coins size={16}/>{format(item.price)}</strong><button type="button" className="farmPrimary" disabled={!user||loading||Boolean(error)||busy||farm.animals.length>=100||farm.coins<item.price} onClick={()=>buy(item)} aria-label={`${item.name} für ${item.price} Farm-Coins kaufen`}>{farm.animals.length>=100?'Weide voll':farm.coins<item.price?`Noch ${format(item.price-farm.coins)}`:'Kaufen'}</button><small>{item.owned} auf deiner Farm</small></article>)}</div><p className="farmCaption">Nach jedem Kauf wird diese Tierart 16 % teurer. Bis zu 100 Tiere wohnen auf deiner Weide.</p></section>
    <section className="farmHerd"><h3><PawPrint size={22}/> Deine Herde <small>({farm.animals.length}/100)</small></h3><label className="farmHerdSearch">Tier suchen<input value={query} onChange={event=>setQuery(event.target.value)} placeholder="Name deines Tiers"/></label><div className="farmHerdList">{filtered.map(entry=>{const kind=farm.catalog.find(item=>item.id===entry.species),clip=farm.voices.find(item=>item.id===entry.voice_id);return <button type="button" key={entry.id} className={`farmHerdRow ${entry.id===animal?.id?'isSelected':''}`} onClick={()=>setSelected(entry.id)}><AnimalArt index={kind.art}/><span><strong>{entry.name}</strong><small>{clip?clip.name:'Noch keine Stimme'}</small></span><b>{kind.income} <Coins size={13}/></b></button>;})}</div>
      {user&&<div className="farmAnimalEditor"><label>Tiername<input maxLength={40} value={editName} onChange={event=>setEditName(event.target.value)} disabled={busy}/></label><label>Gespeicherte Stimme<select value={editVoice} onChange={event=>setEditVoice(event.target.value)} disabled={busy}><option value="">Noch keine Stimme</option>{farm.voices.map(entry=><option key={entry.id} value={entry.id}>{entry.name}</option>)}</select></label><label className="farmCheck"><input type="checkbox" checked={editAll} onChange={event=>setEditAll(event.target.checked)} disabled={busy}/>Stimme für alle {species?.plural} verwenden</label><button type="button" className="farmSecondary" disabled={busy||!editName.trim()||(editName===animal?.name&&editVoice===(animal?.voice_id||'')&&!editAll)} onClick={changeAnimal}><Save size={15}/> Tier speichern</button></div>}
    </section></div>
    {user&&<section className="farmLibrary"><h3>Gespeicherte Stimmen <small>({farm.voices.length}/100)</small></h3>{!farm.voices.length&&<p>Deine erste Aufnahme wartet auf dich. Wähle dein Schaf und nimm etwas Lustiges auf.</p>}<ul>{farm.voices.map(entry=><li key={entry.id}><button type="button" className="farmSecondary" aria-label={`${entry.name} abspielen`} onClick={async()=>{try{await pause();await audio.current.play(entry.id,true);}catch(err){setMessage(err.message);}}}><Play size={15}/></button><span>{entry.name}<small>{entry.duration.toFixed(1)} Sekunden</small></span><button type="button" className="farmTextButton" aria-label={`${entry.name} löschen`} disabled={busy} onClick={()=>deleteVoice(entry.id)}><Trash2 size={17}/></button></li>)}</ul><p className="farmCaption">Deine Aufnahmen sind privat. Wenn du eine Stimme löschst, warten die Tiere, die sie verwendet haben, auf eine neue Aufnahme.</p></section>}
  </section>;
}
