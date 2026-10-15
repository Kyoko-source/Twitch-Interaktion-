import { api } from '../api';

export class FarmAudio {
  constructor() { this.context=null;this.buffers=new Map();this.sources=new Set();this.generation=0;this.enabled=true;this.volume=.65;this.limit=100; }
  async unlock() {
    const AudioCtx=window.AudioContext||window.webkitAudioContext;
    if(!AudioCtx) throw new Error('Dein Browser unterstützt die Audiowiedergabe nicht.');
    if(!this.context) {
      this.context=new AudioCtx();this.master=this.context.createGain();this.master.gain.value=this.volume;
      const limiter=this.context.createDynamicsCompressor();limiter.threshold.value=-14;limiter.ratio.value=10;limiter.knee.value=20;
      this.master.connect(limiter).connect(this.context.destination);
    }
    if(this.context.state==='suspended') await this.context.resume();
    return this.context;
  }
  load(id) {
    if(!this.buffers.has(id)) this.buffers.set(id,api(`/api/farm/voices/${id}`,{},'blob').then(b=>b.arrayBuffer()).then(b=>this.context.decodeAudioData(b)).catch(error=>{this.buffers.delete(id);throw error;}));
    return this.buffers.get(id);
  }
  async play(id, preview=false) {
    if(!id || (!this.enabled&&!preview)) return;
    const generation=this.generation;
    await this.unlock();
    const buffer=await this.load(id);
    if(generation!==this.generation || (!this.enabled&&!preview) || this.sources.size>=this.limit) return;
    const source=this.context.createBufferSource(), gain=this.context.createGain();source.buffer=buffer;gain.gain.value=.75;
    source.connect(gain).connect(this.master);this.sources.add(source);this.updateVolume();
    source.onended=()=>{this.sources.delete(source);source.disconnect();gain.disconnect();this.updateVolume();};source.start();
  }
  settings({enabled,volume,density}) { this.enabled=enabled;this.volume=volume;this.limit=density==='quiet'?6:100;if(!enabled)this.stop();this.updateVolume(); }
  updateVolume() { if(this.master&&this.context?.state!=='closed')this.master.gain.setTargetAtTime(this.volume/Math.sqrt(Math.max(1,this.sources.size*.4)),this.context.currentTime,.03); }
  stop() { this.generation++;this.sources.forEach(source=>{try{source.stop();}catch{}});this.sources.clear(); }
  dispose() { this.stop();this.buffers.clear();this.context?.close().catch(()=>{}); }
}

// Canonical mono PCM WAV: browser-independent playback and bounded private storage.
export async function voiceWav(context, blob) {
  const decoded=await context.decodeAudioData(await blob.arrayBuffer());
  const seconds=Math.min(4,decoded.duration);
  if(seconds<.1)throw new Error('Die Aufnahme ist zu kurz. Sprich mindestens einen kurzen Laut ein.');
  const Offline=window.OfflineAudioContext||window.webkitOfflineAudioContext;
  const offline=new Offline(1,Math.ceil(seconds*16000),16000),source=offline.createBufferSource();
  source.buffer=decoded;source.connect(offline.destination);source.start();
  const samples=(await offline.startRendering()).getChannelData(0);
  let peak=0;for(const value of samples)peak=Math.max(peak,Math.abs(value));
  if(peak<.007)throw new Error('Ich höre noch nichts. Prüfe dein Mikrofon und sprich etwas lauter.');
  let first=0,last=samples.length-1;const threshold=Math.max(.005,peak*.025);
  while(first<last&&Math.abs(samples[first])<threshold)first++;
  while(last>first&&Math.abs(samples[last])<threshold)last--;
  first=Math.max(0,first-320);last=Math.min(samples.length-1,last+640);
  const length=Math.max(1600,last-first+1),buffer=new ArrayBuffer(44+length*2),view=new DataView(buffer);
  const text=(offset,value)=>{for(let i=0;i<value.length;i++)view.setUint8(offset+i,value.charCodeAt(i));};
  text(0,'RIFF');view.setUint32(4,36+length*2,true);text(8,'WAVE');text(12,'fmt ');view.setUint32(16,16,true);
  view.setUint16(20,1,true);view.setUint16(22,1,true);view.setUint32(24,16000,true);view.setUint32(28,32000,true);
  view.setUint16(32,2,true);view.setUint16(34,16,true);text(36,'data');view.setUint32(40,length*2,true);
  const scale=Math.min(5,.75/peak);
  for(let i=0;i<length;i++){const fade=Math.min(1,i/128,(length-i-1)/128);const value=Math.max(-1,Math.min(1,(samples[first+i]||0)*scale*fade));view.setInt16(44+i*2,Math.round(value*32767),true);}
  return {blob:new Blob([buffer],{type:'audio/wav'}),duration:length/16000};
}
