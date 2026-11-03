extends RefCounted

func run(g: Node3D,verify: Callable) -> void:
 g._new_shift();g.intro.skip();g.player.active=false
 var party: HappylandParty=g.world.party;var track=HappylandParty.TRACK
 verify.call(absf(party.audio.stream.get_length()-track.DURATION)<.1,"Lighting duration does not match the actual recording")
 verify.call(track.DURATION>270 and track.BASS.size()==track.ENERGY.size(),"New recording or bass envelope is missing")
 verify.call(party.audio.stream.loop and not party.enabled,"Music does not loop or starts without using the switch")
 verify.call(HappylandParty.MUSIC_CREDIT.contains("Rolling Acid") and HappylandParty.MUSIC_CREDIT.contains("Suno"),"Party credit still refers to the replaced recording")
 party.set_enabled(true)
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 for section in range(track.DROPS.size()):
  var start: float=track.DROPS[section];var end: float=track.DROP_ENDS[section]
  var kick: float=track.BEATS.filter(func(t):return t>start+1.)[0]
  party.evaluate(start-.25,true)
  verify.call(not party.drop and party.buildup>.7,"Pre-drop build is missing in section "+str(section))
  party.evaluate(kick,false)
  verify.call(party.drop and party.intensity>.7,"Bass section does not intensify the lights: "+str(section))
  verify.call(party.lamps.all(func(light):return light.light_color!=Color("f4fff8")),"Disabled strobe produces white flashes")
  var flashes:=false
  for beat in track.BEATS:
   if beat<start or beat>end:continue
   party.evaluate(beat+.005,true)
   if party.lamps.any(func(light):return light.light_color==Color("f4fff8")):flashes=true;break
  verify.call(flashes,"No kick-synchronised burst in section "+str(section))
  party.evaluate(end+.15,true)
  verify.call(not party.drop and party.lamps.all(func(light):return light.light_color!=Color("f4fff8")),"Drop effects overrun the recorded section")
 party.evaluate(150,true)
 verify.call(not party.drop and party.intensity<.7,"Breakdown remains in the intense lighting state")
 party.evaluate(0,true)
 verify.call(party.lamps.all(func(light):return is_zero_approx(light.light_energy)),"Lighting flashes at the silent start")
 party.evaluate(track.DURATION-.01,true)
 verify.call(party.intensity<.02,"Lights do not fade at the loop boundary")
 party.evaluate(.5,false);var loop_intensity:=party.intensity
 party.evaluate(track.DURATION+.5,false)
 verify.call(absf(party.clock-.5)<.001 and absf(party.intensity-loop_intensity)<.001,"Lighting drifts on the next loop")
 # Real seeking and looping are checked in the browser with an audio device;
 # Godot's headless Dummy driver does not provide a reliable playback clock.
 g.phase="pause"
 party.tick(.1,false,true,false)
 await g.get_tree().physics_frame
 verify.call(party.audio.stream_paused,"Pause does not suspend the new song")
 g.phase="play"
 party.tick(.1,true,true,false)
 verify.call(not party.audio.stream_paused,"New song does not resume")
 party.set_enabled(false)
 verify.call(not party.audio.playing and party.lamps.all(func(light):return light.light_energy==0),"Switch leaves the new song or lights active")
