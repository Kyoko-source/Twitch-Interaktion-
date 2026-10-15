import { SampleAudio } from '../audio/SampleAudio';
export class AudioManager {
  constructor(enabledRef) { this.enabledRef = enabledRef; this.ctx = null; this.samples = null; }
  ensure() {
    if (!this.enabledRef.current) return null;
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtx) return null;
    try {
      if (!this.ctx) {
        this.ctx = new AudioCtx();
        const files = { flipper:'impactWood_medium_000', flipperDown:'impactGeneric_light_000', plunger:'impactMetal_light_001',
          bumper:'impactBell_heavy_000', sling:'impactMetal_light_000', target:'impactMetal_light_001', combo:'forceField_000',
          jackpot:'forceField_003', drain:'impactMetal_heavy_000', tilt:'impactGeneric_light_000' };
        this.samples = new SampleAudio(this.ctx, Object.fromEntries(Object.entries(files).map(([key,file]) => [key,`/audio/${file}.ogg`])));
        this.samples.preload();
      }
      if (this.ctx.state === 'suspended') this.ctx.resume().catch(()=>{});
      this.samples.volume(0.5); return this.ctx;
    } catch { return null; }
  }
  play(kind, power = 1) {
    if (!this.ensure()) return;
    this.samples.play(kind, { gain:kind === 'flipper' ? 0.35 : kind === 'bumper' ? 0.3 : 0.45,
      rate:kind === 'bumper' ? 1.12 : 1, gap:kind === 'bumper' ? 0.12 : 0.07 });
  }
  setRolling() {
    // Deliberately silent rolling. Only discrete mechanical contacts make sound.
    if (!this.samples) return;
    this.samples.volume(this.enabledRef.current ? 0.5 : 0);
    if (!this.enabledRef.current) this.samples.stop();
  }
  dispose() { this.samples?.dispose(); if (this.ctx?.state !== 'closed') this.ctx?.close().catch(()=>{}); }
}
