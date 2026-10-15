export function pressureVisuals({remaining,duration=540,running=false,calm=0}){
  if(!running||remaining<=0)return {intensity:0,blur:0,period:2.4};
  const progress=Math.max(0,Math.min(1,1-remaining/Math.max(1,duration)));
  const intensity=Math.pow(progress,2.2);
  const blur=calm>0?0:2.4*Math.pow(Math.max(0,Math.min(1,1-remaining/120)),1.4);
  return {intensity,blur,period:2.4-1.55*intensity};
}
