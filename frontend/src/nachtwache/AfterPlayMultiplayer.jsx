import React,{useCallback,useEffect,useMemo,useRef,useState} from 'react';
import {Eye,LogIn,Shuffle,Trash2,Play,Radio} from 'lucide-react';
import './multiplayer.css';

const API='/api/afterplay/mp/sessions';
const ROUNDS=13;
const STORE='afterplay-mp';

async function call(path,options={}){
  const response=await fetch(`${API}${path}`,options);
  const text=await response.text();let body={};
  try{body=text?JSON.parse(text):{};}catch{body={};}
  if(!response.ok)throw new Error(body.detail||`Fehler ${response.status}`);
  return body;
}

function remembered(){
  try{return JSON.parse(sessionStorage.getItem(STORE)||'null');}catch{return null;}
}

// Player 2 of the spectator multiplayer: join with the six-digit code from
// the Windows game, plan all thirteen rounds by drag and drop, then follow
// player 1 live through the security cameras.
export function AfterPlayMultiplayer(){
  const [session,setSession]=useState(remembered);
  const [code,setCode]=useState('');
  const [error,setError]=useState('');
  const [busy,setBusy]=useState(false);
  const [view,setView]=useState(null);

  const join=async event=>{
    event.preventDefault();setError('');
    const clean=code.replace(/\D/g,'');
    if(clean.length!==6){setError('Der Code hat genau sechs Ziffern.');return;}
    setBusy(true);
    try{
      const body=await call(`/${clean}/join`,{method:'POST'});
      const next={code:clean,token:body.viewer_token};
      try{sessionStorage.setItem(STORE,JSON.stringify(next));}catch{}
      setSession(next);setView(body);
    }catch(problem){setError(problem.message);}
    setBusy(false);
  };

  const leave=()=>{try{sessionStorage.removeItem(STORE);}catch{}setSession(null);setView(null);setCode('');};

  useEffect(()=>{
    if(!session)return undefined;
    let alive=true;
    const poll=async()=>{
      try{
        const body=await call(`/${session.code}/view`,{headers:{'X-Viewer-Token':session.token}});
        if(alive){setView(body);setError('');}
      }catch(problem){if(alive)setError(problem.message);}
    };
    poll();const timer=setInterval(poll,800);
    return()=>{alive=false;clearInterval(timer);};
  },[session]);

  if(!session)return <section className="mpPanel mpJoin">
    <h3><Radio size={20}/>After Play Multiplayer</h3>
    <p>Spieler 1 startet die Windows-Version und wählt im Hauptmenü <strong>Multiplayer</strong>. Dort erscheint ein sechsstelliger Code. Gib ihn hier ein: Du planst dann für alle 13 Runden, welche Anomalie passiert, und verfolgst die Schicht live über die Überwachungskameras.</p>
    <form onSubmit={join}>
      <input inputMode="numeric" autoComplete="off" maxLength={7} placeholder="000000" aria-label="Sechsstelliger Code" value={code} onChange={e=>setCode(e.target.value.replace(/[^\d ]/g,''))}/>
      <button type="submit" disabled={busy}><LogIn size={18}/>Beitreten</button>
    </form>
    {error&&<p className="mpError">{error}</p>}
  </section>;

  if(!view)return <section className="mpPanel"><p>Verbinde mit Spiel {session.code} …</p>{error&&<><p className="mpError">{error}</p><button type="button" className="mpGhost" onClick={leave}>Anderen Code eingeben</button></>}</section>;

  return view.plan?<Live session={session} view={view} error={error} onLeave={leave}/>:<Planner session={session} view={view} error={error} onLeave={leave}/>;
}

function Planner({session,view,error,onLeave}){
  const [rounds,setRounds]=useState(()=>Array(ROUNDS).fill('none'));
  const [picked,setPicked]=useState(null);
  const [filter,setFilter]=useState('');
  const [saving,setSaving]=useState(false);
  const [problem,setProblem]=useState('');
  const names=useMemo(()=>Object.fromEntries(view.catalog.map(a=>[a.id,a])),[view.catalog]);
  const zones=useMemo(()=>{
    const groups={};
    for(const anomaly of view.catalog){
      const hit=!filter||`${anomaly.name} ${anomaly.zone}`.toLowerCase().includes(filter.toLowerCase());
      if(hit)(groups[anomaly.zone||'Sonstiges']??=[]).push(anomaly);
    }
    return Object.entries(groups).sort(([a],[b])=>a.localeCompare(b,'de'));
  },[view.catalog,filter]);
  const used=new Set(rounds.filter(r=>r!=='none'));
  const place=(index,id)=>setRounds(current=>current.map((value,i)=>i===index?id:value));
  const drop=(index,event)=>{event.preventDefault();const id=event.dataTransfer.getData('text/plain');if(id)place(index,id);};
  const shuffle=()=>{
    const pool=[...view.catalog.map(a=>a.id)].sort(()=>Math.random()-.5);
    setRounds(Array.from({length:ROUNDS},(_,i)=>i===0||Math.random()<.45?'none':pool.pop()||'none'));
  };
  const save=async()=>{
    setSaving(true);setProblem('');
    try{await call(`/${session.code}/plan`,{method:'PUT',headers:{'Content-Type':'application/json','X-Viewer-Token':session.token},body:JSON.stringify({rounds})});}
    catch(e){setProblem(e.message);}
    setSaving(false);
  };
  return <section className="mpPanel mpPlanner">
    <header className="mpHead"><h3>Spiel {session.code} · Runden planen</h3><button type="button" className="mpGhost" onClick={onLeave}>Verlassen</button></header>
    <p className="mpHint">Ziehe Anomalien auf die Runden (oder tippe erst eine Anomalie und dann eine Runde an). Leere Runden sind ohne Anomalie: Spieler 1 muss dort die grüne Tür nehmen.</p>
    <div className="mpBoard">
      <div className="mpCatalog">
        <input className="mpSearch" placeholder="Anomalie oder Raum suchen …" value={filter} onChange={e=>setFilter(e.target.value)}/>
        {zones.map(([zone,items])=><div key={zone} className="mpZone"><h4>{zone}</h4>
          {items.map(a=><button type="button" key={a.id} draggable onDragStart={e=>{e.dataTransfer.setData('text/plain',a.id);e.dataTransfer.effectAllowed='copy';}}
            className={`mpCard ${picked===a.id?'mpPicked':''} ${used.has(a.id)?'mpUsed':''}`} onClick={()=>setPicked(picked===a.id?null:a.id)}>{a.name}</button>)}
        </div>)}
      </div>
      <ol className="mpRounds">
        {rounds.map((id,index)=><li key={index} onDragOver={e=>{e.preventDefault();e.dataTransfer.dropEffect='copy';}} onDrop={e=>drop(index,e)}
          onClick={()=>{if(picked){place(index,picked);setPicked(null);}}} className={id==='none'?'mpEmpty':'mpFilled'}>
          <span className="mpRoundNo">Runde {index+1}</span>
          <span className="mpRoundText">{id==='none'?'Keine Anomalie':names[id]?.name||id}</span>
          {id!=='none'&&<button type="button" aria-label="Runde leeren" onClick={e=>{e.stopPropagation();place(index,'none');}}><Trash2 size={15}/></button>}
        </li>)}
      </ol>
    </div>
    <footer className="mpActions">
      <button type="button" className="mpGhost" onClick={shuffle}><Shuffle size={16}/>Zufällig füllen</button>
      <button type="button" className="mpGhost" onClick={()=>setRounds(Array(ROUNDS).fill('none'))}>Alles leeren</button>
      <button type="button" className="mpPrimary" disabled={saving} onClick={save}><Play size={17}/>Speichern · Schicht starten</button>
    </footer>
    {(problem||error)&&<p className="mpError">{problem||error}</p>}
  </section>;
}

function Live({session,view,error,onLeave}){
  const names=useMemo(()=>Object.fromEntries(view.catalog.map(a=>[a.id,a.name])),[view.catalog]);
  const state=view.state||{};
  const round=Math.max(1,Math.min(ROUNDS,state.round||1));
  const frame=view.frame_seq?`${API}/${session.code}/frame.jpg?token=${encodeURIComponent(session.token)}&seq=${view.frame_seq}`:null;
  const events=[...(view.events||[])].reverse();
  const phase={waiting:'Wartet auf den Start',play:'Spielt',pause:'Pausiert',ending:'Abspann',death:'Erwischt',failure:'Falsche Tür',intro:'Im Aufzug'}[state.phase]||state.phase||'—';
  return <section className="mpPanel mpLive">
    <header className="mpHead"><h3><Eye size={19}/>Spiel {session.code} · Live</h3><button type="button" className="mpGhost" onClick={onLeave}>Verlassen</button></header>
    <div className="mpLiveGrid">
      <figure className="mpCamera">
        {frame?<img src={frame} alt={`Überwachungskamera ${state.camera||''}`}/>:<div className="mpNoSignal">Kein Kamerasignal</div>}
        <figcaption><span className="mpRec"/>CAM · {state.camera||state.zone||'—'}</figcaption>
      </figure>
      <aside className="mpStatus">
        <dl>
          <div><dt>Runde</dt><dd>{state.round||'—'} / 13</dd></div>
          <div><dt>Serie</dt><dd>{state.streak??0}</dd></div>
          <div><dt>Raum</dt><dd>{state.zone||'—'}</dd></div>
          <div><dt>Status</dt><dd>{phase}</dd></div>
        </dl>
        <h4>Dein Plan</h4>
        <ol className="mpPlanList">{view.plan.map((id,i)=><li key={i} className={i+1===round?'mpNow':i+1<round?'mpDone':''}><span>{i+1}</span>{id==='none'?'Keine Anomalie':names[id]||id}</li>)}</ol>
        <h4>Ereignisse</h4>
        <ul className="mpEvents">{events.map((e,i)=><li key={i}>{e.text}</li>)}</ul>
      </aside>
    </div>
    {error&&<p className="mpError">{error}</p>}
  </section>;
}
