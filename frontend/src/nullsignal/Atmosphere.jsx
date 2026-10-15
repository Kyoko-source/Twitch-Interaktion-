import React,{useEffect,useRef,useState} from 'react';
import {Flashlight,LightbulbOff} from 'lucide-react';

export function Atmosphere({read,sound,flashlight,onFlashlight,horrorEnabled}){
  const [state,setState]=useState(()=>read()),lastOutage=useRef(null);
  useEffect(()=>{
    const update=()=>{
      const next=read();setState(next);
      if(next.blackout&&lastOutage.current!==next.outage){lastOutage.current=next.outage;sound.play('outage');}
      if(!next.blackout)lastOutage.current=null;
    };
    update();const timer=setInterval(update,80);return()=>clearInterval(timer);
  },[read,sound,horrorEnabled]);
  return <>
    <div className="nsAtmosphere" aria-hidden="true" data-blackout={state.blackout} data-hallucination={horrorEnabled?state.hallucination.toFixed(3):'0.000'} style={{'--ns-hallucination':horrorEnabled?state.hallucination:0}}>
      {horrorEnabled&&state.hallucination>0&&<div className="nsInterference"/>}
    </div>
    <div className={`nsPowerPanel ${state.blackout?'isBlackout':''}`}>
      <span>{state.blackout?<LightbulbOff size={17}/>:<Flashlight size={17}/>}<strong>{state.blackout?'NOTSTROM':'Taschenlampe'}</strong>{state.blackout&&<small>Licht mit Maus / Finger führen</small>}</span>
      <button className="nsSecondary" type="button" aria-label="Taschenlampe" aria-pressed={flashlight} onClick={onFlashlight}><Flashlight size={17}/>{flashlight?'An':'Aus'}<kbd>F</kbd></button>
    </div>
  </>;
}
