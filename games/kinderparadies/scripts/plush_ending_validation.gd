extends RefCounted

# --plush-ending-only: the secret plush ending (4.10.0), from the first pocketed
# plush to the credits.
func run(game: Node3D, verify: Callable) -> void:
 game._new_shift();game.intro.skip();game._build_world("none");game._resume();game.player.active=false
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var total:=CreatorPlush.PLUSHES.size()
 for id in CreatorPlush.PLUSHES:
  var plush: NightProp=game.world.atmosphere.find_child(CreatorPlush.PLUSHES[id].node,true,false)
  verify.call(plush!=null,id+" plush missing before it was collected")
  if not plush:continue
  game.player.position=plush.global_position+Vector3(.9,-.2,.5);game.player.velocity=Vector3.ZERO
  game.player.look_at(Vector3(plush.global_position.x,game.player.global_position.y,plush.global_position.z),Vector3.UP)
  game.player.camera.look_at(plush.global_position,Vector3.UP)
  await game.get_tree().physics_frame
  game.player.grab_prop()
  verify.call(SecretPlushEnding.plush_id(game.player.carried)==id,id+" plush cannot be picked up")
  game._store_plush()
  await game.get_tree().process_frame
  verify.call(id in game.plushes_found and not is_instance_valid(game.player.carried) and game.world.atmosphere.find_child(CreatorPlush.PLUSHES[id].node,true,false)==null,id+" plush does not go into the inventory with E")
 verify.call(game.plushes_found.size()==total and game.plush_call=="ringing" and game.plush_ending.ringing(),"Five plushes do not make the reception phone ring")
 # A round change keeps them in the inventory and out of the venue.
 game._build_world("none");game._resume();game.player.active=false
 await game.get_tree().process_frame
 var leftovers:=0
 for id in CreatorPlush.PLUSHES:
  if game.world.atmosphere.find_child(CreatorPlush.PLUSHES[id].node,true,false):leftovers+=1
 verify.call(leftovers==0 and game.plush_ending.ringing(),"Collected plushes return to the venue or the phone stops ringing after a round change")
 # Saved and restored with the shift.
 var data:={"plushes":game.plushes_found.duplicate(),"plush_call":"ringing"}
 game._restore_plushes({"plushes":["rosenyan","nonsense","rosenyan"],"plush_call":"answered"})
 verify.call(game.plushes_found==["rosenyan"] and game.plush_call=="","Malformed plush save is accepted")
 game._restore_plushes(data)
 verify.call(game.plushes_found.size()==total and game.plush_call=="ringing","Plush inventory is lost on reload")
 # Answer the call, seat everybody.
 game._interact_target("reception_phone")
 verify.call(game.plush_call=="answered" and not game.plush_ending.ringing() and game.plush_ending.chair_bodies.size()==6,"Answering the phone does not open the six birthday chairs")
 verify.call(game.plush_ending.call_voice.playing and game.plush_ending.call_voice.stream.get_length()>6.,"The girl's voice does not play when the phone is answered")
 var chair: Node3D=game.world.props.chairs.get_child(0)
 game.player.position=chair.global_position+Vector3(-1.15,0,0);game.player.velocity=Vector3.ZERO
 await game.get_tree().physics_frame
 game.player.camera.look_at(chair.global_position+Vector3(0,.6,0),Vector3.UP)
 await game.get_tree().physics_frame
 verify.call(game._target()=="plush_chair:0","A birthday chair cannot be aimed at")
 for i in range(total):game._interact_target("plush_chair:%d"%i)
 verify.call(game.plush_ending.seated.size()==total and game.phase=="secret_finale" and game.plush_ending.running,"Five seated plushes do not start the finale")
 var ending: SecretPlushEnding=game.plush_ending;ending.set_process(false)
 var dt:=1.0/30.0
 for i in range(int(SecretPlushEnding.KIDS_AT/dt)):ending._process(dt)
 verify.call(ending.lifted and ending.restored==SecretPlushEnding.ROOMS.size(),"Not every room gets its shine back")
 verify.call(ending.environment.ambient_light_energy>.5 and ending.environment.adjustment_saturation>1.1,"The venue does not light up")
 for i in range(int((SecretPlushEnding.FADE_AT-SecretPlushEnding.KIDS_AT)/dt)):ending._process(dt)
 var arrived:=ending.children.filter(func(c):return c.leg>=(c.path as Array).size()-1).size()
 verify.call(ending.children.size()==30 and arrived==30,"Thirty children do not come in and reach their places (%d/%d)"%[arrived,ending.children.size()])
 verify.call(game.world.backstage.exit_leaf.rotation.y>1.4,"The entrance door does not open for the children")
 var kinds:={}
 for c in ending.children:kinds[c.finish]=kinds.get(c.finish,0)+1
 verify.call(kinds.get("wade",0)>=4 and kinds.get("crawl",0)>=4,"Children do not spread into the ball pit and the crawl tube")
 var up_high:=ending.children.filter(func(c):return (c.at as Vector3).y>2.).size()
 verify.call(up_high>=4,"No children climb the climbing frames")
 for i in range(int((SecretPlushEnding.DURATION-SecretPlushEnding.FADE_AT+.5)/dt)):ending._process(dt)
 verify.call(ending.done and ending.shade.color.a>.99,"The finale does not fade to black")
 await game.get_tree().process_frame
 verify.call(game.phase=="ending" and game.end_credits.ending_number==4 and game.end_credits.end_title()=="Geheimes Ende","The finale does not roll the secret credits")
 verify.call(game.plushes_found.is_empty() and game.plush_call=="","The plushes are still in the inventory after the ending")
 var credits3:=EndCredits.new();credits3.ending_number=3
 verify.call(credits3.end_title()=="ENDE 3/3","Leaving Happyland is not ENDE 3/3 any more");credits3.free()
 # A new shift (as after a death) loses them.
 game.plushes_found.assign(["jule"]);game._new_shift()
 verify.call(game.plushes_found.is_empty(),"A new shift keeps the plushes")
 game._build_world("none");game._resume()
