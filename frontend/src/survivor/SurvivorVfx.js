export function drawBeamVfx(ctx, beam, frame, reducedMotion) {
  const alpha = Math.max(0, beam.life / beam.ttl), width = beam.width || 6;
  const dx=beam.x2-beam.x1, dy=beam.y2-beam.y1, length=Math.hypot(dx,dy), angle=Math.atan2(dy,dx);
  const thunder=beam.color==='#ffe66d', color=beam.color || '#69e7f8';
  ctx.save(); ctx.translate(beam.x1,beam.y1); ctx.rotate(angle); ctx.globalCompositeOperation='lighter'; ctx.lineCap='round';
  const line=(size,paint,opacity,jagged=false)=>{
    ctx.globalAlpha=alpha*opacity; ctx.lineWidth=size; ctx.strokeStyle=paint; ctx.beginPath(); ctx.moveTo(0,0);
    if(jagged) for(let i=1;i<15;i++) ctx.lineTo(length*i/15,Math.sin(frame*.7+i*11)*width*1.6);
    ctx.lineTo(length,0); ctx.stroke();
  };
  line(width*5,color,.08); line(width*2.2,color,.25); line(width,color,.9,thunder); line(Math.max(2,width*.23),'#fff',1,thunder);
  for(const x of [0,length]) {
    const radius=width*(x?3:2.4), glow=ctx.createRadialGradient(x,0,1,x,0,radius);
    glow.addColorStop(0,'#fff'); glow.addColorStop(.25,color); glow.addColorStop(1,'transparent');
    ctx.globalAlpha=alpha; ctx.fillStyle=glow; ctx.fillRect(x-radius,-radius,radius*2,radius*2);
  }
  if(!reducedMotion) {
    for(let i=0;i<8;i++) { const t=((frame*.026+i*.137)%1),x=length*t; ctx.globalAlpha=alpha*(1-t)*.7;
      ctx.strokeStyle=color;ctx.lineWidth=1.5;ctx.beginPath();ctx.moveTo(x,width*2);ctx.lineTo(x-width*2,width*4);ctx.stroke(); }
    for(let i=0;i<7;i++){ const a=i*Math.PI*2/7+frame*.03,r=width*(2+(1-alpha)*6);ctx.globalAlpha=alpha;
      ctx.strokeStyle=color;ctx.beginPath();ctx.moveTo(length+Math.cos(a)*r,Math.sin(a)*r);ctx.lineTo(length+Math.cos(a)*r*1.8,Math.sin(a)*r*1.8);ctx.stroke(); }
  }
  ctx.restore();
}

export function drawProjectileTrail(ctx, shot, frame, reducedMotion) {
  const comet=shot.type==='comet', color=comet?'#ff8d42':shot.type==='drone'?'#78eaff':'#c88cff';
  const speed=Math.max(1,Math.hypot(shot.vx,shot.vy)),angle=Math.atan2(shot.vy,shot.vx);
  ctx.save();ctx.translate(shot.x,shot.y);ctx.rotate(angle);ctx.globalCompositeOperation='lighter';
  const length=comet?90:speed*5,gradient=ctx.createLinearGradient(-length,0,0,0);
  gradient.addColorStop(0,'transparent');gradient.addColorStop(.65,color);gradient.addColorStop(1,'#fff');ctx.fillStyle=gradient;
  ctx.globalAlpha=.85;ctx.beginPath();ctx.moveTo(6,0);ctx.lineTo(-length,comet?-3:-1);ctx.lineTo(-14,comet?10:4);ctx.closePath();ctx.fill();
  if(comet&&!reducedMotion) for(let i=0;i<5;i++){const t=(frame*.09+i*.2)%1;ctx.globalAlpha=(1-t)*.7;ctx.fillStyle='#ffcf8a';ctx.beginPath();ctx.arc(-t*length,Math.sin(i*7+frame)*7,3*(1-t),0,Math.PI*2);ctx.fill();}
  ctx.restore();
}
