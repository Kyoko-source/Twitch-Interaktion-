// Original finite electronic countdown sample; no runtime oscillator or music.
import {writeFileSync} from 'node:fs';
const sampleRate=44100,duration=.06,frames=Math.round(sampleRate*duration),wav=Buffer.alloc(44+frames*2);
wav.write('RIFF');wav.writeUInt32LE(wav.length-8,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(sampleRate,24);wav.writeUInt32LE(sampleRate*2,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(frames*2,40);
for(let frame=0;frame<frames;frame++){
  const time=frame/sampleRate,envelope=Math.min(1,time/.003,(duration-time)/.012);
  const wave=.72*Math.sin(2*Math.PI*1600*time)+.14*Math.sin(2*Math.PI*2400*time);
  wav.writeInt16LE(Math.round(wave*envelope*26000),44+frame*2);
}
writeFileSync(new URL('../public/audio/nullsignal-beep.wav',import.meta.url),wav);
