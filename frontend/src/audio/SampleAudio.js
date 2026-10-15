// One-shot audio files only. No continuously running oscillator or music loop.
export class SampleAudio {
  constructor(context, files) {
    this.context = context; this.files = files; this.buffers = new Map(); this.last = new Map(); this.voices = new Set(); this.generation = 0;
    this.master = context.createGain(); this.master.gain.value = 0.65;
    this.limiter = context.createDynamicsCompressor();
    this.limiter.threshold.value = -12; this.limiter.knee.value = 18; this.limiter.ratio.value = 8;
    this.limiter.attack.value = 0.003; this.limiter.release.value = 0.15;
    this.master.connect(this.limiter).connect(context.destination);
  }
  load(name) {
    if (!this.files[name]) return Promise.resolve(null);
    if (!this.buffers.has(name)) this.buffers.set(name, fetch(this.files[name]).then(r => {
      if (!r.ok) throw new Error(`Sound unavailable: ${name}`); return r.arrayBuffer();
    }).then(bytes => this.context.decodeAudioData(bytes)).catch(() => { this.buffers.delete(name); return null; }));
    return this.buffers.get(name);
  }
  preload() { return Promise.all(Object.keys(this.files).map(name => this.load(name))); }
  volume(value) { this.master.gain.setTargetAtTime(Math.max(0, Math.min(1, value)), this.context.currentTime, 0.015); }
  async play(name, { gain = 1, rate = 1, gap = 0.07 } = {}) {
    const now = this.context.currentTime;
    if (now - (this.last.get(name) ?? -Infinity) < gap) return;
    this.last.set(name, now);
    const generation = this.generation, buffer = await this.load(name);
    if (!buffer || generation !== this.generation || this.context.state !== 'running' || this.voices.size >= 14) return;
    const source = this.context.createBufferSource(), level = this.context.createGain();
    source.buffer = buffer; source.playbackRate.value = rate; level.gain.value = gain;
    source.connect(level).connect(this.master); this.voices.add(source);
    source.onended = () => { this.voices.delete(source); source.disconnect(); level.disconnect(); };
    source.start();
  }
  stop() { this.generation++; this.voices.forEach(source => { try { source.stop(); } catch {} }); this.voices.clear(); }
  dispose() { this.stop(); this.master.disconnect(); this.limiter.disconnect(); }
}
