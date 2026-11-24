extends RefCounted

# 5.7.0: the After Play tutorial. Normal round, anomaly round with the floating
# rabbit, three wrong doors (text, arrows, the uninstall picture), no saving.
func run(game: Node3D,verify: Callable) -> void:
 var tree:=game.get_tree()
 game._main_menu()
 var entry: Button=game.menu.find_children("MainMenuAction*","Button",true,false).filter(func(b):return b.text=="Tutorial").front() if game.menu.find_children("MainMenuAction*","Button",true,false).any(func(b):return b.text=="Tutorial") else null
 verify.call(entry!=null,"The main menu has no Tutorial entry")
 NightMenus.tutorials(game)
 var ap: Button=game.menu.find_child("Tutorial_after_play",true,false)
 var party: Button=game.menu.find_child("Tutorial_zombies",true,false)
 var watch: Button=game.menu.find_child("Tutorial_nightwatch",true,false)
 verify.call(ap!=null and not ap.disabled and party!=null and party.disabled and watch!=null and watch.disabled,"Tutorial menu: After Play must start, Partynacht and Nightwatch must be greyed out")
 # Nothing is saved while the tutorial runs.
 var before: String=game._persistent_text(game.SAVE)
 ap.pressed.emit()
 var t: AfterPlayTutorial=game.tutorial
 verify.call(t.active and game.phase=="arrival" and not game.has_session,"The tutorial does not start in the lift")
 game.intro.skip();await tree.process_frame
 verify.call(game.phase=="play" and t.title.text=="Willkommen zu After Play" and t.box.visible and game.round_label.text=="TUTORIAL","The tutorial greeting is missing")
 verify.call(t.title.get_theme_color("font_color")==AfterPlayTutorial.PURPLE and t.title.get_theme_font_size("font_size")>=70,"The tutorial text is not big and purple")
 verify.call(t.body.text.contains("grüne Tür"),"The first tutorial text does not send you to the green door")
 t.tick(12.,true)
 verify.call(t.reminder.visible and t.reminder.text.contains("GRÜNE"),"No reminder stays after the big text")
 # No scares and no ambush at the wrong door.
 verify.call(game.world.passages!=null,"No doors")
 game._door_death(false);verify.call(game.phase=="play","A wrong door kills in the tutorial")
 # Red in the normal round: back to the start, no anomaly.
 game.phase="lift";game._finish_lift(true)
 verify.call(t.step=="normal" and game.phase=="arrival","Red door in the normal round does not send you back")
 game.intro.skip();await tree.process_frame
 verify.call(t.title.text=="Hier war doch alles normal","No hint after the red door in a normal round")
 # Green: the anomaly round, the big rabbit floats.
 game.phase="lift";game._finish_lift(false)
 verify.call(t.step=="anomaly" and game.phase=="arrival","The green door does not start the anomaly round")
 game.intro.skip();await tree.process_frame
 t.tick(.1,true)
 verify.call(t.snapshot().rabbit_float>.8 and t.rabbit==game.world.polish.party_mascot,"The big rabbit does not float")
 verify.call(t.title.text.contains("Anomalie") and t.body.text.contains("rote Tür"),"The anomaly round does not send you to the red door")
 # Wrong door once: in front of the rabbit, the guide repeats itself.
 game.phase="lift";game._finish_lift(false)
 await _until(tree,func():return game.phase=="play")
 verify.call(t.wrong==1 and game.player.global_position.distance_to(AfterPlayTutorial.RABBIT_VIEW)<.5 and t.title.text.begins_with("Vielleicht") and t.body.text.contains("ROTE TÜR"),"The first wrong door does not repeat the hint in front of the rabbit")
 verify.call(t.rabbit!=null and t.arrows.is_empty(),"Rabbit or arrows wrong after the first wrong door")
 # Twice: blinking arrows to the red door.
 game.phase="lift";game._finish_lift(false)
 await _until(tree,func():return game.phase=="play")
 verify.call(t.wrong==2 and t.title.text=="Oh man …" and t.body.text.contains("13 Runden"),"The second wrong door has no 'oh man'")
 verify.call(t.arrows.size()>=20 and t.arrows.all(func(a):return a.is_inside_tree()),"No arrows to the red door")
 var states:={}
 for i in range(20):
  t.tick(.07,true);states[t.arrows[0].visible]=true
 verify.call(states.size()==2,"The arrows do not blink")
 var tip: Node3D=t.arrows[0];var aim: Vector3=tip.global_basis.y.normalized()
 verify.call(aim.dot(Vector3.DOWN)>.95,"The arrows above the door do not point down at it")
 # Three times: the uninstall picture, then the main menu.
 game.phase="lift";game._finish_lift(false)
 verify.call(game.phase=="tutorial_end" and t.snapshot().give_up and t.screen.find_child("TutorialGiveUpBack",true,false)!=null,"The third wrong door shows no uninstall picture")
 var rings:=t.screen.find_children("*","Panel",true,false).filter(func(p):var s=p.get_theme_stylebox("panel");return s is StyleBoxFlat and s.border_color==Color("e3261b") and s.bg_color.a==0.)
 verify.call(rings.size()==4,"The uninstall picture does not circle four steps in red")
 (t.screen.find_child("TutorialGiveUpBack",true,false) as Button).pressed.emit()
 verify.call(game.phase=="menu" and not t.active and not t.visible,"The uninstall picture does not lead back to the main menu")
 # The right way: green, then red.
 game._start_tutorial();game.intro.skip();await tree.process_frame
 game.phase="lift";game._finish_lift(false);game.intro.skip();await tree.process_frame
 game.phase="lift";game._finish_lift(true)
 verify.call(game.phase=="tutorial_end" and t.title.text=="Richtig!","The red door in the anomaly round is not praised")
 game._main_menu()
 verify.call(not t.active and game.phase=="menu" and not game.transition_shade.visible,"Leaving the tutorial leaves something behind")
 verify.call(game._persistent_text(game.SAVE)==before and not game.has_session,"The tutorial touched the shift save")
 print("Tutorial checks done")

func _until(tree: SceneTree, done: Callable, seconds: float=4.) -> void:
 var end:=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<end:
  if done.call():return
  await tree.process_frame
