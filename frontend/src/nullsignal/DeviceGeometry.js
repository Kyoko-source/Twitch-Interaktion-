import * as T from 'three';
import {RoundedBoxGeometry} from 'three/addons/geometries/RoundedBoxGeometry.js';
import {GLYPHS,COLOR_HEX} from './glyphs';

export function createDevice({steel,bomb,closed=false}) {
  const root=new T.Group(),hits=[],modules=new Map(),animated=[],textures=[];
  const materials={
    case:new T.MeshStandardMaterial({color:'#424b50',map:steel,bumpMap:steel,bumpScale:.016,metalness:.72,roughness:.54}),
    plate:new T.MeshStandardMaterial({color:'#555e62',map:steel,bumpMap:steel,bumpScale:.008,metalness:.58,roughness:.6}),
    copper:new T.MeshStandardMaterial({color:'#b37a47',map:steel,metalness:.75,roughness:.42}),
    edge:new T.MeshStandardMaterial({color:'#68767c',metalness:.8,roughness:.55}),
    black:new T.MeshStandardMaterial({color:'#10191d',roughness:.7,metalness:.22}),
    rubber:new T.MeshStandardMaterial({color:'#171d20',roughness:.9}),
    mint:new T.MeshStandardMaterial({color:'#83e5cd',emissive:'#83e5cd',emissiveIntensity:1.2,roughness:.3}),
    red:new T.MeshStandardMaterial({color:'#351f20',emissive:'#f33e35',emissiveIntensity:.05,roughness:.3}),
  };
  function box(parent,x,y,z,w,h,d,mat=materials.plate,r=.025){
    const mesh=new T.Mesh(r?new RoundedBoxGeometry(w,h,d,2,r):new T.BoxGeometry(w,h,d),mat);
    mesh.position.set(x,y,z);mesh.castShadow=true;mesh.receiveShadow=true;parent.add(mesh);return mesh;
  }
  function cylinder(parent,x,y,z,r,h,mat=materials.edge){
    const mesh=new T.Mesh(new T.CylinderGeometry(r,r,h,16),mat);mesh.rotation.x=Math.PI/2;mesh.position.set(x,y,z);mesh.castShadow=true;parent.add(mesh);return mesh;
  }
  function label(parent,x,y,z,w,h,draw,{background='#10191d',color='#dce6df',size=38}={}){
    const canvas=document.createElement('canvas');canvas.width=512;canvas.height=Math.max(96,Math.round(512*h/w));const ctx=canvas.getContext('2d');
    const texture=new T.CanvasTexture(canvas);texture.colorSpace=T.SRGBColorSpace;texture.anisotropy=4;textures.push(texture);
    const mesh=new T.Mesh(new T.PlaneGeometry(w,h),new T.MeshBasicMaterial({map:texture,transparent:true,toneMapped:false}));mesh.position.set(x,y,z);parent.add(mesh);
    const paint=(content)=>{ctx.clearRect(0,0,canvas.width,canvas.height);if(background){ctx.fillStyle=background;ctx.fillRect(0,0,canvas.width,canvas.height);}ctx.fillStyle=color;ctx.strokeStyle=color;ctx.textAlign='center';ctx.textBaseline='middle';ctx.font=`600 ${size}px "Bahnschrift", "Arial Narrow", sans-serif`;if(typeof content==='function')content(ctx,canvas.width,canvas.height);else ctx.fillText(content,canvas.width/2,canvas.height/2,canvas.width-24);texture.needsUpdate=true;};
    paint(draw);return {mesh,paint};
  }
  function screw(parent,x,y,z){
    cylinder(parent,x,y,z,.041,.028);const slot=box(parent,x,y,z+.018,.053,.009,.005,materials.black,0);slot.rotation.z=(x*y)*1.9;
  }
  function hit(mesh,id,operation=null,value=null){mesh.userData.ns={id,operation,value};hits.push(mesh);return mesh;}
  function button(parent,id,x,y,w,h,text,op,value,options={}){
    const material=new T.MeshStandardMaterial({color:options.color||'#303d42',metalness:.45,roughness:.38});
    const key=hit(box(parent,x,y,.11,w,h,.115,material,.035),id,op,value);
    const textLabel=label(parent,x,y,.172,w*.88,h*.8,text,{size:options.size||74,color:options.ink||'#e6ece5',background:null});
    key.userData.label=textLabel;return key;
  }
  function glyph(parent,x,y,id){return label(parent,x,y,.181,.36,.28,(ctx,w,h)=>{const scale=Math.min(w,h)*.008;ctx.translate(w/2,h/2);ctx.scale(scale,scale);ctx.translate(-50,-50);ctx.lineWidth=6;ctx.lineCap='round';ctx.lineJoin='round';ctx.stroke(new Path2D(GLYPHS[id]?.path||GLYPHS.cross.path));ctx.setTransform(1,0,0,1,0,0);},{background:null,color:'#e9ede2'});}
  // Beveled octagonal carrier, substantial sidewall, gasket and metal face frame.
  const shape=new T.Shape();const w=2.45,h=2.02,c=.28;
  shape.moveTo(-w+c,-h);shape.lineTo(w-c,-h);shape.lineTo(w,-h+c);shape.lineTo(w,h-c);shape.lineTo(w-c,h);shape.lineTo(-w+c,h);shape.lineTo(-w,h-c);shape.lineTo(-w,-h+c);shape.closePath();
  const shell=new T.Mesh(new T.ExtrudeGeometry(shape,{depth:.88,bevelEnabled:true,bevelSize:.055,bevelThickness:.055,bevelSegments:2,steps:1}),materials.case);shell.position.z=-.48;shell.castShadow=true;shell.receiveShadow=true;root.add(shell);
  for(const side of [-1,1]){
    box(root,0,0,side*.47,4.42,3.65,.06,materials.rubber,.06);
    for(const x of [-2.19,2.19])for(const y of [-1.76,1.76]){
      const brace=box(root,x,y,side*.53,.45,.45,.09,materials.copper,.035);brace.rotation.z=(x*y>0?1:-1)*Math.PI/4;
      screw(root,x,y,side*.595);
    }
    for(let i=0;i<12;i++)box(root,-2.35,-1.35+i*.245,0,.08,.1,.7,materials.black,.01);
  }
  // Top handle and latches are separate physical components.
  for(const x of [-.72,.72]){box(root,x,2.02,0,.22,.18,.48,materials.copper);box(root,x,2.21,0,.12,.34,.18,materials.edge);}
  const handle=new T.Mesh(new T.CylinderGeometry(.11,.11,1.45,24),materials.rubber);handle.rotation.z=Math.PI/2;handle.position.set(0,2.36,0);root.add(handle);
  for(let i=0;i<18;i++){
    const ridge=new T.Mesh(new T.TorusGeometry(.112,.008,5,16),materials.black);ridge.rotation.y=Math.PI/2;ridge.position.set(-.6+i*.07,2.36,0);root.add(ridge);
  }
  for(const x of [-1.6,1.6]){box(root,x,-1.86,.54,.3,.32,.12,materials.edge);box(root,x,-1.86,.63,.14,.2,.07,materials.copper);}
  if(closed){
    box(root,0,0,.54,4.28,3.57,.16,materials.case,.09);
    for(const x of [-1.91,1.91])for(const y of [-1.55,1.55])screw(root,x,y,.646);
    label(root,0,.16,.635,2.3,.45,'NULLSIGNAL',{size:72,color:'#c4c7be',background:null});
    label(root,0,-.38,.635,1.9,.18,'N S  /  Z W E I  S T I M M E N',{size:30,color:'#9aa8a5',background:null});
    return {root,hits,modules,animated,textures,materials};
  }
  const timerGroup=new T.Group();timerGroup.position.set(1.83,.98,.53);root.add(timerGroup);
  box(timerGroup,0,0,0,.74,1.6,.06,materials.black);
  label(timerGroup,0,.62,.04,.58,.15,'ZEIT',{size:50,color:'#ffb862'});
  const timer=label(timerGroup,0,.27,.05,.64,.36,'06:00',{size:122,color:'#ffad51'});
  label(timerGroup,0,-.09,.04,.59,.13,'FEHLER',{size:46,color:'#b7bdb8'});
  const strikes=[];
  for(let i=0;i<3;i++){
    cylinder(timerGroup,-.22+i*.22,-.34,.06,.085,.04,materials.black);
    const lamp=new T.Mesh(new T.SphereGeometry(.065,16,12),materials.red.clone());lamp.position.set(-.22+i*.22,-.34,.1);timerGroup.add(lamp);strikes.push(lamp);
  }
  label(root,1.83,-.72,.57,.66,.55,`${bomb?.serial||'NS-0000'}\n`,{size:45,color:'#a4b3ad'});
  label(root,1.83,-.82,.58,.63,.17,`${bomb?.voltage||18} V · ${bomb?.coolant||'KALT'}`,{size:34,color:'#c9cfbe'});
  for(let i=0;i<6;i++)box(root,1.83,-1.1-i*.1,.56,.55,.035,.06,materials.black,.009);
  const all=bomb?.modules||[];
  for(let side=0;side<2;side++){
    const face=new T.Group();face.position.z=side?-.53:.53;face.rotation.y=side?Math.PI:0;root.add(face);
    for(let slot=0;slot<6;slot++){
      const m=all[side*6+slot],x=-1.3+(slot%2)*1.8,y=1.23-Math.floor(slot/2)*1.22;
      const panel=new T.Group();panel.position.set(x,y,.02);face.add(panel);
      const plate=box(panel,0,0,0,1.68,1.08,.065,materials.plate,.055);
      for(const sx of [-.77,.77])for(const sy of [-.47,.47])screw(panel,sx,sy,.057);
      if(!m){
        for(let i=0;i<6;i++)box(panel,0,.27-i*.11,.048,1.15,.04,.02,materials.black,.01);
        if(side&&slot===3)label(panel,0,0,.075,1.35,.64,'N S  /  24',{size:90,color:'#919f96'});
        continue;
      }
      hit(plate,m.id);
      label(panel,-.05,.427,.044,1.25,.12,m.name.toUpperCase(),{size:44,color:'#d3d9d0'});
      const led=new T.Mesh(new T.SphereGeometry(.032,12,8),materials.red.clone());led.position.set(.67,.42,.08);panel.add(led);
      const outline=new T.LineSegments(new T.EdgesGeometry(new RoundedBoxGeometry(1.7,1.1,.08,1,.04)),new T.LineBasicMaterial({color:'#ff9c52',transparent:true,opacity:0}));outline.position.z=.018;panel.add(outline);
      const item={panel,led,outline,kind:m.kind,buttons:[],values:[],labels:[]};modules.set(m.id,item);
      const data=m.data;
      if(m.kind==='wires'){
        data.wires.forEach((color,i)=>{
          const yy=.25-i*(.63/(data.wires.length-1));
          for(const xx of [-.61,.61]){cylinder(panel,xx,yy,.09,.067,.04,materials.copper);cylinder(panel,xx,yy,.13,.042,.04,materials.black);}
          const curve=new T.CatmullRomCurve3([new T.Vector3(-.61,yy,.145),new T.Vector3(-.32,yy-.035,.22),new T.Vector3(.12,yy-.08,.23),new T.Vector3(.61,yy,.145)]);
          const cable=new T.Mesh(new T.TubeGeometry(curve,24,.029,8,false),new T.MeshStandardMaterial({color:COLOR_HEX[color],roughness:.65,metalness:0}));panel.add(cable);item.values.push(cable);
          const hitArea=hit(new T.Mesh(new T.TubeGeometry(curve,24,.052,8,false),new T.MeshBasicMaterial({transparent:true,opacity:0,depthWrite:false})),m.id,'cut',i);hitArea.userData.targetPoint=curve.getPoint(.5);panel.add(hitArea);cable.userData.hitArea=hitArea;
          const broken=new T.Group();broken.visible=false;panel.add(broken);cable.userData.broken=broken;
          for(const [from,to,droop] of [[0,.4,-.03],[.6,1,-.055]]){const points=Array.from({length:9},(_,index)=>{const point=curve.getPoint(from+(to-from)*index/8);point.y+=Math.sin(index/8*Math.PI)*droop;return point;});const end=new T.Mesh(new T.TubeGeometry(new T.CatmullRomCurve3(points),12,.029,8,false),cable.material);broken.add(end);}
        });
      }else if(m.kind==='glyphs'){
        data.keys.forEach((key,i)=>{const xx=i%2===0?-.36:.36,yy=i<2?.13:-.25;const buttonMesh=button(panel,m.id,xx,yy,.63,.32,'','press',i);glyph(panel,xx,yy,key);item.buttons.push(buttonMesh);});
      }else if(m.kind==='frequency'){
        cylinder(panel,0,.26,.08,.078,.04,materials.black);
        item.lamp=new T.Mesh(new T.SphereGeometry(.055,16,12),materials.mint.clone());item.lamp.position.set(0,.26,.12);panel.add(item.lamp);
        const ring=new T.Mesh(new T.TorusGeometry(.23,.025,10,48),materials.edge);ring.position.set(0,-.08,.09);panel.add(ring);
        cylinder(panel,0,-.08,.12,.2,.11,materials.black);
        item.needle=box(panel,0,.055,.195,.018,.11,.015,materials.copper,.004);item.needle.userData.centerY=-.08;
        button(panel,m.id,-.54,-.06,.25,.26,'−','step',-1,{size:220});button(panel,m.id,.54,-.06,.25,.26,'+','step',1,{size:220});
        item.labels.push(label(panel,0,-.09,.2,.3,.1,'72.0',{size:65,color:'#ffb466'}));
        button(panel,m.id,0,-.39,.71,.16,'SENDEN','submit',null,{size:43});
      }else if(m.kind==='sequence'){
        item.labels.push(label(panel,-.57,.27,.075,.32,.16,'1',{size:85,color:'#ffb466'}));
        item.stage=label(panel,.13,.28,.075,.84,.11,'SCHRITT 1 / 3',{size:44,color:'#9abdb4'});
        data.keys.forEach((key,i)=>{item.buttons.push(button(panel,m.id,-.48+(i%3)*.48,.06-Math.floor(i/3)*.21,.36,.17,String(key),'press',i,{size:86}));});
      }else if(m.kind==='relays'){
        for(let i=0;i<3;i++){
          const xx=-.48+i*.48;
          const lamp=new T.Mesh(new T.SphereGeometry(.045,12,8),new T.MeshStandardMaterial({color:(data.pattern&(1<<(2-i)))?'#ffb466':'#37474b',emissive:'#ff9c52',emissiveIntensity:(data.pattern&(1<<(2-i)))?.7:0}));lamp.position.set(xx,.23,.1);panel.add(lamp);
          const base=hit(box(panel,xx,-.11,.09,.29,.37,.07,materials.black),m.id,'toggle',i);
          const lever=new T.Group();lever.position.set(xx,-.11,.14);panel.add(lever);box(lever,0,.02,.09,.09,.24,.06,materials.edge);box(lever,0,.14,.09,.23,.1,.12,materials.copper);item.values.push(lever);item.buttons.push(base);
          label(panel,xx,-.34,.062,.25,.08,String(i+1),{size:55,color:'#95aaa4'});
        }
        button(panel,m.id,0,-.43,.7,.14,'PRÜFEN','submit',null,{size:40});
      }else if(m.kind==='sliders'){
        label(panel,0,.28,.073,.9,.13,`${data.mark}  /  ${data.polarity}`,{size:53,color:'#e3b373'});
        for(let row=0;row<3;row++){
          const yy=.08-row*.17;box(panel,0,yy,.08,1.12,.055,.05,materials.black,.012);
          for(let col=0;col<5;col++){
            const xx=-.5+col*.25;const tick=hit(box(panel,xx,yy,.111,.17,.13,.008,new T.MeshBasicMaterial({transparent:true,opacity:0,depthWrite:false})),m.id,'slide',[row,col]);
            box(panel,xx,yy+.054,.07,.012,.024,.008,materials.edge,0);
          }
          const knob=box(panel,0,yy,.12,.075,.14,.07,materials.copper,.012);item.values.push(knob);
        }
        button(panel,m.id,0,-.43,.7,.14,'PRÜFEN','submit',null,{size:40});
      }else if(m.kind==='pipes'){
        data.tiles.forEach((mask,i)=>{
          const xx=-.36+(i%3)*.36,yy=.19-Math.floor(i/3)*.23;
          const key=button(panel,m.id,xx,yy,.3,.19,'','rotate',i);
          const pipe=label(panel,xx,yy,.175,.28,.17,(ctx,w,h)=>{ctx.lineWidth=17;ctx.lineCap='round';for(const [bit,px,py] of [[1,w/2,0],[2,w,h/2],[4,w/2,h],[8,0,h/2]])if(mask&bit){ctx.beginPath();ctx.moveTo(w/2,h/2);ctx.lineTo(px,py);ctx.stroke();}},{background:null,color:'#a7d6ca'});item.values.push(pipe.mesh);item.buttons.push(key);
        });
        label(panel,-.67,-.04,.075,.13,.12,'→',{size:80,color:'#ffb466'});label(panel,.67,-.04,.075,.13,.12,'→',{size:80,color:'#ffb466'});
        button(panel,m.id,0,-.43,.7,.14,'PRÜFEN','submit',null,{size:40});
      }else if(m.kind==='vectors'){
        label(panel,-.45,.27,.075,.7,.13,`A${data.numbers[0]} B${data.numbers[1]} C${data.numbers[2]}`,{size:35,color:'#bdc6bb'});
        item.labels.push(label(panel,.42,.26,.075,.55,.15,'____',{size:70,color:'#ffb466'}));
        for(let i=0;i<9;i++)button(panel,m.id,-.45+(i%3)*.45,.06-Math.floor(i/3)*.17,.33,.14,String(i+1),'digit',i+1,{size:72});
        button(panel,m.id,-.45,-.44,.33,.13,'C','clear',null,{size:65});button(panel,m.id,0,-.44,.33,.13,'0','digit',0,{size:65});button(panel,m.id,.45,-.44,.33,.13,'OK','submit',null,{size:50});
      }
    }
  }
  return {root,hits,modules,animated,textures,materials,timer,strikes};
}
