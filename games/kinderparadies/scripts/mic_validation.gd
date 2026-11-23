extends RefCounted

# 5.4.0: microphone mode (scripts/mic_listener.gd, scripts/mic_warden.gd), the
# godless face scare, the jumpscare stings and the balloon pops.
func run(game: Node3D,verify: Callable) -> void:
 verify.call(game.DEFAULT_SETTINGS.mic==false,"Microphone mode is on by default")
 var warden: MicWarden=game.mic_warden
 verify.call(warden!=null and game.mic!=null,"Microphone listener or warden is missing")
 if warden==null:return
 # Settings tab: switch, sensitivity, level meter and the "not an anomaly" note.
 if MicListener.supported():
  game._settings("menu");NightMenus.settings(game,"Mikrofon")
  var texts:=""
  for l: Label in game.menu.find_children("*","Label",true,false):texts+=l.text+"\n"
  var switch:=false
  for b: CheckButton in game.menu.find_children("*","CheckButton",true,false):switch=switch or b.text==AfterPlayLanguage.t("Mikrofon-Modus")
  verify.call(switch,"Microphone tab has no on/off switch")
  verify.call("KEINE Anomalie" in texts or "NOT an anomaly" in texts,"Microphone tab does not explain that the creature is not an anomaly")
  verify.call(game.menu.find_child("MicLevelMeter",true,false)!=null,"Microphone tab has no level meter")
  game._return_from_panel()
 for line in MicWarden.TEXTS+[MicWarden.NOTE,"Du hast es geweckt.","Mikrofon-Modus","MIKROFON","ZU LAUT"]:
  if line!="":verify.call(AfterPlayLanguage.messages.has(line),"Microphone text has no English version: "+line)

 game._new_shift();game.intro.skip();game.set_process(false)
 game.phase="play";game.player.active=true
 var original: Dictionary=game.settings.duplicate(true)
 game.settings.mic=true;game.settings.mic_sensitivity=.5
 game.mic.enabled=true
 warden.reset()
 var quiet:=func(seconds: float):
  game.mic.inject(-70.)
  var t:=0.
  while t<seconds:warden.tick(.1,true);t+=.1
 var shout:=func(seconds: float):
  game.mic.inject(-6.)
  var t:=0.
  while t<seconds:warden.tick(.05,true);t+=.05
  game.mic.inject(-70.)
 quiet.call(2.)
 verify.call(warden.strikes==0,"Silence counts as noise")
 verify.call(warden.hud.visible,"The microphone level is not on screen during the shift")
 warden.tick(.05,false)
 verify.call(not warden.hud.visible,"The microphone level stays on screen in the pause")
 var streak: int=game.state.streak
 var first_round:=warden.threshold();game.state.streak=6;var later:=warden.threshold();game.state.streak=streak
 verify.call(later<first_round-5.,"It does not get more sensitive round by round")
 game.mic.inject(warden.threshold()+3.);warden.tick(.05,true)
 verify.call(warden.hud_fill.color==Color("ff2a2a") and warden.hud_red.size.x>0.,"The meter does not show the red zone")
 quiet.call(1.)
 shout.call(.4);quiet.call(1.)
 verify.call(warden.strikes==0,"A short sound already counts as too loud")
 # First time: every lamp flickers, red warning, "not an anomaly".
 shout.call(.9)
 verify.call(warden.strikes==1 and warden.title.visible and warden.title.text==AfterPlayLanguage.t(MicWarden.TEXTS[1]) and warden.note.visible,"First time too loud shows no warning")
 var dark_seen:=false
 for i in range(20):
  warden.tick(.05,true)
  for light in warden.lights:dark_seen=dark_seen or (is_instance_valid(light) and not light.visible)
 verify.call(not warden.lights.is_empty() and dark_seen,"Lamps do not flicker on the warning")
 quiet.call(3.)
 var hidden:=0
 for light: Light3D in game.world.find_children("*","Light3D",true,false):
  if not light.has_meta("outdoor") and not light.visible:hidden+=1
 verify.call(warden.lights.is_empty() and not warden.title.visible,"Lamps or warning stay after the flicker")
 # The cooldown swallows the rest of the same scream.
 shout.call(4.)
 verify.call(warden.strikes==1,"One long scream counts more than once")
 quiet.call(11.)
 shout.call(.9)
 verify.call(warden.strikes==2 and warden.title.text==AfterPlayLanguage.t(MicWarden.TEXTS[2]) and warden.scream.playing,"Second time too loud does not scream")
 # Three calm minutes take one step back.
 quiet.call(181.)
 verify.call(warden.strikes==1,"Calm does not let it fall back asleep")
 game.settings.mic=false;shout.call(2.)
 verify.call(warden.strikes==1,"Microphone noise counts while the mode is off")
 game.settings.mic=true;quiet.call(11.);shout.call(.9);quiet.call(11.)
 verify.call(warden.strikes==2,"Strike count lost")
 # Third time: rage, silence, whisper behind, slow turn, nothing, the face.
 var streak_before: int=game.state.streak
 var yaw: float=game.player.rotation.y
 shout.call(.9)
 verify.call(warden.stage=="rage" and game.phase=="mic_death" and not game.player.active,"Third time does not wake it")
 var seen:={}
 var whisper_behind:=false
 var turned:=0.
 var face_seen:=false
 var t:=0.
 while warden.stage not in ["done","idle"] and t<30.:
  warden.tick(.05,false);game.jumpscare.tick(.05,true,game.player.camera,game.settings);t+=.05
  seen[warden.stage]=true
  if warden.stage=="whisper" and warden.whisper:whisper_behind=warden.whisper.position.z>.2 and warden.whisper.get_parent()==game.player.camera
  if warden.stage=="still":turned=absf(angle_difference(yaw,game.player.rotation.y))
  if warden.stage=="scare" and game.jumpscare.godless:face_seen=face_seen or float(game.jumpscare.material.get_shader_parameter("face"))>.9
 for stage in ["rage","silence","whisper","turn","still","scare"]:verify.call(seen.has(stage),"The final scare skips: "+stage)
 verify.call(whisper_behind,"The whisper does not come from behind")
 verify.call(turned>PI*.95,"The guard does not turn round")
 verify.call(face_seen,"The godless face does not fill the screen")
 var wait:=0
 while game.phase!="arrival" and wait<600:
  await game.get_tree().process_frame;wait+=1
 verify.call(game.phase=="arrival" and game.state.streak==0 and warden.strikes==0 and warden.stage=="idle","Waking it does not lose the night (streak before: %d)"%streak_before)
 verify.call(warden.silenced.is_empty() and not warden.title.visible,"Silence or warning leaks into the next night")
 game.jumpscare.stop()
 # Jumpscare stings: one per scare, never twice in a row.
 var before:=ScareBank.sting_count
 ScareBank.sting_at=-10.;ScareBank.sting();var first:=ScareBank.last_sting;ScareBank.sting()
 verify.call(ScareBank.sting_count==before+1,"Two stings for one scare")
 ScareBank.sting_at=-10.;ScareBank.sting()
 verify.call(ScareBank.last_sting!=first and ResourceLoader.exists(ScareBank.STING_ROOT%ScareBank.last_sting),"Sting repeats or is missing")
 for i in range(1,ScareBank.STINGS+1):verify.call(ResourceLoader.exists(ScareBank.STING_ROOT%i),"Missing jumpscare sting %d"%i)
 verify.call(ResourceLoader.exists(ScareBank.BALLOON_BURST),"Balloon burst sound is missing")
 game.mic.release_injection();game.mic.enabled=false
 game.settings=original;game._apply_settings();game.set_process(true);game.player.active=false
 print("Microphone checks done")
