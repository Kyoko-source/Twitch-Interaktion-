import React,{useEffect,useRef,useState} from 'react';

const seed=id=>{let value=Array.from(id).reduce((hash,letter)=>(hash*31+letter.charCodeAt(0))>>>0,7);value=Math.imul(value^(value>>>16),0x45d9f3b);value=Math.imul(value^(value>>>16),0x45d9f3b);return (value^(value>>>16))>>>0;};
export function FarmScene({animals,catalog,selected,onSelect,running,events}){
  const canvas=useRef(null),data=useRef({animals,catalog,selected,running,onSelect}),calls=useRef(new Map()),seen=useRef(new Set()),[attempt,setAttempt]=useState(0),[error,setError]=useState(''),[ready,setReady]=useState(false);
  data.current={animals,catalog,selected,running,onSelect};
  useEffect(()=>{for(const event of events){if(seen.current.has(event.id))continue;seen.current.add(event.id);calls.current.set(event.animal_id,{at:performance.now(),amount:event.amount});}if(seen.current.size>500)seen.current=new Set(events.map(e=>e.id));},[events]);
  useEffect(()=>{
    let alive=true,frame,loaded=0;setError('');setReady(false);
    const meadow=new Image(),sprites=new Image();let positions=[];
    const media=matchMedia('(prefers-reduced-motion: reduce)');
    const loadedImage=()=>{if(++loaded===2&&alive){setReady(true);frame=requestAnimationFrame(draw);}};
    const fail=()=>{if(alive)setError('Die Weide konnte nicht geladen werden. Bitte erneut versuchen.');};
    meadow.onload=sprites.onload=loadedImage;meadow.onerror=sprites.onerror=fail;meadow.src='/assets/farm/meadow.png';sprites.src='/assets/farm/animals.png';
    const timeout=setTimeout(()=>{if(loaded<2)fail();},20000);
    function draw(now){
      if(!alive)return;const node=canvas.current,ctx=node.getContext('2d'),state=data.current;
      const crop=Math.max(1100/meadow.naturalWidth,700/meadow.naturalHeight),width=meadow.naturalWidth*crop,height=meadow.naturalHeight*crop;
      ctx.drawImage(meadow,(1100-width)/2,(700-height)/2,width,height);
      const size=Math.max(38,108-Math.sqrt(state.animals.length)*6.7);
      positions=state.animals.map((animal,index)=>{const key=seed(animal.id),phase=key%628/100,active=state.running&&!media.matches;
        const x=index===0&&state.animals.length===1?490:180+(key%735),y=index===0&&state.animals.length===1?395:250+(Math.floor(key/800)%325);
        return {animal,x:x+(active?Math.sin(now/7000+phase)*24:0),y:y+(active?Math.cos(now/9000+phase)*15:0),phase};
      }).sort((a,b)=>a.y-b.y);
      for(const {animal,x,y,phase} of positions){
        const call=calls.current.get(animal.id),age=call?now-call.at:Infinity,calling=age<1500,species=state.catalog.find(entry=>entry.id===animal.species),index=(species?.art||0)+(calling?6:0);
        if(animal.id===state.selected){ctx.strokeStyle='#ffe295';ctx.lineWidth=3;ctx.beginPath();ctx.ellipse(x,y+size*.34,size*.39,size*.14,0,0,Math.PI*2);ctx.stroke();}
        const bob=!media.matches&&state.running?Math.sin(now/(calling?75:350)+phase)*(calling?4:1.6):0;
        const sw=sprites.naturalWidth/4,sh=sprites.naturalHeight/3;
        ctx.drawImage(sprites,(index%4)*sw+sw*.04,Math.floor(index/4)*sh+sh*.04,sw*.92,sh*.92,x-size/2,y-size/2+bob,size,size);
        if(age<1400){ctx.save();ctx.globalAlpha=1-age/1400;ctx.font='bold 24px Segoe UI,sans-serif';ctx.textAlign='center';ctx.fillStyle='#fff3b1';ctx.strokeStyle='#274525';ctx.lineWidth=4;const text=`+${call.amount}`,ty=y-size*.5-(media.matches?0:age*.03);ctx.strokeText(text,x+size*.3,ty);ctx.fillText(text,x+size*.3,ty);ctx.restore();}
      }
      if(state.animals.length===1&&!state.animals[0].voice_id){ctx.fillStyle='#fff7e5';ctx.beginPath();ctx.roundRect(490,280,195,55,12);ctx.fill();ctx.fillStyle='#243b2f';ctx.font='bold 17px Segoe UI,sans-serif';ctx.fillText('Mäh? Entscheide du.',505,313);}
      frame=requestAnimationFrame(draw);
    }
    const click=event=>{const bounds=canvas.current.getBoundingClientRect(),x=(event.clientX-bounds.left)/bounds.width*1100,y=(event.clientY-bounds.top)/bounds.height*700;
      const closest=positions.slice().sort((a,b)=>Math.hypot(a.x-x,a.y-y)-Math.hypot(b.x-x,b.y-y))[0];if(closest&&Math.hypot(closest.x-x,closest.y-y)<80)data.current.onSelect(closest.animal.id);};
    const node=canvas.current;node.addEventListener('click',click);node.__farmScene={get positions(){return positions;},meadow,sprites};
    return()=>{alive=false;clearTimeout(timeout);cancelAnimationFrame(frame);node.removeEventListener('click',click);delete node.__farmScene;};
  },[attempt]);
  return <div className="farmPasture"><canvas ref={canvas} width="1100" height="700" aria-label={`Weide mit ${animals.length} Tieren. Wähle ein Tier auf der Weide oder in deiner Herde.`}/>{!ready&&<div className="farmSceneStatus">{error?<><p>{error}</p><button type="button" className="farmPrimary" onClick={()=>setAttempt(value=>value+1)}>Weide erneut laden</button></>:<p>Deine Weide wächst …</p>}</div>}</div>;
}
