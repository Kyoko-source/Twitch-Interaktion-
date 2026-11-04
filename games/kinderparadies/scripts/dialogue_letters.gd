class_name DialogueLetters
extends Node3D

const LIMIT:=150
var letters: Array[Dictionary]=[]
var rng:=RandomNumberGenerator.new()
var guard: NightGuard
var emitted:=0

func build(player: NightGuard) -> void:
 guard=player;name="FallingCommentLetters";rng.seed=406

func release(letter: String,screen: Vector2,color: Color) -> void:
 if letter.strip_edges().is_empty():return
 if letters.size()>=LIMIT:letters[0].node.free();letters.pop_front()
 var camera:=guard.camera
 var start:=camera.project_position(screen,1.25)
 var forward:=-camera.global_basis.z;forward.y=0
 if forward.length_squared()<.01:forward=-guard.global_basis.z
 var goal:=guard.global_position+forward.normalized()*.90+Vector3(rng.randf_range(-.25,.25),.02,rng.randf_range(-.16,.16))
 var excludes: Array[RID]=[guard.get_rid()]
 if is_instance_valid(guard.carried):excludes.append(guard.carried.get_rid())
 # Find a floor under the pile, skipping tabletops above the player's feet.
 for i in range(8):
  var ray:=PhysicsRayQueryParameters3D.create(goal+Vector3.UP*.35,goal+Vector3.DOWN*3.,1,excludes)
  var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
  if hit.is_empty():goal.y=guard.global_position.y+.025;break
  if hit.normal.y>.65 and hit.position.y<=guard.global_position.y+.30:
   goal.y=hit.position.y+.018+rng.randf_range(0,.008);break
  excludes.append(hit.rid)
 start.y=maxf(start.y,goal.y+.25)
 var flight:=sqrt(2.*(start.y-goal.y)/6.8)
 var node:=Label3D.new();node.name="FallenLetter";node.text=letter;node.font=ThemeDB.fallback_font;node.font_size=64
 node.pixel_size=clampf(camera.project_position(screen+Vector2(0,27),1.25).distance_to(camera.project_position(screen,1.25))/64.,.0007,.0025)
 node.modulate=color;node.outline_size=0;node.shaded=true;node.no_depth_test=false;node.alpha_cut=Label3D.ALPHA_CUT_DISCARD
 node.billboard=BaseMaterial3D.BILLBOARD_ENABLED;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(node);node.global_position=start
 letters.append({"node":node,"start":start,"goal":goal,"flight":flight,"time":0.,"spin":rng.randf_range(-2.,2.),"yaw":rng.randf_range(-PI,PI),"color":color})
 emitted+=1

func tick(delta: float,active: bool) -> void:
 visible=active
 if not active:return
 for i in range(letters.size()-1,-1,-1):
  var r: Dictionary=letters[i];r.time+=delta
  var t: float=minf(r.time/r.flight,1.)
  if t<1.:
   r.node.global_position=r.start.lerp(r.goal,t)
   r.node.global_position.y=r.start.y-3.4*pow(r.time,2)
   r.node.rotation.z=r.spin*r.time
  else:
   r.node.global_position=r.goal;r.node.billboard=BaseMaterial3D.BILLBOARD_DISABLED;r.node.rotation=Vector3(-PI/2,r.yaw,0)
   var fade:=clampf((r.time-r.flight-3.2)/1.4,0.,1.)
   # Fade with geometry scaling: the opaque glyphs do not introduce another
   # transparent particle layer or TAA stippling on the floor.
   r.node.scale=Vector3.ONE*(1.-fade)
  if r.time>r.flight+4.6:r.node.free();letters.remove_at(i)

func clear() -> void:
 for r in letters:r.node.free()
 letters.clear()

func snapshot() -> Dictionary:
 return {"count":letters.size(),"landed":letters.filter(func(r):return r.time>=r.flight).size(),"emitted":emitted,"visible":visible}
