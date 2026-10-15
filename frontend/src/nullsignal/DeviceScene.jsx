import React,{useEffect,useRef,useState} from 'react';
import * as T from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {RoomEnvironment} from 'three/addons/environments/RoomEnvironment.js';
import {EffectComposer} from 'three/addons/postprocessing/EffectComposer.js';
import {RenderPass} from 'three/addons/postprocessing/RenderPass.js';
import {UnrealBloomPass} from 'three/addons/postprocessing/UnrealBloomPass.js';
import {OutputPass} from 'three/addons/postprocessing/OutputPass.js';
import {createDevice} from './DeviceGeometry';

function disposeTree(root,{materials=true}={}){
  const geometries=new Set(),mats=new Set(),maps=new Set();
  root?.traverse(object=>{if(object.geometry)geometries.add(object.geometry);for(const material of [object.material].flat().filter(Boolean)){mats.add(material);for(const value of Object.values(material))if(value?.isTexture&&value.isCanvasTexture)maps.add(value);}});
  geometries.forEach(g=>g.dispose());maps.forEach(t=>t.dispose());if(materials)mats.forEach(m=>m.dispose());
}

class DeviceRenderer {
  constructor(container,getProps,onError,onReady){
    this.container=container;this.getProps=getProps;this.onError=onError;this.onReady=onReady;this.alive=true;this.lastSelected=null;this.lastRound=null;this.lastTimer='';this.lastEvent=null;this.effectStart=-Infinity;this.elapsed=0;
    this.reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
    this.scene=new T.Scene();
    this.camera=new T.PerspectiveCamera(33,1,.1,70);
    this.renderer=new T.WebGLRenderer({antialias:true,alpha:true,powerPreference:'high-performance'});
    this.renderer.setPixelRatio(Math.min(devicePixelRatio||1,1.5));this.renderer.setClearColor(0,0);
    this.renderer.outputColorSpace=T.SRGBColorSpace;this.renderer.toneMapping=T.ACESFilmicToneMapping;this.renderer.toneMappingExposure=1.05;
    this.renderer.shadowMap.enabled=true;this.renderer.shadowMap.type=T.PCFSoftShadowMap;this.renderer.shadowMap.autoUpdate=false;
    container.append(this.renderer.domElement);this.renderer.domElement.setAttribute('aria-label','Drehbare 3D-Bombe. Ziehen zum Drehen, Modul anklicken zum Fokussieren.');this.renderer.domElement.setAttribute('role','img');
    this.controls=new OrbitControls(this.camera,this.renderer.domElement);this.controls.enablePan=false;this.controls.enableDamping=true;this.controls.dampingFactor=.085;this.controls.minDistance=1.8;this.controls.maxDistance=17;this.controls.minPolarAngle=.2;this.controls.maxPolarAngle=Math.PI/2-.03;
    this.onOrbit=()=>{this.tween=null;};this.controls.addEventListener('start',this.onOrbit);
    const ambient=new T.HemisphereLight('#b9d8df','#39271d',.8);this.scene.add(ambient);
    const key=new T.DirectionalLight('#ffd7a0',2.8);key.position.set(-4,7,6);key.castShadow=true;key.shadow.mapSize.set(2048,2048);key.shadow.camera.left=-5;key.shadow.camera.right=5;key.shadow.camera.top=5;key.shadow.camera.bottom=-5;key.shadow.normalBias=.025;this.scene.add(key);
    const fill=new T.DirectionalLight('#94c8ec',1.3);fill.position.set(5,2,4);this.scene.add(fill);
    const rim=new T.DirectionalLight('#ffac64',1.5);rim.position.set(0,2,-5);this.scene.add(rim);
    const pmrem=new T.PMREMGenerator(this.renderer),roomEnvironment=new RoomEnvironment();this.environment=pmrem.fromScene(roomEnvironment,.06);this.scene.environment=this.environment.texture;this.scene.environmentIntensity=.4;roomEnvironment.dispose();pmrem.dispose();
    this.table=new T.Mesh(new T.BoxGeometry(13,.18,8),new T.MeshStandardMaterial({color:'#594331',metalness:.35,roughness:.8}));this.table.position.y=-2.2;this.table.receiveShadow=true;this.scene.add(this.table);
    this.composer=new EffectComposer(this.renderer);this.composer.addPass(new RenderPass(this.scene,this.camera));this.bloom=new UnrealBloomPass(new T.Vector2(800,600),.1,.35,2.5);this.composer.addPass(this.bloom);this.outputPass=new OutputPass();this.composer.addPass(this.outputPass);
    const count=80,positions=new Float32Array(count*3);this.particleDirections=[];
    for(let i=0;i<count;i++){const v=new T.Vector3(Math.sin(i*2.4),Math.cos(i*7.1)*.8+.6,Math.cos(i*3.3)).normalize();this.particleDirections.push(v);}
    const geo=new T.BufferGeometry();geo.setAttribute('position',new T.BufferAttribute(positions,3));
    this.particles=new T.Points(geo,new T.PointsMaterial({size:.04,color:'#ffb46b',transparent:true,opacity:0,depthWrite:false,blending:T.AdditiveBlending}));this.scene.add(this.particles);
    this.pointer=new T.Vector2();this.ray=new T.Raycaster();
    this.down=event=>{this.downPoint={x:event.clientX,y:event.clientY,time:performance.now()};};
    this.up=event=>{if(!this.downPoint||Math.hypot(event.clientX-this.downPoint.x,event.clientY-this.downPoint.y)>7||performance.now()-this.downPoint.time>700)return;this.pick(event);};
    this.move=event=>{if(!this.device)return;this.setRay(event);const found=this.ray.intersectObjects(this.device.hits,false)[0];this.renderer.domElement.style.cursor=found?'pointer':'grab';};
    this.contextLost=event=>{event.preventDefault();if(this.alive)this.onError('Die 3D-Verbindung wurde unterbrochen. Lade die 3D-Ansicht erneut; eure Runde bleibt gespeichert.');};
    this.renderer.domElement.addEventListener('pointerdown',this.down);this.renderer.domElement.addEventListener('pointerup',this.up);this.renderer.domElement.addEventListener('pointermove',this.move);this.renderer.domElement.addEventListener('webglcontextlost',this.contextLost);
    this.observer=new ResizeObserver(()=>this.resize());this.observer.observe(container);
    this.renderer.domElement.__nullsignalScene={ready:false,targets:()=>this.targets(),view:side=>this.view(side)};
    this.resize();this.view('front',true);
    const loader=new T.TextureLoader();Promise.all([loader.loadAsync('/assets/nullsignal/steel.png'),loader.loadAsync('/assets/nullsignal/workshop.png')]).then(([texture,background])=>{
      if(!this.alive){texture.dispose();background.dispose();return;}
      texture.colorSpace=T.SRGBColorSpace;texture.wrapS=texture.wrapT=T.RepeatWrapping;texture.repeat.set(2,2);texture.anisotropy=Math.min(this.renderer.capabilities.getMaxAnisotropy(),8);this.steel=texture;this.table.material.map=texture;this.table.material.bumpMap=texture;this.table.material.bumpScale=.025;this.table.material.needsUpdate=true;
      background.colorSpace=T.SRGBColorSpace;this.background=background;this.scene.background=background;this.resize();this.rebuild();this.renderer.domElement.__nullsignalScene.ready=true;this.onReady();
    }).catch(()=>{if(this.alive)this.onError('Die Werkstatttexturen konnten nicht geladen werden. Bitte erneut versuchen.');});
    this.animate=this.animate.bind(this);this.frame=requestAnimationFrame(this.animate);
  }
  resize(){
    if(!this.alive)return;const width=Math.max(1,this.container.clientWidth),height=Math.max(1,this.container.clientHeight);
    this.camera.aspect=width/height;this.camera.updateProjectionMatrix();this.renderer.setSize(width,height);this.composer.setSize(width,height);
    if(this.background){const ratio=this.camera.aspect/(this.background.image.width/this.background.image.height);this.background.repeat.set(Math.min(1,ratio),Math.min(1,1/ratio));this.background.offset.set((1-this.background.repeat.x)/2,(1-this.background.repeat.y)/2);}
  }
  rebuild(){
    if(!this.steel)return;
    if(this.device){this.scene.remove(this.device.root);disposeTree(this.device.root);}
    const props=this.getProps();this.closed=props.preview;this.lastRound=props.roundId;this.device=createDevice({steel:this.steel,bomb:props.bomb,closed:this.closed});this.scene.add(this.device.root);
    if(this.closed){this.device.root.rotation.x=-Math.PI/2;this.device.root.rotation.z=-.12;this.device.root.position.y=-1.54;}
    this.lastSelected=null;this.lastTimer='';this.renderer.shadowMap.needsUpdate=true;this.applyState();this.view('front',true);
  }
  update(){
    const props=this.getProps();
    if(this.steel&&(props.preview!==this.closed||props.roundId!==this.lastRound))this.rebuild();
    this.applyState();
    if(props.selected!==this.lastSelected){this.lastSelected=props.selected;if(props.selected)this.focus(props.selected);}
    const event=props.event;
    if(event?.id&&event.id!==this.lastEvent){this.lastEvent=event.id;if(['bad','good','defused','exploded'].includes(event.kind)){this.effectStart=performance.now();this.effectKind=event.kind;this.effectModule=event.module;}}
  }
  applyState(){
    if(!this.device||this.closed)return;const {bomb,strikes=0,selected}=this.getProps();
    this.device.strikes?.forEach((light,i)=>{light.material.emissiveIntensity=i<strikes?2:.04;light.material.color.set(i<strikes?'#ff5348':'#381d1b');});
    for(const m of bomb?.modules||[]){
      const item=this.device.modules.get(m.id);if(!item)continue;
      const signature=JSON.stringify(m.data);if(item.dataSignature!==signature){item.dataSignature=signature;this.renderer.shadowMap.needsUpdate=true;}
      item.led.material.color.set(m.solved?'#83e5cd':'#59483a');item.led.material.emissive.set(m.solved?'#83e5cd':'#c87b39');item.led.material.emissiveIntensity=m.solved?1.1:.08;
      item.outline.material.opacity=selected===m.id ? .65 : 0;
      if(m.kind==='wires')item.values.forEach((cable,i)=>{const cut=m.data.cut.includes(i);cable.visible=!cut;cable.userData.hitArea.visible=!cut;cable.userData.broken.visible=cut;});
      if(m.kind==='glyphs')item.buttons.forEach((key,i)=>{key.material.color.set(m.progress.includes(m.data.keys[i])?'#4c9a84':'#303d42');});
      if(m.kind==='frequency'){
        const angle=(-.7+m.data.tuning/8*1.4)*Math.PI;item.needle.position.set(Math.sin(angle)*.145,-.08+Math.cos(angle)*.145,.195);item.needle.rotation.z=-angle;
        const value=m.data.channels[m.data.tuning].toFixed(1);if(item.previous!==value){item.labels[0].paint(value);item.previous=value;}
      }
      if(m.kind==='sequence'){
        const value=`${m.progress.length}:${m.solved}`;if(item.previous!==value){item.labels[0].paint(m.solved?'✓':String(m.data.displays[Math.min(2,m.progress.length)]));item.stage.paint(`SCHRITT ${Math.min(3,m.progress.length+1)} / 3`);item.previous=value;}
        item.buttons.forEach((key,i)=>key.material.color.set(m.progress.includes(i)?'#4c9a84':'#303d42'));
      }
      if(m.kind==='relays')item.values.forEach((lever,i)=>{lever.rotation.x=m.data.switches[i]?-.5:.5;});
      if(m.kind==='sliders')item.values.forEach((knob,i)=>{knob.position.x=-.5+m.data.sliders[i]*.25;});
      if(m.kind==='pipes')item.values.forEach((tile,i)=>{tile.rotation.z=-m.data.rotations[i]*Math.PI/2;});
      if(m.kind==='vectors'&&item.previous!==m.data.entered){item.labels[0].paint(m.data.entered.padEnd(4,'_'));item.previous=m.data.entered;}
    }
  }
  setRay(event){const rect=this.renderer.domElement.getBoundingClientRect();this.pointer.set((event.clientX-rect.left)/rect.width*2-1,-(event.clientY-rect.top)/rect.height*2+1);this.ray.setFromCamera(this.pointer,this.camera);}
  pick(event){
    if(!this.device||this.closed)return;this.setRay(event);const picked=this.ray.intersectObjects(this.device.hits,false).find(hit=>hit.object.visible)?.object;
    if(!picked)return;const target=picked.userData.ns,props=this.getProps(),module=props.bomb?.modules.find(m=>m.id===target.id);
    if(props.selected!==target.id){props.onSelect(target.id);return;}
    if(!target.operation||props.status!=='running'||module?.solved)return;
    if(target.operation==='step'){const tuning=Math.max(0,Math.min(8,module.data.tuning+target.value));props.onAction(target.id,'tune',tuning);}
    else props.onAction(target.id,target.operation,target.value);
  }
  tweenTo(position,target,instant=false){
    if(instant||this.reduced){this.camera.position.copy(position);this.controls.target.copy(target);this.controls.update();this.tween=null;return;}
    this.tween={start:performance.now(),position:this.camera.position.clone(),target:this.controls.target.clone(),to:position,toTarget:target};
  }
  view(side='front',instant=false){
    if(!this.camera)return;const fit=Math.max(1,1.0/this.camera.aspect);
    if(this.closed)this.tweenTo(new T.Vector3(3.4,4.2,9.4).multiplyScalar(fit),new T.Vector3(0,-1.2,0),instant);
    else this.tweenTo(new T.Vector3(side==='back'?-2.2:2.2,1,side==='back'?-9.2:9.2).multiplyScalar(fit),new T.Vector3(0,.05,0),instant);
  }
  focus(id){
    const item=this.device?.modules.get(id);if(!item)return;this.device.root.updateMatrixWorld(true);
    const target=item.panel.getWorldPosition(new T.Vector3()),normal=new T.Vector3(0,0,1).transformDirection(item.panel.matrixWorld);
    const distance=2.9*Math.max(1,.95/this.camera.aspect);this.tweenTo(target.clone().addScaledVector(normal,distance).add(new T.Vector3(0,.08,0)),target);
  }
  targets(){
    if(!this.device)return[];this.scene.updateMatrixWorld(true);
    return this.device.hits.filter(mesh=>mesh.visible).map(mesh=>{const world=mesh.userData.targetPoint?mesh.localToWorld(mesh.userData.targetPoint.clone()):new T.Box3().setFromObject(mesh).getCenter(new T.Vector3()),p=world.project(this.camera);return {...mesh.userData.ns,x:(p.x+1)*this.container.clientWidth/2,y:(1-p.y)*this.container.clientHeight/2,inView:p.z<1&&Math.abs(p.x)<1&&Math.abs(p.y)<1};});
  }
  animate(now){
    if(!this.alive)return;const props=this.getProps();
    if(this.tween){const t=Math.min(1,(now-this.tween.start)/420),ease=1-Math.pow(1-t,3);this.camera.position.lerpVectors(this.tween.position,this.tween.to,ease);this.controls.target.lerpVectors(this.tween.target,this.tween.toTarget,ease);if(t===1)this.tween=null;}
    this.controls.update();
    if(this.device&&!this.closed){
      const remaining=props.remaining(),sec=Math.max(0,Math.ceil(remaining)),text=`${String(Math.floor(sec/60)).padStart(2,'0')}:${String(sec%60).padStart(2,'0')}`;
      if(text!==this.lastTimer){this.device.timer.paint(text);this.lastTimer=text;}
      for(const m of props.bomb?.modules||[])if(m.kind==='frequency'){
        const item=this.device.modules.get(m.id),position=(now/450)%9,index=Math.floor(position);
        if(item?.lamp)item.lamp.material.emissiveIntensity=props.status==='running'&&!m.solved&&index<5&&(position%1)<(m.data.pattern[index]==='1'?.85:.25)?2.5:.02;
      }
      const age=(now-this.effectStart)/1000;
      if(!this.reduced&&age<1.2){
        const exploded=this.effectKind==='exploded',bad=exploded||this.effectKind==='bad',origin=this.device.modules.get(this.effectModule)?.panel.getWorldPosition(new T.Vector3())||new T.Vector3(0,0,.6);
        const position=this.particles.geometry.attributes.position;
        this.particles.material.color.set(bad?'#ff9c52':'#83e5cd');this.particles.material.opacity=Math.max(0,1-age/1.2);
        for(let i=0;i<position.count;i++){const direction=this.particleDirections[i],speed=exploded?4:1.3;position.setXYZ(i,origin.x+direction.x*age*speed,origin.y+direction.y*age*speed-age*age,origin.z+direction.z*age*speed);}
        position.needsUpdate=true;
        this.device.root.position.x=bad&&age<.2?Math.sin(age*155)*.025:0;
      }else{this.particles.material.opacity=0;this.device.root.position.x=0;}
    }
    if(!document.hidden)this.composer.render();this.frame=requestAnimationFrame(this.animate);
  }
  dispose(){
    this.alive=false;cancelAnimationFrame(this.frame);this.observer.disconnect();this.controls.dispose();
    const canvas=this.renderer.domElement;canvas.removeEventListener('pointerdown',this.down);canvas.removeEventListener('pointerup',this.up);canvas.removeEventListener('pointermove',this.move);canvas.removeEventListener('webglcontextlost',this.contextLost);
    disposeTree(this.scene);this.steel?.dispose();this.background?.dispose();this.environment.dispose();this.composer.dispose();this.bloom.dispose();this.outputPass.dispose();this.renderer.dispose();this.renderer.forceContextLoss();canvas.remove();
  }
}

export default function DeviceScene(props){
  const container=useRef(null),instance=useRef(null),latest=useRef(props),alive=useRef(true);latest.current=props;
  const [error,setError]=useState(''),[loaded,setLoaded]=useState(false),[retry,setRetry]=useState(0);
  useEffect(()=>{
    alive.current=true;setError('');setLoaded(false);
    try{instance.current=new DeviceRenderer(container.current,()=>latest.current,message=>alive.current&&setError(message),()=>alive.current&&setLoaded(true));}
    catch(err){setError('Die 3D-Ansicht konnte nicht starten. Aktiviere die Hardwarebeschleunigung im Browser und versuche es erneut.');instance.current?.dispose();instance.current=null;}
    return()=>{alive.current=false;instance.current?.dispose();instance.current=null;};
  },[retry]);
  useEffect(()=>{instance.current?.update();});
  useEffect(()=>{if(props.cameraView)instance.current?.view(props.cameraView.side);},[props.cameraView]);
  return <div className={`nsViewport ${props.preview?'isPreview':''}`} ref={container} data-loaded={loaded}>
    {!loaded&&!error&&<div className="nsSceneMessage" role="status">Werkstatt wird vorbereitet …</div>}
    {error&&<div className="nsSceneMessage" role="alert"><p>{error}</p><button type="button" className="nsPrimary" onClick={()=>setRetry(value=>value+1)}>3D erneut laden</button></div>}
  </div>;
}
