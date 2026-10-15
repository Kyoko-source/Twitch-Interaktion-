const clamp=value=>Math.max(0,Math.min(1,value));

// Read the authoritative active-play clock, interpolating between room polls.
export function atmosphereVisuals({played=0,untreated=0,outage_start=40,scare_id=null,scare_remaining=0,remaining=180,running=false,calm=0}={}){
  if(!running||remaining<=0)return {blackout:false,outage:0,hallucination:0,apparition:false,scare:false,scareId:null};
  const phase=played-outage_start,outage=Math.floor(Math.max(0,phase)/75);
  const blackout=phase>=0&&phase%75<12;
  const hallucination=calm>0?0:clamp((untreated-50)/45)*clamp((120-remaining)/60);
  // Sparse sightings with long quiet gaps; never counterfeit puzzle information.
  const apparition=hallucination>.12&&(played+outage_start)%19<2.6;
  return {blackout,outage,hallucination,apparition,scare:calm<=0&&scare_remaining>0,scareId:scare_id};
}
