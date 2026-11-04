extends RefCounted

func press(g: Node3D) -> void:
 var event:=InputEventAction.new();event.action="interact";event.pressed=true;g._unhandled_input(event)
 g.player.hands.tick(2.,true)

func run(g: Node3D,verify: Callable) -> void:
 g.party_reboot_until=0;g.world.party.reboot_until=0
 g._new_shift();g.intro.skip();g.player.active=false
 var party: HappylandParty=g.world.party
 var point:=party.control.global_position
 verify.call(point.distance_to(g.world.chalk.global_position)<2.2,"Party switch is not beside the chalkboard")
 verify.call(point.x>19 and point.z< -12.5,"Party switch is outside the costume room")
 var switches: Array=g.world.find_children("*","StaticBody3D",true,false).filter(func(body):return body.get_meta("interaction","")=="party_control")
 verify.call(switches.size()==1,"An old or duplicate party switch remains")
 g.player.position=Vector3(-11.49,0,-3.48);g.player.rotation.y=-PI/2;g.player.camera.rotation=Vector3(-.18,0,0)
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 verify.call(g._target()!="party_control","Maintenance room still has a party interaction")
 g.player.position=Vector3(18.52,.2,-13.25);g.player.rotation.y=-PI/2;g.player.camera.look_at(point)
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 verify.call(g._target()=="party_control","New switch is obstructed or faces into the wall")
 verify.call(party.control_prompt()=="E · Partymodus einschalten" and party.reboot_remaining()==0,"Unused switch begins locked")
 press(g);await g.get_tree().physics_frame;await g.get_tree().physics_frame
 verify.call(party.enabled and party.audio.playing and party.reboot_remaining()==0,"First press does not start music or locks the off button")
 verify.call(party.control_prompt()=="E · Partymodus ausschalten","Active party cannot be switched off")
 press(g)
 var deadline:=party.reboot_until
 verify.call(not party.enabled and not party.audio.playing and party.reboot_remaining()>=899,"Switching off does not begin a 15-minute restart")
 for i in range(12):press(g)
 verify.call(not party.enabled and not party.audio.playing and party.reboot_until==deadline,"Repeated presses restart music or extend the lockout")
 party.tick(.01,false,true,false)
 verify.call(party.status.text.begins_with("NEUSTART ") and party.led.emission==Color("ffb94f"),"Restart has no visible status and amber indicator")
 AfterPlayLanguage.choose("en");party.tick(.01,false,true,false)
 verify.call(party.status.text.begins_with("RESTART ") and AfterPlayLanguage.t(party.control_prompt()).begins_with("System restarting"),"Restart countdown does not translate")
 AfterPlayLanguage.choose("de");party.tick(.01,false,true,false)
 verify.call(party.status.text.begins_with("NEUSTART "),"Restart label remains English after changing back")
 var saved=JSON.parse_string(g._persistent_text(g.SAVE))
 verify.call(int(saved.get("party_reboot_until",0))==deadline,"Save omits the reboot deadline")
 g._save(true);g._build_world("none");g._resume();g.player.active=false;party=g.world.party
 verify.call(party.reboot_until==deadline and not party.interact(),"Round rebuild bypasses the cooldown")
 g.has_session=false;g._continue();g.player.active=false;party=g.world.party
 verify.call(party.reboot_until==deadline and not party.interact(),"Reloading the patrol bypasses the cooldown")
 g._new_shift();g.intro.skip();g.player.active=false;party=g.world.party
 verify.call(party.reboot_until==deadline and not party.interact(),"Starting a new shift bypasses the cooldown")
 # Advance the stored deadline past the boundary, without waiting 15 minutes.
 g.party_reboot_until=int(Time.get_unix_time_from_system())-1;party.reboot_until=g.party_reboot_until
 party.tick(.01,false,true,false)
 verify.call(party.status.text=="AUS" and party.reboot_remaining()==0,"Expired restart stays blocked")
 verify.call(party.interact() and party.enabled,"Switch is not usable after expiry")
 verify.call(party.interact() and not party.enabled and party.reboot_remaining()>=899,"The next on/off cycle has no fresh cooldown")
 party.reboot_until=0;g.party_reboot_until=0;g._save()
