import React,{useEffect,useRef,useState} from 'react';
import {Eye,Flashlight,LightbulbOff} from 'lucide-react';

const PHANTOM_SRC='/assets/nullsignal/apparition-v2.png';

// Original generated character cutout, shared by sightings and the close-up.
function Phantom(){
  return <img src={PHANTOM_SRC} alt="" width="1024" height="1536" draggable="false" decoding="async"/>;
}

export function Atmosphere({read,sound,flashlight,onFlashlight,horrorEnabled,lookingRoom,onLookRoom}){
  const [state,setState]=useState(()=>read()),seen=useRef(new Set()),lastOutage=useRef(null);
  useEffect(()=>{
    // Decode early in the round so the brief scare never waits for its image.
    if(!horrorEnabled)return;
    const image=new Image();image.src=PHANTOM_SRC;image.decode().catch(()=>{});
  },[horrorEnabled]);
  useEffect(()=>{
    const update=()=>{
      const next=read();setState(next);
      if(next.blackout&&lastOutage.current!==next.outage){lastOutage.current=next.outage;sound.play('outage');}
      if(!next.blackout)lastOutage.current=null;
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
      {horrorEnabled&&state.scare&&<div className="nsJumpscare" key={state.scareId}><Phantom/><span>REISS DICH ZUSAMMEN</span></div>}
    </div>
    <div className={`nsPowerPanel ${state.blackout?'isBlackout':''}`}>
      <span>{state.blackout?<LightbulbOff size={17}/>:<Flashlight size={17}/>}<strong>{state.blackout?'NOTSTROM':'Taschenlampe'}</strong>{(state.blackout||lookingRoom)&&<small>{lookingRoom?'Gestalt kurz anleuchten':'Licht mit Maus / Finger führen'}</small>}</span>
      <button className="nsSecondary" type="button" aria-label="Taschenlampe" aria-pressed={flashlight} onClick={onFlashlight}><Flashlight size={17}/>{flashlight?'An':'Aus'}<kbd>F</kbd></button>
      <button className="nsSecondary nsRoomLook" type="button" aria-label="Raum ansehen" aria-pressed={lookingRoom} onClick={onLookRoom}><Eye size={17}/><span>{lookingRoom?'Zur Bombe':'Raum ansehen'}</span><kbd>R</kbd></button>
    </div>
  </>;
}
