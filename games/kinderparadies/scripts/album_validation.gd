extends RefCounted

# 5.2.8: anomaly album (scripts/anomaly_album.gd).
func run(game: Node3D,verify: Callable) -> void:
 var album: AnomalyAlbum=game.anomaly_album
 album.found.clear();album.save()
 verify.call(album.count()==0 and AnomalyAlbum.total()==PatrolState.ANOMALIES.size(),"Album does not start empty or counts the wrong catalogue")
 var missing:=PatrolState.ANOMALIES.filter(func(a):return album.photo(a.id)==null).map(func(a):return a.id)
 verify.call(missing.is_empty(),"Album photos are missing: "+str(missing))
 # Only real catalogue anomalies, each once, with a count of sightings.
 verify.call(not album.record("none") and not album.record("detail") and album.count()==0,"Album accepts rounds without a catalogue anomaly")
 var before: int=game.achievements.queue.size()
 verify.call(album.record("balls_float") and album.count()==1,"A new anomaly does not become a polaroid")
 var announced: bool=game.achievements.toast_head.text=="NEUES POLAROID" or game.achievements.queue.any(func(q):return q is Dictionary and q.get("head","")=="NEUES POLAROID")
 verify.call(announced,"A new polaroid does not announce itself")
 verify.call(not album.record("balls_float") and int(album.found.balls_float.times)==2,"A repeated anomaly is not counted as seen again")
 # The game records correct red doors only.
 game._album_record({"correct":false,"anomaly":true,"id":"lights_red"})
 game._album_record({"correct":true,"anomaly":false,"id":"none"})
 verify.call(not album.found.has("lights_red"),"A wrong door or a normal round fills the album")
 game._album_record({"correct":true,"anomaly":true,"id":"lights_red"})
 verify.call(album.found.has("lights_red"),"A correct red door does not fill the album")
 var shift:=PatrolState.new();shift.start(77)
 while shift.current=="none":shift.decide(false)
 var id:=shift.current;var result:=shift.decide(true)
 verify.call(result.get("id","")==id and result.correct and result.anomaly,"Patrol results do not name the reported anomaly")
 # Survives a restart; milestones unlock.
 for a in PatrolState.ANOMALIES.slice(0,10):album.record(a.id)
 verify.call(game.achievements.has("album_10"),"Ten polaroids do not unlock their achievement")
 var reload:=AnomalyAlbum.new();reload.build(game)
 verify.call(reload.count()==album.count() and int(reload.found.balls_float.times)==2,"The album is not saved")
 # The menu: every anomaly has a card; found ones open a detail view.
 album.show_menu(func():NightMenus.home(game))
 var cards: Array=game.menu.find_children("Polaroid_*","Button",true,false)
 verify.call(cards.size()==AnomalyAlbum.total(),"The album does not show a card per anomaly: "+str(cards.size()))
 var first: Button=game.menu.find_child("Polaroid_balls_float",true,false)
 if first:first.pressed.emit()
 verify.call(game.menu.find_children("*","TextureRect",true,false).any(func(t):return t.texture==album.photo("balls_float")),"Opening a polaroid does not show its photo")
 NightMenus.home(game)
 NightMenus.extras(game)
 verify.call(game.menu.find_child("Extras_anomalies",true,false)!=null and game.menu.find_children("MainMenuAction*","Button",true,false).is_empty(),"Extras has no anomaly album")
 NightMenus.home(game)
 verify.call((game.menu.find_child("MainMenuAction4",true,false) as Button).text=="Extras","The main menu has no Extras entry")
 album.found.clear();album.save()
 DirAccess.remove_absolute(album.path)
 print("Album checks done: ",AnomalyAlbum.total()," polaroids")
