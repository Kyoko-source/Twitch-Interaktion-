import { mkdirSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const directory = fileURLToPath(new URL("../frontend/public/overlays/sounds/", import.meta.url));
mkdirSync(directory, { recursive: true });
const sampleRate = 44100;

function compose(name, duration, score) {
  const samples = new Float64Array(Math.ceil(duration * sampleRate));
  let seed = 173;
  function noise() {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return seed / 2147483648 - 1;
  }
  function note(start, length, frequency, gain, voice = "bell", endFrequency = frequency) {
    let phase = 0;
    let filtered = 0;
    for (let i = 0; i < length * sampleRate; i++) {
      const index = Math.floor(start * sampleRate) + i;
      if (index >= samples.length) break;
      const t = i / sampleRate;
      const progress = t / length;
      phase += 2 * Math.PI * (frequency + (endFrequency - frequency) * progress) / sampleRate;
      let wave;
      if (voice === "noise") {
        filtered += .16 * (noise() - filtered);
        wave = filtered * Math.sin(Math.PI * progress);
      } else if (voice === "brass") {
        wave = Math.sin(phase) + .32 * Math.sin(2 * phase) + .16 * Math.sin(3 * phase);
      } else if (voice === "bass") {
        wave = Math.sin(phase) + .22 * Math.sin(2 * phase);
      } else {
        wave = Math.sin(phase) + .3 * Math.sin(phase * 2.005) * Math.exp(-4 * t) + .16 * Math.sin(phase * 3.01) * Math.exp(-6 * t);
      }
      const envelope = Math.min(1, t / .012) * Math.min(1, (length - t) / .09)
        * (voice === "brass" ? Math.exp(-1.8 * progress) : Math.exp(-4 * progress));
      samples[index] += wave * envelope * gain;
    }
  }
  score(note);
  // Short reflections add space without relying on a browser-specific audio engine.
  for (let i = samples.length - 1; i >= 0; i--) {
    if (i > .13 * sampleRate) samples[i] += .18 * samples[i - Math.floor(.13 * sampleRate)];
    if (i > .23 * sampleRate) samples[i] += .1 * samples[i - Math.floor(.23 * sampleRate)];
  }
  const peak = samples.reduce((maximum, value) => Math.max(maximum, Math.abs(value)), 0);
  const buffer = Buffer.alloc(44 + samples.length * 2);
  buffer.write("RIFF", 0); buffer.writeUInt32LE(buffer.length - 8, 4); buffer.write("WAVEfmt ", 8);
  buffer.writeUInt32LE(16, 16); buffer.writeUInt16LE(1, 20); buffer.writeUInt16LE(1, 22);
  buffer.writeUInt32LE(sampleRate, 24); buffer.writeUInt32LE(sampleRate * 2, 28);
  buffer.writeUInt16LE(2, 32); buffer.writeUInt16LE(16, 34); buffer.write("data", 36);
  buffer.writeUInt32LE(samples.length * 2, 40);
  samples.forEach((value, index) => buffer.writeInt16LE(Math.round(value / peak * .82 * 32767), 44 + index * 2));
  writeFileSync(`${directory}${name}.wav`, buffer);
  console.log(`${name}: ${duration}s, ${buffer.length} bytes`);
}

compose("breaking", 3.8, (note) => {
  note(0, .7, 105, .8, "bass", 36);
  note(0, .5, 0, .9, "noise");
  [0, .26, .52].forEach((start) => {
    [196, 246.94, 293.66].forEach((frequency) => note(start, .28, frequency, .2, "brass"));
  });
  [261.63, 329.63, 392, 523.25].forEach((frequency) => note(.92, 1.5, frequency, .18, "brass"));
  note(.92, 1.5, 65.41, .5, "bass");
  note(.65, .45, 0, 1.2, "noise");
  note(1.05, 2.5, 1046.5, .16);
});
compose("normal", 2.4, (note) => {
  [523.25, 659.25, 783.99, 1046.5].forEach((frequency, index) => note(.12 + index * .14, 1.6, frequency, .27));
  note(0, .55, 0, .5, "noise");
  note(.4, 1.4, 130.81, .35, "bass");
});
compose("community", 3.1, (note) => {
  [392, 493.88, 587.33, 783.99, 987.77, 1174.66].forEach((frequency, index) => note(.07 + index * .12, 1.3, frequency, .24));
  [196, 293.66, 392].forEach((frequency) => note(.8, 1.5, frequency, .13, "brass"));
  note(0, .45, 150, .35, "bass", 70);
  note(.62, .4, 0, .65, "noise");
  note(.85, 2, 1567.98, .12);
});
