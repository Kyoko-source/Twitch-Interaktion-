import React,{useEffect,useId,useRef,useState} from 'react';
import {Flashlight,LightbulbOff} from 'lucide-react';

// Original vector mask, shared by distant apparitions and the brief close-up.
function Phantom(){
  const id=useId();
  return <svg viewBox="0 0 400 480" aria-hidden="true" focusable="false">
    <defs><radialGradient id={id+'metal'} cx="38%" cy="28%"><stop stopColor="#667173"/><stop offset=".5" stopColor="#252d31"/><stop offset="1" stopColor="#03080b"/></radialGradient><radialGradient id={id+'eye'}><stop stopColor="#fff0cb"/><stop offset=".25" stopColor="#ff674c"/><stop offset="1" stopColor="#76090b"/></radialGradient></defs>
    <path d="M21 480 45 214 70 90 129 28 198 7 274 35 332 108 361 254 389 480Z" fill="#020609"/>
    <path d="m85 100 53-58 123 10 59 67-19 190-49 104-52 30-65-40-48-111Z" fill={`url(#${id}metal)`} stroke="#87928a" strokeWidth="2"/>
    <path d="m94 164 64-25 29 41-38 44-54-22zm117 17 35-40 62 32-10 35-60 21Z" fill="#010303" stroke="#525d57" strokeWidth="5"/>
    <path d="m107 181 44-10 21 15-29 13-36-5zm121 5 24-13 40 14-3 10-36 6Z" fill={`url(#${id}eye)`}/>
    <path d="m201 191-21 84 36 5m-84 28 66-22 70 27-20 63-52 24-43-28Z" fill="#060b0e" stroke="#7a8580" strokeWidth="3"/>
    <path d="m151 319 97 13m-94 8 90 12m-86 7 79 10m-71 4 62 9" stroke="#8d9384" strokeWidth="4"/>
    <path d="m167 46 16 55-15 38m91-85-22 70 20 17m45 102-39 11 24 15-25 39m-111 21-25 43 31 59" fill="none" stroke="#bdc4af" strokeWidth="2" opacity=".6"/>
    <path d="m53 480 38-109 53 48 55 24 58-23 55-51 41 111Z" fill="#090f13" stroke="#354044" strokeWidth="4"/>
  </svg>;
}

export function Atmosphere({read,sound,flashlight,onFlashlight,horrorEnabled}){
  const [state,setState]=useState(()=>read()),seen=useRef(new Set()),lastOutage=useRef(null),lastApparition=useRef(false);
  useEffect(()=>{
    const update=()=>{
      const next=read();setState(next);
      if(next.blackout&&lastOutage.current!==next.outage){lastOutage.current=next.outage;sound.play('outage');}
      if(!next.blackout)lastOutage.current=null;
      if(horrorEnabled&&next.apparition&&!lastApparition.current)sound.play('phantom');
      lastApparition.current=next.apparition;
      if(horrorEnabled&&next.scare&&next.scareId&&!seen.current.has(next.scareId)){
        seen.current.add(next.scareId);
        let heard=false;try{heard=sessionStorage.getItem('nullsignal-scare:'+next.scareId)==='heard';sessionStorage.setItem('nullsignal-scare:'+next.scareId,'heard');}catch{}
        if(!heard)sound.play('scare');
      }
    };
    update();const timer=setInterval(update,80);return()=>clearInterval(timer);
  },[read,sound,horrorEnabled]);
  return <>
    <div className="nsAtmosphere" aria-hidden="true" data-blackout={state.blackout} data-hallucination={horrorEnabled?state.hallucination.toFixed(3):'0.000'} data-scare={Boolean(horrorEnabled&&state.scare)} style={{'--ns-hallucination':horrorEnabled?state.hallucination:0}}>
      {horrorEnabled&&state.hallucination>0&&<div className="nsInterference"/>}
      {horrorEnabled&&state.apparition&&<div className={`nsPhantom ${state.outage%2?'isRight':''}`}><Phantom/></div>}
      {horrorEnabled&&state.scare&&<div className="nsJumpscare" key={state.scareId}><Phantom/><span>REISS DICH ZUSAMMEN</span></div>}
    </div>
    <div className={`nsPowerPanel ${state.blackout?'isBlackout':''}`}>
      <span>{state.blackout?<LightbulbOff size={17}/>:<Flashlight size={17}/>}<strong>{state.blackout?'NOTSTROM':'Taschenlampe'}</strong>{state.blackout&&<small>Licht mit Maus / Finger führen</small>}</span>
      <button className="nsSecondary" type="button" aria-label="Taschenlampe" aria-pressed={flashlight} onClick={onFlashlight}><Flashlight size={17}/>{flashlight?'An':'Aus'}<kbd>F</kbd></button>
    </div>
  </>;
}
