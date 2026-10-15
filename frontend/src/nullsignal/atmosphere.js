const clamp=value=>Math.max(0,Math.min(1,value));

// Read the authoritative active-play clock, interpolating between room polls.
export function atmosphereVisuals({played=0,untreated=0,outage_start=40,remaining=180,running=false,calm=0}={}){
  if(!running||remaining<=0)return {blackout:false,outage:0,hallucination:0};
  const phase=played-outage_start,outage=Math.floor(Math.max(0,phase)/75);
  const blackout=phase>=0&&phase%75<12;
  const hallucination=calm>0?0:clamp((untreated-50)/45)*clamp((120-remaining)/60);
  return {blackout,outage,hallucination};
}
