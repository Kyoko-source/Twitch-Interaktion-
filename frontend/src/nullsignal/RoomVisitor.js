import * as T from 'three';

// World-space photographic billboard: actual depth, perspective and occlusion.
// It is separate from the rotating device and never changes puzzle state.
export class RoomVisitor {
  constructor(scene){
    this.scene=scene;this.alive=true;this.round=null;this.cycle=null;this.opacity=0;this.exposure=0;this.dismissed=new Set();this.seen=new Set();
    this.ray=new T.Raycaster();this.head=new T.Vector3();this.origin=new T.Vector3();this.direction=new T.Vector3();this.toHead=new T.Vector3();this.projected=new T.Vector3();this.reference=new T.PerspectiveCamera(33,1,.1,70);
    this.sprite=new T.Sprite(new T.SpriteMaterial({transparent:true,opacity:0,depthWrite:false,alphaTest:.025,color:'#839698'}));
    this.sprite.scale.set(4.13,6.2,1);this.sprite.visible=false;scene.add(this.sprite);
  }
  load(){
    this.loading=true;new T.TextureLoader().load('/assets/nullsignal/visitor-fullbody-v1.png',texture=>{
      if(!this.alive){texture.dispose();return;}
      texture.colorSpace=T.SRGBColorSpace;this.texture=texture;this.sprite.material.map=texture;this.sprite.material.needsUpdate=true;
    },undefined,()=>{});
  }
  persist(){try{sessionStorage.setItem('nullsignal-visitor:'+this.round,JSON.stringify({dismissed:[...this.dismissed],seen:[...this.seen]}));}catch{}}
  reset(round){
    this.round=round;this.cycle=null;this.opacity=0;this.exposure=0;this.dismissed.clear();this.seen.clear();
    try{const saved=JSON.parse(sessionStorage.getItem('nullsignal-visitor:'+round)||'{}');for(const value of saved.dismissed||[])if(Number.isInteger(value))this.dismissed.add(value);for(const value of saved.seen||[])if(Number.isInteger(value))this.seen.add(value);}catch{}
  }
  place(stage,aspect){
    const fit=Math.max(1,1/aspect);this.reference.aspect=aspect;this.reference.position.set(2.2,1,9.2).multiplyScalar(fit).add(new T.Vector3(0,.05*(1-fit),0));this.reference.lookAt(0,.05,0);this.reference.updateProjectionMatrix();this.reference.updateMatrixWorld();
    // Keep the face beside the case even in the narrow portrait viewport.
    const side=aspect<1?(stage===1?.9:stage===0?-.9:-.94):(stage===1?.78:stage===0?-.78:-.72),z=[-9,-6.5,-4.5][stage];
    this.ray.setFromCamera(new T.Vector2(side,0),this.reference);
    const distance=(z-this.ray.ray.origin.z)/this.ray.ray.direction.z;
    this.sprite.position.copy(this.ray.ray.at(distance,this.head));this.sprite.position.y=-1.1;
    this.aspect=aspect;this.stage=stage;
  }
  update({roundId,visit,enabled,camera,flashlight,occluders,delta,onSeen}){
    if(enabled&&!this.loading)this.load();
    if(roundId!==this.round)this.reset(roundId);
    if(visit&&(visit.cycle!==this.cycle||camera.aspect!==this.aspect)){
      this.cycle=visit.cycle;this.exposure=0;this.place(visit.stage,camera.aspect);
    }
    const showing=Boolean(enabled&&visit&&this.texture&&!this.dismissed.has(visit.cycle));
    if(showing&&!this.seen.has(visit.cycle)){this.seen.add(visit.cycle);this.persist();onSeen?.();}
    this.sprite.getWorldPosition(this.head);this.head.y+=this.sprite.scale.y*.32;
    this.lit=false;this.blocker=null;this.alignment=null;
    if(showing&&flashlight.intensity>0){
      flashlight.getWorldPosition(this.origin);flashlight.target.getWorldPosition(this.direction);this.direction.sub(this.origin).normalize();this.toHead.copy(this.head).sub(this.origin);
      const distance=this.toHead.length();this.alignment=this.toHead.normalize().dot(this.direction);
      if(this.alignment>Math.cos(flashlight.angle*.42)){
        this.ray.set(this.origin,this.toHead);this.ray.far=Math.max(0,distance-.2);
        const hit=this.ray.intersectObjects(occluders,true).find(({object})=>{
          // Selection outlines and invisible click volumes do not block light.
          if(!object.isMesh)return false;
          for(let parent=object;parent;parent=parent.parent)if(!parent.visible)return false;
          return [object.material].flat().some(material=>material.visible&&material.opacity>.1);
        });
        this.blocker=hit?{distance:hit.distance,position:hit.point.toArray()}:null;this.lit=!hit;
      }
    }
    this.exposure=this.lit?this.exposure+delta:0;
    if(this.exposure>=.45&&showing){this.dismissed.add(visit.cycle);this.persist();}
    // Immediate removal for pause, pills and opt-out; a brief dissolve for light.
    const target=showing&&!this.dismissed.has(visit.cycle) ? .78 : 0;
    this.opacity=enabled&&visit?T.MathUtils.damp(this.opacity,target,12,delta):0;
    this.sprite.material.opacity=this.opacity;this.sprite.visible=this.opacity>.015;
    this.projected.copy(this.head).project(camera);
  }
  inspect(camera,width,height){
    return {loaded:Boolean(this.texture),visible:this.sprite.visible,cycle:this.cycle,stage:this.stage,opacity:this.opacity,lit:this.lit,lightProgress:this.exposure,blocker:this.blocker,beamAlignment:this.alignment,beamOrigin:this.origin.toArray(),head:this.head.toArray(),dismissed:[...this.dismissed],position:this.sprite.position.toArray(),distance:camera.position.distanceTo(this.sprite.position),target:{x:(this.projected.x+1)*width/2,y:(1-this.projected.y)*height/2,inView:this.projected.z<1&&Math.abs(this.projected.x)<1&&Math.abs(this.projected.y)<1}};
  }
  dispose(){this.alive=false;this.scene.remove(this.sprite);this.texture?.dispose();this.sprite.material.dispose();}
}
