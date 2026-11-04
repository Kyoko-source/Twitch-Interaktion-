import React,{useEffect,useRef,useState} from 'react';
import {createPortal} from 'react-dom';
import {ArrowLeft,Download,Maximize,Monitor,Play} from 'lucide-react';
import './nachtwache.css';

function GameWindow({onClose}){
  const root=useRef(null);
  useEffect(()=>{
    const app=document.querySelector('.communityApp'),wasInert=app?.inert,overflow=document.body.style.overflow;
    if(app)app.inert=true;document.body.style.overflow='hidden';
    return()=>{if(app)app.inert=wasInert;document.body.style.overflow=overflow;};
  },[]);
  return createPortal(<section className="nightGameWindow" ref={root} aria-label="After Play spielen"><header><button type="button" onClick={onClose}><ArrowLeft size={17}/>Zurück zur Webseite</button><span>After Play · Kinderparadies</span><button type="button" aria-label="Spiel im Vollbild öffnen" onClick={()=>root.current?.requestFullscreen?.().catch(()=>{})}><Maximize size={17}/></button></header><div className="nightGameStage"><iframe title="After Play – eigenständiges 3D-Spiel" src="/standalone/kinderparadies/index.html" allow="autoplay; fullscreen"/></div></section>,document.body);
}

export function AfterPlay(){
  const trailer=useRef(null);
  const [playing,setPlaying]=useState(false),[touch]=useState(()=>matchMedia('(pointer: coarse)').matches&&!matchMedia('(any-pointer: fine)').matches);
  return <section className="nightLaunch" aria-labelledby="night-title"><div className="nightLaunchCopy"><h2 id="night-title">After Play</h2><p className="nightSubtitle">Kinderparadies</p><p className="nightLead">Dreizehn Rundgänge.<br/>Keine zweite Sicherheit.</p><p>Nachts gehört das Spieleparadies dir. Kontrolliere Empfang, Bällebad, Party Raum, Wartungsgang, Küche und Kino. Präge dir jedes Detail ein – etwas könnte sich verändert haben.</p><div className="nightRules"><p><i className="nightGreen"/>Alles normal? <strong>Grüne Tür.</strong></p><p><i className="nightRed"/>Etwas stimmt nicht? <strong>Rote Tür.</strong></p><p><strong>13 richtige Entscheidungen in Folge.</strong> Eine falsche Tür beendet die Schicht.</p></div><div className="nightLaunchActions"><a href="/downloads/after-play-windows-v3.9.2.zip" download><Download size={19}/>Für Windows herunterladen</a><button type="button" disabled={touch} onClick={()=>{trailer.current?.pause();setPlaying(true);}}><Play size={19}/>Im Web spielen</button></div><p className="nightSystem"><Monitor size={16}/>Windows 64 Bit · hochwertige PC-Grafik · offline spielbar</p>{touch&&<p className="nightTouchNotice">Die Web-Version benötigt Maus und Tastatur. Den Windows-Download kannst du am PC öffnen.</p>}<details><summary>Steuerung und Spielablauf</summary><p>WASD oder Pfeiltasten: bewegen. Maus: umsehen. Umschalt: rennen. Leertaste: springen. C halten: ducken und krabbeln. E: interagieren. F: Taschenlampe. G: Gegenstände aufheben oder loslassen; linke Maustaste: werfen. TAB: Inventar. ESC: Pause. F11: Vollbild.</p><p>Präge dir beim ersten Rundgang die Räume ein. Alles normal? Grüne Tür. Eine Anomalie entdeckt? Rote Tür. Dreizehn richtige Entscheidungen in Folge beenden die Nachtschicht. Geräusche und selbst verschobene Gegenstände zählen nicht als Anomalien. Deutsch und Englisch sowie Untertitel findest du in den Einstellungen.</p></details></div><div className="nightLaunchArt"><video ref={trailer} controls playsInline preload="none" poster="/assets/after-play/windows-v3.8.0.png" aria-label="After Play – offizieller Trailer"><source src="/downloads/after-play-trailer-1080p.mp4?v=3.8.0" type="video/mp4"/></video><p>Offizieller Trailer · 75 Sekunden · Windows-Spielszenen</p></div>{playing&&<GameWindow onClose={()=>setPlaying(false)}/>}</section>;
}
