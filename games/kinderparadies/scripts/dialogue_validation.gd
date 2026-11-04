extends RefCounted

func run(g: Node3D,verify: Callable) -> void:
 g._new_shift();g.intro.skip();g.set_process(false);g.player.active=false
 var d: GuardDialogue=g.dialogue
 verify.call(d.catalog.size()==13,"Author's document does not have all thirteen scenes")
 for id in d.catalog:
  verify.call(d.catalog[id].de.size()==d.catalog[id].en.size(),"Missing English comment paragraphs: "+id)
 d.reset();verify.call(d.request("reel") and not d.request("reel"),"One-time comment can queue twice")
 d.tick(.01);verify.call(d.current=="reel" and d.text.typed>0 and d.ui.visible,"Requested comment does not type on screen")
 var typed:=d.text.typed;g.phase="pause";d.tick(5.)
 verify.call(d.text.typed==typed and not d.ui.visible and not d.typing.playing,"Typing does not pause")
 g.phase="play"
 for i in range(420):d.tick(1./60.)
 verify.call(d.letters.emitted>0,"Typed letters never become physical scene glyphs")
 verify.call(d.letters.letters.all(func(r):return r.node is Label3D and r.node.get_child_count()==0),"Falling letters add physics bodies or scripted clutter")
 var emitted:=d.letters.emitted
 var saved:=d.serialize();d.restore(saved)
 verify.call(d.seen.has("reel") and not d.request("reel"),"Continue repeats an already seen scene")
 g._save();var persistent=JSON.parse_string(g._persistent_text(g.SAVE))
 verify.call(persistent.dialogue.seen.has("reel"),"Save does not remember delivered comments")
 d.reset();verify.call(d.request("reel"),"A new game does not rearm comments")
 d.pending.clear();d.current="";d.seen.clear();d.arrival_armed=false
 g.player.position=Vector3(-7.,0,4.);d.idle_anchor=g.player.position
 d.observe(59.9);verify.call(not d.seen.has("idle"),"Idle comment triggers before 60 seconds")
 d.observe(.2);verify.call(d.seen.has("idle"),"Idle comment never triggers")
 d.reset();d.arrival_armed=false;g.player.position=Vector3(-7.,0,4.);d.idle_anchor=g.player.position;d.observe(35.)
 g.player.position.x+=1.;d.observe(30.);verify.call(not d.seen.has("idle"),"Moving does not reset the idle timer")
 d.reset();d.arrival_armed=false;g.state.streak=6;d.observe(.01);d.observe(.01)
 verify.call(d.pending.count("round7")==1,"Round seven fires every frame")
 g.state.streak=12;d.observe(.01);verify.call(d.pending.count("round13")==1,"Final patrol comment is missing")
 d.reset();g.state.streak=0;g.player.position=Vector3(-8,0,19.35);d.observe(.2)
 verify.call(not d.seen.has("arrival"),"Arrival monologue starts inside the closed lift")
 g.player.position.z=16.9;d.observe(.01);verify.call(d.seen.has("arrival"),"First exit does not trigger the monologue")
 # Real interaction hooks; the archive note has its own line, not the generic newspaper gag.
 d.reset();g._collect_paper("note")
 verify.call(d.seen.has("note") and not d.seen.has("newspaper"),"Door note plays the newspaper gag as well")
 g._interact_target("delivery_exit");g._interact_target("delivery_exit")
 verify.call(d.pending.count("locked")==1,"Locked parking door repeats the same comment")
 d.reset();g._interact_target("film_reel");verify.call(d.seen.has("reel"),"Collecting a reel has no comment")
 d.reset();g.party_reboot_until=0;g.world.party.reboot_until=0;g.world.party.set_enabled(false)
 g._interact_target("party_control");verify.call(d.seen.has("party"),"First successful party press has no comment")
 d.reset();d.arrival_armed=false;g.player.position=Vector3(-7.9,0,-18.75);g.player.camera.look_at(g.world.watch.board.to_global(Vector3(0,0,.15)))
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 d.observe(.7);verify.call(d.seen.has("memories"),"Looking at the actual corridor photowall does not trigger a comment")
 d.reset();d.arrival_armed=false;g.player.position=Vector3(-12.5,0,-31.25);g.player.camera.look_at(g.world.annex.clown.head.global_position)
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 d.observe(.6);verify.call(d.seen.has("cook"),"Seeing the kitchen clown does not trigger a comment")
 # World-space glyphs land and disappear without ever entering a collision layer.
 d.letters.clear();g.player.position=Vector3(-7.,0,4.);g.player.camera.rotation=Vector3.ZERO
 d.letters.release("A",Vector2(960,850),Color.WHITE);d.letters.tick(1.5,true)
 verify.call(d.letters.snapshot().landed==1,"Letters do not settle on the floor")
 var record: Dictionary=d.letters.letters[0]
 verify.call(record.node.billboard==BaseMaterial3D.BILLBOARD_DISABLED and absf(record.node.rotation.x+PI/2)<.001,"Landed letters do not lie flat")
 var time: float=record.time;d.letters.tick(3.,false);verify.call(record.time==time,"Fallen letters age during pause")
 d.letters.tick(6.,true);verify.call(d.letters.letters.is_empty(),"Floor lettering accumulates indefinitely")
 d.reset();g._new_shift();g.intro.skip();g.set_process(true)
