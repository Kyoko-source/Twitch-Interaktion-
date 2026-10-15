import {SampleAudio} from '../audio/SampleAudio.js';

// Seconds between finite, recorded beeps. Mistakes multiply every time tier.
export function countdownInterval(remaining,strikes=0){
  if(!Number.isFinite(remaining)||remaining<=0)return Infinity;
  const base=remaining>60?1:remaining>30?.5:.08+.24*Math.pow(remaining/30,1.35);
  return Math.max(.05,base*Math.pow(.7,Math.max(0,Math.min(2,strikes))));
}

export class NullsignalAudio {
  constructor(){
    this.enabled=true;this.volume=.6;this.musicEnabled=true;this.musicVolume=.25;
    this.mode=null;this.tracks=new Map();this.pending=new Set();this.failed=new Set();
    this.unlocked=false;this.disposed=false;this.alarm=null;this.nextBeep=0;
  }
  async unlock(){
    if(this.disposed)return false;
    if(!this.context){
      const Context=window.AudioContext||window.webkitAudioContext;if(!Context)return false;
      this.context=new Context();
      this.audio=new SampleAudio(this.context,{click:'/audio/impactMetal_light_001.ogg',beep:'/audio/nullsignal-beep.wav',good:'/audio/forceField_003.ogg',bad:'/audio/impactBell_heavy_000.ogg',explode:'/audio/explosionCrunch_000.ogg',win:'/audio/forceField_000.ogg',outage:'/audio/impactMetal_heavy_000.ogg'});
      this.audio.volume(this.enabled?this.volume:0);this.audio.preload();
      this.audio.load('beep').then(buffer=>{this.beepReady=Boolean(buffer);});
    }
    // Start HTML media in the actual user gesture, including on mobile Safari.
    this.unlocked=true;this.syncMusic();
    if(this.context.state==='suspended')await this.context.resume();
    if(this.disposed)return false;
    this.syncAlarm();return this.context.state==='running';
  }
  settings(enabled,volume,musicEnabled,musicVolume){
    this.enabled=enabled;this.volume=volume;this.musicEnabled=musicEnabled;this.musicVolume=musicVolume;
    this.audio?.volume(enabled?volume:0);if(!enabled)this.audio?.stop();
    this.syncMusic();this.syncAlarm();
  }
  mission({role,status,roundId,remaining,strikes=0}){
    if(status==='paused'||status==='lobby'||status==='closed')this.audio?.stop();
    if(roundId!==this.roundId){const ingame=this.tracks.get('ingame');if(ingame)ingame.currentTime=0;}
    if(roundId!==this.roundId||status!==this.status)this.nextBeep=0;
    this.roundId=roundId;this.status=status;this.remaining=remaining;this.strikes=strikes;
    this.host=role==='host';this.mode=this.host?(!status||status==='lobby'||status==='closed'?'menu':status==='running'?'ingame':null):null;
    this.syncMusic();this.syncAlarm();
  }
  musicAllowed(){return !this.disposed&&this.unlocked&&this.enabled&&this.musicEnabled&&this.musicVolume>0;}
  syncMusic(){
    const target=this.musicAllowed()?this.mode:null;
    for(const [mode,track] of this.tracks){track.volume=this.enabled&&this.musicEnabled?this.musicVolume:0;if(mode!==target)track.pause();}
    if(!target||this.failed.has(target))return;
    let track=this.tracks.get(target);
    if(!track){track=new Audio(`/music/nullsignal/${target}.mp3`);track.loop=true;track.preload='none';track.volume=this.musicVolume;this.tracks.set(target,track);}
    if(!track.paused||this.pending.has(target))return;
    this.pending.add(target);
    track.play().then(()=>{if(!this.musicAllowed()||this.mode!==target)track.pause();}).catch(error=>{
      // Missing optional MP3s remain silent; blocked playback can retry on a gesture.
      if(error.name!=='NotAllowedError'&&error.name!=='AbortError')this.failed.add(target);
    }).finally(()=>this.pending.delete(target));
  }
  alarmAllowed(){return !this.disposed&&this.host&&this.status==='running'&&this.enabled&&this.volume>0&&this.context?.state==='running';}
  syncAlarm(){
    if(!this.alarmAllowed()){clearTimeout(this.alarm);this.alarm=null;return;}
    if(this.alarm===null)this.pump();
  }
  pump(){
    if(!this.alarmAllowed()){this.alarm=null;return;}
    const remaining=this.remaining?.()??0,interval=countdownInterval(remaining,this.strikes),now=performance.now()/1000;
    if(this.beepReady&&Number.isFinite(interval)){
      // A penalty immediately shortens the next interval. Never replay missed beats.
      if(this.lastBeep!==undefined)this.nextBeep=Math.min(this.nextBeep,this.lastBeep+interval);
      if(now>=this.nextBeep){this.audio.play('beep',{gain:.23,rate:1+this.strikes*.1+(remaining<30?(1-remaining/30)*.2:0),gap:.025});this.lastBeep=now;this.nextBeep=now+interval;}
    }
    this.alarm=setTimeout(()=>{this.alarm=null;this.pump();},20);
  }
  play(kind){
    if(!this.enabled||!this.audio||this.disposed)return;
    if(kind==='calm')this.audio.stop();
    if(kind==='outage'){if(this.host&&this.status==='running')this.audio.play('outage',{gain:.4,rate:.5,gap:1});return;}
    const name=({neutral:'click',good:'good',calm:'good',bad:'bad',defused:'win',exploded:'explode'})[kind]||kind;
    this.audio.play(name,{gain:name==='click'?.18:name==='explode'?.6:.35,gap:.04});
  }
  dispose(){
    this.disposed=true;clearTimeout(this.alarm);this.alarm=null;
    for(const track of this.tracks.values()){track.pause();track.removeAttribute('src');track.load();}
    this.tracks.clear();this.audio?.dispose();this.context?.close().catch(()=>{});
  }
}
