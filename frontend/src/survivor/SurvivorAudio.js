import { SampleAudio } from '../audio/SampleAudio';
const mixers = new WeakMap();
const files = { shot:'laserSmall_000', drone:'laserSmall_002', rail:'laserLarge_001', laser:'laserLarge_000',
  bomb:'explosionCrunch_000', explosion:'explosionCrunch_000', nova:'lowFrequency_explosion_000', thunder:'explosionCrunch_000',
  comet:'thrusterFire_000', hit:'slime_000', heal:'forceField_000', start:'forceField_003', level:'forceField_003', freeze:'forceField_000', pepple:'impactBell_heavy_000' };
export function survivorMixer(context) {
  if (!context) return null;
  if (!mixers.has(context)) { const mixer = new SampleAudio(context, Object.fromEntries(Object.entries(files).map(([key,file])=>[key,`/audio/${file}.ogg`]))); mixers.set(context,mixer); mixer.preload(); }
  return mixers.get(context);
}
export function survivorSound(context, type, volume) {
  if (!context || volume <= 0) return;
  const mixer = survivorMixer(context); mixer.volume(volume * 0.7);
  mixer.play(files[type] ? type : 'shot', { gain: ['shot','drone','pepple'].includes(type) ? 0.32 : type === 'thunder' ? 0.55 : 0.85, rate:type === 'thunder' ? 1.5 : 1, gap:type === 'pepple' ? 0.16 : 0.08 });
}
export function survivorStop(context) { mixers.get(context)?.stop(); }
export function survivorVolume(context, volume) { mixers.get(context)?.volume(volume * 0.7); }
