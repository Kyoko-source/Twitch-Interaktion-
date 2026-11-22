extends RefCounted

# 5.2.7: ambient life (scripts/ambient_life.gd).
func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var life: AmbientLife=game.world.ambient
 verify.call(life!=null,"Ambient life is missing from the world")
 if life==null:return
 var files:={}
 for spec in AmbientLife.BEDS:files[spec.file]=true
 for key in AmbientLife.POOLS:
  for file in AmbientLife.POOLS[key].files:files[file]=true
 var missing:=files.keys().filter(func(f):return not ResourceLoader.exists(AmbientLife.ROOT+f+".ogg"))
 verify.call(missing.is_empty(),"Ambient sounds are missing: "+str(missing))
 # Every shipped edit is a documented CC0 recording.
 var provenance=JSON.parse_string(FileAccess.get_file_as_string(AmbientLife.ROOT+"provenance.json"))
 var documented:={}
 if provenance is Array:
  for row in provenance:
   if row.get("license","")=="CC0-1.0" and str(row.get("source","")).begins_with("https://freesound.org/"):documented[str(row.file).get_basename()]=true
 verify.call(files.keys().all(func(f):return documented.has(f)),"An ambient sound has no CC0 provenance")
 verify.call(life.beds.size()==AmbientLife.BEDS.size() and life.beds.all(func(s):return s.stream.loop),"Room tones do not loop")
 var routed:=life.sources().all(func(s):return game.world.acoustics.records.any(func(r):return r.source==s))
 verify.call(routed,"Ambient sources bypass the room acoustics (walls would not muffle them)")
 var powered:=life.beds.filter(func(s):return s.has_meta("machinery_file"))
 # The blackout gathers its mains-powered sources when the power cuts.
 game.world.blackout._collect()
 verify.call(powered.size()>=6 and powered.all(func(s):return s in game.world.blackout.hums),"Mains-powered hums keep running in the blackout")
 # Plays while patrolling, pauses with the game.
 game._resume();await game.get_tree().process_frame
 for i in range(5):life.tick(.1,true,game.player)
 verify.call(life.beds.all(func(s):return s.playing and not s.stream_paused),"Room tones are not playing on patrol")
 for i in range(3):await game.get_tree().process_frame
 game._pause()
 for i in range(2):await game.get_tree().process_frame
 var unpaused:=life.beds.filter(func(s):return not s.stream_paused).map(func(s):return [s.name,s.playing])
 verify.call(unpaused.is_empty(),"Room tones do not pause with the game: "+str(unpaused))
 game._resume()
 # The scheduler: variety, cooldowns, earshot, and no influence on the patrol.
 var rng_before:=str(game.state.rng.state);var seen:={};var cooldown_ok:=true;var reach_ok:=true;var last_at:={}
 var spots:=[Vector3(0,1.6,4),Vector3(10,1.6,-6),Vector3(-12,1.6,-31),Vector3(22,1.6,8),Vector3(-13,1.6,8.5),Vector3(-7.9,1.6,-20)]
 for i in range(1200):
  life.clock+=3.
  var at: Vector3=spots[i%spots.size()]
  var file:=life.cue(at)
  if file.is_empty():continue
  seen[file]=true
  for key in AmbientLife.POOLS:
   var pool: Dictionary=AmbientLife.POOLS[key]
   if file in pool.files:
    if last_at.has(file) and life.clock-float(last_at[file])<float(pool.cooldown):cooldown_ok=false
    var voice: AudioStreamPlayer3D=life.voices[(life.voice_index-1+life.voices.size())%life.voices.size()]
    if voice.position.distance_to(at)>float(pool.reach)+1.:reach_ok=false
  last_at[file]=life.clock
 verify.call(seen.size()>=30,"Ambient life repeats too few sounds: "+str(seen.size()))
 verify.call(cooldown_ok,"An ambient sound repeats inside its cooldown")
 verify.call(reach_ok,"An ambient sound plays out of earshot")
 verify.call(str(game.state.rng.state)==rng_before,"Ambient life consumes the anomaly random stream")
 life.stop_all()
 print("Ambient life sample: ",seen.size()," different sounds")
