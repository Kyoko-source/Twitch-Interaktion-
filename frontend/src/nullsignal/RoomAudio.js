// A separate, controllable non-musical ambience bus; all media is finite WAV/OGG.
export class RoomAudio{
  constructor(context,samples){this.context=context;this.samples=samples;this.generation=0;this.mode=null;this.voices=new Set();this.gain=context.createGain();this.gain.gain.value=0;this.gain.connect(samples.master);}
  sync({allowed,volume,blackout=false}){
    const level=allowed?volume:0;if(level!==this.level){this.level=level;this.gain.gain.setTargetAtTime(level,this.context.currentTime,.12);}
    const mode=allowed?(blackout?'roomLow':'room'):null;
    if(mode===this.mode)return;
    this.mode=mode;const generation=++this.generation;
    for(const voice of this.voices){voice.level.gain.setTargetAtTime(0,this.context.currentTime,.04);try{voice.source.stop(this.context.currentTime+.22);}catch{}}
    clearTimeout(this.timer);
    if(!mode)return;
    this.samples.load(mode).then(buffer=>{
      if(!buffer||generation!==this.generation||this.context.state!=='running')return;
      const source=this.context.createBufferSource(),level=this.context.createGain(),voice={source,level};source.buffer=buffer;source.loop=true;level.gain.value=0;source.connect(level).connect(this.gain);this.voices.add(voice);source.onended=()=>{this.voices.delete(voice);source.disconnect();level.disconnect();};source.start();level.gain.setTargetAtTime(1,this.context.currentTime,.08);
    });
    const mechanical=()=>{
      if(generation!==this.generation||!this.mode)return;
      if(!blackout)this.samples.play('mechanical',{gain:this.level*.06,rate:.7+Math.random()*.35,gap:3});
      this.timer=setTimeout(mechanical,6000+Math.random()*11000);
    };
    this.timer=setTimeout(mechanical,4000+Math.random()*3000);
  }
  dispose(){this.sync({allowed:false,volume:0});this.gain.disconnect();}
}
