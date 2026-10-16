// Original, non-musical room textures. No oscillators, notes or imported recordings.
import {writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const rate=22050,length=rate*12;
function render(name,lowPower){
  let seed=lowPower?1687:7163,air=0,room=0,drip=0;
  const noise=()=>{seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;return (seed>>>0)/2147483648-1;};
  const values=new Float32Array(length);
  for(let i=0;i<length;i++){
    const white=noise();air+=.38*(white-air);room+=.018*(white-room);
    if(noise()>.9995)drip=.045+Math.abs(noise())*.035;
    drip*=.997;
    values[i]=(lowPower?.14:.22)*air+(lowPower?.18:.8)*room+drip*noise();
  }
  // Crossfade the loop seam using identical start/end material, without silence.
  const overlap=rate/2;
  for(let i=0;i<overlap;i++){const t=i/overlap;values[length-overlap+i]=values[length-overlap+i]*(1-t)+values[i]*t;}
  const samples=values.subarray(overlap),wav=Buffer.alloc(44+samples.length*2);
  wav.write('RIFF',0);wav.writeUInt32LE(wav.length-8,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(rate,24);wav.writeUInt32LE(rate*2,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(samples.length*2,40);
  let peak=0,sum=0;for(let i=0;i<samples.length;i++){const v=samples[i];peak=Math.max(peak,Math.abs(v));sum+=v*v;wav.writeInt16LE(Math.round(Math.max(-1,Math.min(1,v))*32767),44+i*2);}
  if(peak>=.9)throw new Error('Ambient clipping');
  writeFileSync(fileURLToPath(new URL(`../public/audio/${name}.wav`,import.meta.url)),wav);
  console.log(name,{seconds:samples.length/rate,peak:peak.toFixed(3),rms:Math.sqrt(sum/samples.length).toFixed(3)});
}
render('nullsignal-workshop',false);render('nullsignal-low-power',true);
