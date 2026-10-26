class_name BallPitPhysics
extends Node3D

# Keep one draw call, but give every rendered ball its own real sphere body.
# Layer 4 is deliberately absent from the guard's movement mask: lightweight
# balls move aside instead of becoming a staircase that traps the player.
const RADIUS:=.14
var w: PlayWorld
var bodies: Array[RigidBody3D]=[]
var starts: Array[Vector3]=[]
var suspended: Array[Vector3]=[]
var spinning: Array[Vector3]=[]
var running:=false
var player: NightGuard
var kicks:=0
var configured:=false

func build(world: PlayWorld) -> void:
 w=world;name="PhysicalBallPit"
 var sphere:=SphereShape3D.new();sphere.radius=RADIUS
 var plastic:=PhysicsMaterial.new();plastic.friction=.28;plastic.bounce=.12
 for i in range(w.ball_transforms.size()):
  var body:=RigidBody3D.new();body.name="PitBall%03d"%i;body.mass=.055;body.collision_layer=4;body.collision_mask=7
  body.physics_material_override=plastic;body.linear_damp=1.2;body.angular_damp=1.6;body.continuous_cd=true;body.freeze=true
  var shape:=CollisionShape3D.new();shape.shape=sphere;body.add_child(shape);add_child(body)
  body.global_position=w.balls.to_global(w.ball_transforms[i].origin)
  bodies.append(body);starts.append(body.global_position);suspended.append(Vector3.ZERO);spinning.append(Vector3.ZERO)
 _render()

func configure() -> void:
 configured=true
 for i in range(bodies.size()):
  var absent:=w.current=="balls_missing"
  bodies[i].collision_layer=0 if absent else 4
  bodies[i].collision_mask=0 if absent else 7

func _floating(i: int) -> bool:
 return w.current=="balls_float" and i%3==0

func tick(active: bool, guard: NightGuard) -> void:
 player=guard
 var enabled:=active and configured and w.current!="balls_missing"
 if enabled!=running:
  running=enabled
  for i in range(bodies.size()):
   var body:=bodies[i]
   if _floating(i): continue
   if not enabled:
    suspended[i]=body.linear_velocity;spinning[i]=body.angular_velocity
   body.freeze=not enabled
   if enabled: body.linear_velocity=suspended[i];body.angular_velocity=spinning[i]
 if running and w.current=="balls_float":
  for i in range(0,bodies.size(),3):
   bodies[i].freeze=true;bodies[i].global_position=starts[i]+Vector3.UP*(1.0+sin(w.clock*.7)*.25)
 _render()

func _physics_process(delta: float) -> void:
 if not running or not is_instance_valid(player): return
 var speed:=Vector2(player.velocity.x,player.velocity.z).length()
 if speed<.15 and absf(player.velocity.y)<.5: return
 for i in range(bodies.size()):
  if _floating(i): continue
  var body:=bodies[i];var offset:=body.global_position-player.global_position
  if offset.y<-.14 or offset.y>1.1: continue
  offset.y=0
  if offset.length_squared()>.53*.53: continue
  var push: Vector3=(offset.normalized()+Vector3(player.velocity.x,0,player.velocity.z).normalized()*.45).normalized()
  body.sleeping=false;body.apply_central_impulse((push*minf(2.5,speed*.65)+Vector3.UP*.20)*body.mass*delta*13)
  kicks+=1

func _render() -> void:
 var inverse:=w.balls.global_transform.affine_inverse()
 for i in range(bodies.size()):
  var transform_value:=inverse*bodies[i].global_transform
  w.ball_render_transforms[i]=transform_value;w.balls.multimesh.set_instance_transform(i,transform_value)

func snapshot() -> Dictionary:
 var moving:=0;var sleeping:=0
 for body in bodies:
  if body.linear_velocity.length()>.06: moving+=1
  if body.sleeping: sleeping+=1
 return {"count":bodies.size(),"running":running,"moving":moving,"sleeping":sleeping,"kicks":kicks,"radius":RADIUS,"floating":120 if w.current=="balls_float" else 0}
