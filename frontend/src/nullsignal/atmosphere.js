const clamp=value=>Math.max(0,Math.min(1,value));

// Read the authoritative active-play clock, interpolating between room polls.
export function atmosphereVisuals({played=0,untreated=0,outage_start=40,scare_id=null,scare_remaining=0,remaining=180,running=false,calm=0}={}){
  if(!running||remaining<=0)return {blackout:false,outage:0,hallucination:0,visitor:null,scare:false,scareId:null};
  const phase=played-outage_start,outage=Math.floor(Math.max(0,phase)/75);
  const blackout=phase>=0&&phase%75<12;
  const hallucination=calm>0?0:clamp((untreated-50)/45)*clamp((120-remaining)/60);
  // Sparse room sightings with quiet gaps; never counterfeit puzzle information.
  const visitPhase=played-(outage_start+18),cycle=Math.floor(visitPhase/32),age=visitPhase-cycle*32;
  const visitor=calm<=0&&untreated>=35&&visitPhase>=0&&age<12&&scare_remaining<=0?{cycle,stage:Math.min(2,cycle),age}:null;
  return {blackout,outage,hallucination,visitor,scare:calm<=0&&scare_remaining>0,scareId:scare_id};
}
