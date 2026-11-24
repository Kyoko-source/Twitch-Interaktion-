extends RefCounted

# 5.3.0: room moods (scripts/room_mood.gd), the follower between the scares
# (scripts/night_follower.gd) and the sparkle fix on the kitchen clown's cap.
func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var w: PlayWorld=game.world
 var mood: RoomMood=w.mood
 verify.call(mood!=null and w.follower!=null,"Room mood or follower is missing from the world")
 if mood==null or w.follower==null:return
 if OS.has_feature("web"):
  verify.call(mood.accents.is_empty() and mood.beams.is_empty(),"Web build got the Forward+ room moods")
  return
 verify.call(mood.accents.size()==RoomMood.LIGHTS.size(),"Not every room accent light was built")
 var rooms:={}
 for spec in RoomMood.LIGHTS:rooms[spec.room]=true
 verify.call(rooms.size()>=10,"Some rooms have no light mood of their own")
 verify.call(mood.hazes.size()==(RoomMood.HAZE.size() if mood.advanced else 0),"Room haze volumes do not match the renderer")
 # No red accent in a normal round: red ceiling light is the anomaly "lights_red".
 var reds:=RoomMood.LIGHTS.filter(func(s):var c:=Color(s.color);return c.s>.45 and (c.h<.04 or c.h>.94))
 verify.call(reds.is_empty(),"A room accent is red and would look like the red-light anomaly: "+str(reds.map(func(s):return s.room)))
 verify.call(mood.accents.all(func(a):return not a.light.shadow_enabled),"Accent lights cast shadows (too expensive)")
 # 5.3.1: no lamp-less light glowing in the haze; flickering lights have a lamp.
 verify.call(mood.accents.all(func(a):return a.light.light_volumetric_fog_energy==0.),"An accent light glows in the haze without a lamp")
 verify.call(mood.accents.filter(func(a):return a.spec.motion in ["tube","neon"]).all(func(a):return a.tube!=null),"A flickering accent light has no lamp")
 # 5.6.1: every ceiling batten sits right under the real ceiling, not in the
 # air below it and not inside a wall.
 var loose:=[]
 for batten: Node3D in mood.get_children().filter(func(n):return str(n.name).begins_with("MoodBatten") and n is Node3D):
  var spec_row: Array=RoomMood.LIGHTS.filter(func(s):return "MoodBatten_"+str(s.room).replace(" ","")==str(batten.name) and s.motion in ["tube","neon"])
  if spec_row.is_empty() or spec_row[0].has("wall"):continue
  var p:=batten.global_position
  var hit: Dictionary=w.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,1.4,p.z),Vector3(p.x,6.,p.z)))
  if hit.is_empty() or absf(float(hit.position.y)-p.y)>.1:loose.append([batten.name,p.y,hit.get("position",Vector3.ZERO).y if not hit.is_empty() else -1.])
 verify.call(loose.is_empty(),"A ceiling batten does not sit under the ceiling: "+str(loose))
 # Anomalies keep their meaning.
 w.set_anomaly("party_dark");mood.tick(.1,true)
 verify.call(mood.accents.filter(func(a):return a.spec.get("party",false)).all(func(a):return a.light.light_energy==0.),"Party accents stay on when the party lights fail")
 w.set_anomaly("lights_red");mood.tick(.1,true)
 verify.call(mood.accents.filter(func(a):return not a.spec.get("outdoor",false) and not a.spec.get("sign",false)).all(func(a):return a.light.light_color==Color("e22c28")),"Accents ignore the red-light anomaly")
 w.set_anomaly("cold_breath");mood.tick(.1,true)
 verify.call(mood.accents.filter(func(a):return a.spec.get("kitchen",false)).all(func(a):return a.light.light_energy==0.),"Warm kitchen accents fight the cold-breath anomaly")
 w.set_anomaly("none");mood.tick(.1,true)
 verify.call(mood.accents.all(func(a):return a.on and a.light.light_color==a.color),"Accents do not return to normal in a normal round")
 # Blackout: indoor accents go dark, street and lot light stay.
 w.blackout._collect()
 var indoor:=mood.accents.filter(func(a):return not a.spec.get("outdoor",false)).map(func(a):return a.light)
 verify.call(indoor.all(func(l):return l in w.blackout.lights),"Indoor accents keep burning in the blackout")
 verify.call(mood.beams.all(func(b):return b not in w.blackout.lights),"Car headlights from outside die with the venue power")
 # Moving light: pendants swing, a passing car sweeps through the window.
 var before: Array=mood.swings.map(func(s):return s.pivot.rotation)
 for i in range(30):mood.tick(.05,true)
 verify.call(mood.swings.size()==(w.look.pendants.size() if w.look else 0) and (mood.swings.is_empty() or mood.swings.map(func(s):return s.pivot.rotation)!=before),"The hall pendants do not swing")
 mood.headlights(Vector3(-11.6,2,1.7))
 verify.call(mood.sweep>=0 and mood.beams[0].visible,"A passing car throws no headlights")
 var lit:=false
 for i in range(30):
  mood.tick(.05,true);lit=lit or mood.beams[0].light_energy>10.
 for i in range(80):mood.tick(.05,true)
 verify.call(lit and mood.sweep<0 and not mood.beams[0].visible,"Headlight sweep does not light up and end")
 # The follower walks behind the guard on the guard's own path.
 var f: NightFollower=w.follower;var p: NightGuard=game.player
 f.reset();f.wait=999.
 p.global_position=Vector3(-1,0,8);p.rotation.y=0.;p.camera.rotation=Vector3.ZERO
 # Walk a stretch first, as in a round: the follower needs a path behind you.
 for i in range(120):
  p.global_position+=Vector3(0,0,-.05);p.velocity=Vector3(0,0,-1.5);f.tick(.033,true,p)
 f.last_kind="follow";f.state="follow";f.gap=4.;f.steps_played=0
 var step_ok:=true
 for i in range(60):
  p.global_position+=Vector3(0,0,-.05);p.velocity=Vector3(0,0,-1.5)
  f.tick(.033,true,p)
  if f.step.playing and f.steps_played>0:
   var offset:=f.step.position-p.global_position
   step_ok=step_ok and offset.z>.8 and offset.z<6.
 verify.call(f.steps_played>=2 and step_ok,"Follower steps are not behind the guard: %d steps"%f.steps_played)
 # Stop: one step too many.
 var count:=f.steps_played;p.velocity=Vector3.ZERO
 for i in range(20):f.tick(.033,true,p)
 verify.call(f.steps_played==count+1,"Follower does not take one step too many when the guard stops")
 # Turn round: gone.
 p.rotation.y=PI;f.tick(.033,true,p)
 verify.call(f.state=="idle" and f.caught==1,"Follower keeps walking when the guard turns round")
 # Never turned round: it closes in, breathes behind you, the torch stutters.
 p.rotation.y=0.;f.state="follow";f.gap=1.3;f.steps_played=1
 for i in range(40):
  p.global_position+=Vector3(0,0,-.05);p.velocity=Vector3(0,0,-1.5);f.tick(.033,true,p)
  if f.state=="idle":break
 verify.call(f.closed==1 and f.breath.playing,"Follower never closes in")
 # Door bangs shut behind the guard.
 f.state="door";f.pending=.05;f.tick(.1,true,p)
 verify.call(f.doors==1 and f.thud.playing and (f.thud.position-p.global_position).z>3.,"No door bangs shut behind the guard")
 # Pause freezes it.
 # A sound paused in the frame it started keeps playing in Godot; one frame on.
 await game.get_tree().process_frame
 f.tick(.1,false,p)
 verify.call(f.thud.stream_paused,"Follower sounds keep playing in the pause")
 f.stop_all();f.reset()
 verify.call(f.wait>=35. and f.state=="idle","A new round does not reset the follower")
 # Kitchen clown cap: no pow() on a value that can reach zero (NaN sparkle).
 var code:=Array(FileAccess.get_file_as_string("res://assets/clown-v404/patched-cap.gdshader").split("
")).filter(func(l):return not l.strip_edges().begins_with("//"))
 verify.call(not "
".join(code).contains("pow(") ,"Clown cap shader uses pow() again (NaN sparkle under the hood)")
 for path in ["res://assets/atmosphere-v320/floor.gdshader","res://assets/atmosphere-v320/patinated.gdshader","res://assets/craft-v340/service-wear.gdshader","res://assets/restoration-v350/wrapping-paper.gdshader","res://assets/revamp-v300/weathered.gdshader"]:
  verify.call(not FileAccess.get_file_as_string(path).contains("pow(abs("),"pow(abs()) can produce NaN sparkle in "+path.get_file())
 # 5.3.1: the crawler takes the floor and tube scenes; the jumpscare screen.
 for id in ["kitchen_floor_crawler","tube_chase"]:
  game._build_world(id)
  var t: NightTerrors=game.world.terrors
  verify.call(t.visual!=null and t.visual.has_meta("crawler") and ResourceLoader.exists(CharacterFinish.CRAWLER),"The crawler does not play "+id)
 game._build_world("snackbar_visitor")
 verify.call(not game.world.terrors.visual.has_meta("crawler"),"A standing visitor scene got the crawler")
 var fx: JumpscareFX=game.jumpscare
 verify.call(fx!=null and JumpscareFX.current==fx,"The jumpscare screen is missing")
 if fx:
  var cam: Camera3D=game.player.camera
  fx.stop();JumpscareFX.fire(1.,0.)
  var flash_seen:=false
  for i in range(10):
   fx.tick(.016,true,cam,{"strobe":true,"motion":true});flash_seen=flash_seen or float(fx.material.get_shader_parameter("flash"))>.3
  verify.call(fx.running() and fx.rect.visible and flash_seen and absf(cam.h_offset)+absf(cam.v_offset)>0.,"A jumpscare does not take over the screen")
  fx.tick(.5,false,cam,{});var frozen:=fx.clock
  fx.tick(.5,false,cam,{})
  verify.call(fx.clock==frozen,"The jumpscare runs on in the pause")
  for i in range(100):fx.tick(.016,true,cam,{"strobe":true,"motion":true})
  verify.call(not fx.running() and not fx.rect.visible and cam.h_offset==0. and cam.v_offset==0.,"The jumpscare does not end cleanly")
  # Photosensitivity and motion settings are respected.
  JumpscareFX.fire(1.,0.);var flashed:=false;var shaken:=false
  for i in range(20):
   fx.tick(.016,true,cam,{"strobe":false,"motion":false})
   flashed=flashed or float(fx.material.get_shader_parameter("flash"))>0.;shaken=shaken or cam.h_offset!=0.
  verify.call(not flashed and not shaken,"Jumpscare flashes or shakes with strobe and motion turned off")
  fx.stop()
 print("Mood checks done: ",mood.accents.size()," accents, ",mood.swings.size()," pendants")
