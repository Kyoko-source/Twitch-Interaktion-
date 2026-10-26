class_name EndingAfterglow
extends RefCounted

const DURATION:=16.0
var g: Node3D
var w: PlayWorld
var camera: Camera3D
var prior: Camera3D
var clock:=0.0
var lights: Array[Dictionary]=[]
var emissions: Array[Dictionary]=[]
var ambient:=0.0
var finished:=false
var disposed:=false

func build(game: Node3D) -> void:
 g=game
 # The last image is the intact, empty reference venue. Patrol progress and
 # the completed archive remain unchanged; only the displayed world is rebuilt.
 g._build_world("none");w=g.world
 prior=g.get_viewport().get_camera_3d()
 camera=Camera3D.new();camera.name="AfterPlayLastLook";camera.fov=67;camera.position=Vector3(-4.2,1.85,13.9);w.add_child(camera)
 camera.look_at(Vector3(7.4,2.15,3.6));camera.make_current()
 for light in w.find_children("*","Light3D",true,false): lights.append({"node":light,"energy":light.light_energy})
 var seen: Dictionary={}
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  for surface in range(mesh.mesh.get_surface_count()):
   var material: Material=mesh.get_active_material(surface)
   if material is StandardMaterial3D and material.emission_enabled and not seen.has(material.get_instance_id()):
    seen[material.get_instance_id()]=true;emissions.append({"material":material,"energy":material.emission_energy_multiplier})
 ambient=w.environment.environment.ambient_light_energy
 # Ordinary room sounds stay paused in the ending. Only the supplied music box plays.
 w.atmosphere.set_active(false)

func tick(delta: float) -> void:
 if finished: return
 clock=minf(clock+delta,DURATION)
 for i in range(lights.size()):
  var light: Light3D=lights[i].node
  if is_instance_valid(light): light.light_energy=lights[i].energy*(1.-smoothstep(3.+fmod(i*1.9,6.),10.5+fmod(i*.7,2.),clock))
 if is_instance_valid(w): w.environment.environment.ambient_light_energy=ambient*(1.-smoothstep(5.,13.,clock))
 for item in emissions: item.material.emission_energy_multiplier=item.energy*(1.-smoothstep(4.,12.,clock))
 finished=clock>=DURATION

func shade_alpha() -> float:
 return maxf(1.-smoothstep(0.,2.,clock),smoothstep(12.5,16.,clock))

func dispose() -> void:
 if disposed: return
 disposed=true
 for item in lights:
  if is_instance_valid(item.node): item.node.light_energy=item.energy
 for item in emissions: item.material.emission_energy_multiplier=item.energy
 if is_instance_valid(w): w.environment.environment.ambient_light_energy=ambient
 if is_instance_valid(prior) and prior.is_inside_tree(): prior.make_current()
 if is_instance_valid(camera): camera.queue_free()
 lights.clear()
 emissions.clear()

func snapshot() -> Dictionary:
 return {"clock":clock,"finished":finished,"camera":is_instance_valid(camera),"light_ratio":1.-smoothstep(3.,12.,clock)}
