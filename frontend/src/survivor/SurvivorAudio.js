const mixes = new WeakMap();

function mix(context) {
  if (mixes.has(context)) return mixes.get(context);
  const limiter = context.createDynamicsCompressor();
  limiter.threshold.value = -16; limiter.knee.value = 14; limiter.ratio.value = 8;
  limiter.attack.value = 0.005; limiter.release.value = 0.16;
  limiter.connect(context.destination);
  const buffer = context.createBuffer(1, Math.ceil(context.sampleRate * 0.6), context.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
  const result = { limiter, buffer, last: new Map() }; mixes.set(context, result); return result;
}

function tone(context, out, frequency, end, duration, volume, type = "sine", delay = 0) {
  const start = context.currentTime + delay, oscillator = context.createOscillator(), gain = context.createGain();
  oscillator.type = type; oscillator.frequency.setValueAtTime(frequency, start);
  oscillator.frequency.exponentialRampToValueAtTime(Math.max(25, end), start + duration);
  gain.gain.setValueAtTime(0.0001, start); gain.gain.exponentialRampToValueAtTime(Math.max(0.0001, volume), start + 0.008);
  gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
  oscillator.connect(gain); gain.connect(out); oscillator.start(start); oscillator.stop(start + duration + 0.015);
  oscillator.onended = () => { oscillator.disconnect(); gain.disconnect(); };
}

export function survivorNoise(context, duration, volume, frequency = 700) {
  if (!context || context.state !== "running" || volume <= 0) return;
  const { limiter, buffer } = mix(context), source = context.createBufferSource(), gain = context.createGain(), filter = context.createBiquadFilter();
  source.buffer = buffer; filter.type = "bandpass"; filter.frequency.value = frequency; filter.Q.value = 0.65;
  const now = context.currentTime; gain.gain.setValueAtTime(volume, now); gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);
  source.connect(filter).connect(gain).connect(limiter); source.start(now); source.stop(now + Math.min(duration, 0.6));
  source.onended = () => { source.disconnect(); filter.disconnect(); gain.disconnect(); };
}

export function survivorSound(context, type, volume) {
  if (!context || context.state !== "running" || volume <= 0) return;
  const { limiter, last } = mix(context), now = context.currentTime;
  const gap = ["shot", "kill", "pepple"].includes(type) ? 0.065 : 0.04;
  if (now - (last.get(type) ?? -Infinity) < gap) return;
  last.set(type, now);
  const play = (f, end, time, gain, wave = "sine", delay = 0) => tone(context, limiter, f, end, time, gain * volume, wave, delay);
  if (type === "rail" || type === "laser") {
    play(type === "rail" ? 1900 : 1400, 160, 0.3, 0.07, "sawtooth");
    play(110, 42, 0.22, 0.13, "sine"); survivorNoise(context, 0.1, 0.04 * volume, 2600);
  } else if (["bomb", "explosion", "nova", "thunder"].includes(type)) {
    play(type === "thunder" ? 340 : 110, 32, 0.38, 0.14, "triangle");
    survivorNoise(context, type === "thunder" ? 0.18 : 0.4, 0.13 * volume, type === "thunder" ? 2600 : 380);
    if (type === "nova") [330, 440, 660].forEach((f, i) => play(f, f * 0.6, 0.4, 0.035, "sine", i * 0.035));
  } else if (type === "comet") {
    play(220, 80, 0.22, 0.07, "triangle"); survivorNoise(context, 0.22, 0.06 * volume, 1300);
  } else if (type === "hit") {
    play(130, 45, 0.16, 0.09, "triangle"); survivorNoise(context, 0.1, 0.06 * volume, 700);
  } else if (type === "heal" || type === "start" || type === "level") {
    [523, 659, 784, 1047].forEach((f, i) => play(f, f * 1.015, 0.25, 0.04, "sine", i * 0.055));
  } else if (type === "freeze") {
    [1480, 1760].forEach((f, i) => play(f, f * 0.8, 0.18, 0.03, "sine", i * 0.035));
  } else {
    play(type === "pepple" ? 880 : type === "kill" ? 440 : 620, type === "pepple" ? 1320 : 260, 0.1, 0.035, "triangle");
  }
}
