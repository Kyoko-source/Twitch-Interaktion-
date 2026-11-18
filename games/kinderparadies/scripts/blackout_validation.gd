extends RefCounted

# --blackout-only: the power-cut event anomaly (4.9.0).
func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
 verify.call(PatrolState.ANOMALIES.any(func(row):return row.id==PowerBlackout.ID),"Blackout is missing from the anomaly catalogue")
 game.state.current=PowerBlackout.ID;game._build_world(PowerBlackout.ID);game._resume();game.player.active=false
 var power: PowerBlackout=game.world.blackout;power.set_process(false)
 var dt:=1.0/60.0
 verify.call(power.enabled and power.phase=="waiting" and game.world.red_locked() and game.world.passages.red_locked and not game.world.passages.horse_note.visible,"Blackout round does not lock red without the horse note")
 verify.call(game.world.red_clue()==PowerBlackout.CLUE,"Red door shows the wrong clue in a blackout round")
 game.world.party.set_enabled(true)
 for i in range(ceili((PowerBlackout.WAIT+PowerBlackout.FLICKER+.2)*60)):power.step(dt,true,game.player)
 verify.call(power.phase=="dark","Power does not fail a few seconds into the round")
 verify.call(power.lights.size()>10 and power.lights.all(func(light):return not is_instance_valid(light) or not light.visible),"Venue lights stay on during the blackout")
 verify.call(power.glows.all(func(m):return m.emission_energy_multiplier==0.),"Glowing signs and screens stay lit during the blackout")
 var env: Environment=game.world.environment.environment
 verify.call(env.ambient_light_energy==0. and env.fog_light_energy==0. and env.volumetric_fog_ambient_inject==0.,"Ambient light or glowing fog survives the blackout")
 verify.call(power.screens.size()>0 and power.screens.all(func(n):return not is_instance_valid(n) or not n.visible),"Self-lit screens and displays keep glowing in the dark")
 verify.call(not game.world.party.enabled and power.party_was_on,"Party mode keeps running without power")
 verify.call(power.hums.size()>0 and power.hums.all(func(h):return not is_instance_valid(h) or h.volume_db<=-79.),"Machine hums keep running without power")
 verify.call(game.player.lamp!=null and not power.is_ancestor_of(game.player.lamp) and power.lights.find(game.player.lamp)<0,"Blackout switches off the guard's torch")
 game._decide(true)
 verify.call(not game.world.passages.lanes[1].open,"Red door opens during the blackout")
 for i in range(ceili(20*60)):power.step(dt,true,game.player)
 verify.call(power.fear>.45 and power.fear<.55 and power.fright()>.15 and power.scares==0,"Fear does not build steadily over the 40 seconds")
 var scared:=false
 for i in range(ceili(21*60)):
  power.step(dt,true,game.player)
  if power.visitor.visible:scared=true
 verify.call(scared and power.scares==1 and power.scream.playing,"No jumpscare after 40 seconds in the dark")
 for i in range(60):power.step(dt,true,game.player)
 verify.call(not power.visitor.visible and power.phase=="dark" and power.fear<.1,"Jumpscare does not end, or brings the power back by itself")
 game.player.position=Vector3(-15.65,0,-5.75);game.player.rotation.y=0
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var eye: Vector3=game.player.camera.global_position;var aim:=Vector3(-15.65,1.05,-6.55)
 game.player.camera.rotation=Vector3(atan2(aim.y-eye.y,Vector2(aim.x-eye.x,aim.z-eye.z).length()),0,0)
 await game.get_tree().physics_frame
 verify.call(game._target()=="power_lever","Main breaker cannot be aimed at from in front of the cabinet")
 game._interact_target("power_lever")
 verify.call(power.phase=="restoring","Throwing the breaker does nothing")
 for i in range(90):power.step(dt,true,game.player)
 verify.call(power.phase=="resolved" and not game.world.red_locked() and not game.world.passages.red_locked,"Power returns but red stays locked")
 verify.call(power.lights.all(func(light):return not is_instance_valid(light) or light.visible==power.light_visible[power.lights.find(light)]),"Lights do not come back after the breaker")
 verify.call(game.world.party.enabled,"Party mode that was running does not come back with the power")
 var saved:=power.serialize()
 game._build_world(PowerBlackout.ID);power=game.world.blackout;power.set_process(false)
 game.world.passages.restore({});power.restore(saved)
 verify.call(power.phase=="resolved" and not game.world.red_locked(),"Reload after the fix locks red again")
 game.state.current="none";game._build_world("none")
 verify.call(not game.world.blackout.enabled and not game.world.red_locked(),"Normal round is affected by the blackout")
