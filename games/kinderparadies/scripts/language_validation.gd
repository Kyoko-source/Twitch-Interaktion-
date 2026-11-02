extends RefCounted

func run(g: Node3D,verify: Callable) -> void:
 var original: Dictionary=g.settings.duplicate(true)
 g._settings("menu");NightMenus.settings(g,"Sprache")
 var choice:=g.menu.find_child("LanguageChoice",true,false) as OptionButton
 verify.call(choice!=null and choice.item_count==2,"Settings do not expose both languages")
 choice.item_selected.emit(1)
 verify.call(g.settings.language=="en" and AfterPlayLanguage.english(),"Selecting English does not apply immediately")
 g.settings.language="de";g._read_settings()
 verify.call(g.settings.language=="en","Language choice does not survive settings reload")
 var sample: Label=g._label("Einstellungen")
 verify.call(sample.text=="Settings" and sample.tr(sample.text)=="Settings","Shared UI still uses German in English mode");sample.free()
 verify.call(AfterPlayLanguage.t("RUNDGANG 03 / 13")=="PATROL 03 / 13","Formatted patrol HUD is untranslated")
 verify.call(AfterPlayLanguage.t("E · Zeitung einsammeln")=="E · Collect Newspaper","Specific collection template loses to generic E template")
 verify.call(AfterPlayLanguage.t("E · Rote Tür – Anomalie")=="E · Red door – Anomaly","Door interaction is not translated recursively")
 var credits:=EndCredits.new();credits.ending_number=3
 verify.call(credits.end_title()=="Secret Ending","Ending card ignores the selected language");credits.free()
 var note: Label=g._label(EndCredits.KYOKO_NOTE)
 verify.call(note.text.begins_with("Thank you for playing my project."),"Kyoko's credits note has no English translation");note.free()
 for id in ArchiveState.ORDER:
  var doc:=ArchiveState.document(id)
  verify.call(not doc.is_empty() and doc.has("body") and doc.has("headline"),"Missing translated document: "+id)
 verify.call(ArchiveState.document("opening").body.contains("June") and int(ArchiveState.document("opening").stage)==3,"Opening newspaper loses its clue or round")
 verify.call(ArchiveState.document("missing").body.contains("9 children") and ArchiveState.document("missing").body.contains("13 children") and int(ArchiveState.document("missing").stage)==5,"Missing newspaper loses its clue or round")
 verify.call(ArchiveState.document("coverup").body.contains("two") and int(ArchiveState.document("coverup").stage)==8,"Cover-up newspaper loses its clue or round")
 verify.call(ArchiveState.document("closure").body.contains("8 months") and int(ArchiveState.document("closure").stage)==11,"Closure newspaper loses its clue or round")
 var lock:=ArchiveState.new();verify.call(lock.try_code("0712"),"Creator archive access was lost")
 verify.call(g.captions.line_at("intro",27).contains("red door"),"Phone captions do not follow the recording")
 verify.call(g.captions.line_at("film",22).contains("cake"),"Film narration has no English captions")
 verify.call(g.captions.line_at("archive",274).contains("soup"),"Final recording is missing its last caption")
 verify.call(g.captions.line_at("archive",278).is_empty(),"A caption persists after the final spoken sentence")
 g._new_shift();g.intro.skip();g.player.active=false
 var prop_names: Dictionary={}
 for prop in g.world.atmosphere.loose:prop_names[prop.title]=true
 for value: String in prop_names:
  verify.call(AfterPlayLanguage.t(value)!=value,"Pickup prompt has an untranslated object name: "+value)
 for face in g.get_tree().get_nodes_in_group("caption_signs"):
  if face is MeshInstance3D and face.mesh is TextMesh and g.world.is_ancestor_of(face):
   verify.call(not face.mesh.can_translate_messages(),"A physical sign silently changes its printed language")
 g.archive.ending="recording";g.archive.recording_position=119.9;g.captions.tick(.1,g)
 verify.call(g.captions.content.contains("Two children") and g.captions.source=="archive","Archive captions are disconnected from playback position")
 g.phase="pause";g.captions.tick(.1,g)
 verify.call(not g.captions.panel.visible,"Speech remains on screen after leaving playback for pause")
 g.phase="play";g.archive.recording_position=146.7;g.captions.tick(.1,g)
 verify.call(g.captions.content.contains("Nine children"),"Captions do not resume at the current recording position")
 g.archive.ending="idle";g.settings.subtitles=false;g.settings.sign_subtitles=false;g.captions.tick(.1,g)
 verify.call(not g.captions.panel.visible,"Subtitle switches cannot hide the overlay")
 g.settings.subtitles=true;g.settings.sign_subtitles=true
 var sign: Node3D
 for face in g.get_tree().get_nodes_in_group("caption_signs"):
  if g.world.is_ancestor_of(face) and face.get_meta("sign_design","")=="hours":sign=face;break
 verify.call(sign!=null,"Opening-hours poster is missing its translated reading surface")
 if sign:
  g.player.rotation=Vector3.ZERO;g.player.camera.rotation=Vector3.ZERO
  g.player.position=sign.global_position+sign.global_basis.z*1.8-Vector3.UP*1.65
  g.player.camera.look_at(sign.global_position)
  Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
  await g.get_tree().physics_frame;await g.get_tree().physics_frame
  var center: Vector2=g.player.camera.get_viewport().get_visible_rect().size*.5
  verify.call(not g.captions.read_sign(g,center).is_empty(),"Looking at a physical sign shows no English translation")
  var blocker: MeshInstance3D=g.world.box(g.world,sign.global_position+sign.global_basis.z*.7,Vector3(.7,1,.7),g.world.materials.dark,true)
  await g.get_tree().physics_frame;await g.get_tree().physics_frame
  verify.call(g.captions.read_sign(g,center).is_empty(),"Sign translation is visible through an obstruction")
  blocker.queue_free()
  g.player.camera.rotate_y(PI)
  verify.call(g.captions.read_sign(g,center).is_empty(),"Sign translation ignores where the player is looking")
 # Test the rendered translation too: Label.text alone hid the engine's former
 # English fallback, even while the saved selection already said German.
 g._settings("menu");NightMenus.settings(g,"Sprache")
 choice=g.menu.find_child("LanguageChoice",true,false) as OptionButton
 choice.item_selected.emit(0)
 verify.call(g.settings.language=="de" and not AfterPlayLanguage.english(),"Selecting German does not apply immediately")
 sample=g._label("Einstellungen")
 verify.call(sample.text=="Einstellungen" and sample.tr(sample.text)=="Einstellungen","German labels are displayed in English through the engine fallback");sample.free()
 verify.call(TranslationServer.translate("Einstellungen")=="Einstellungen","Engine translation ignores the selected German locale")
 g.settings.language="en";AfterPlayLanguage.choose("en");g._read_settings()
 verify.call(g.settings.language=="de" and not AfterPlayLanguage.english(),"German selection does not survive settings reload")
 g._main_menu()
 var start:=g.menu.find_child("MainMenuAction0",true,false) as Button
 verify.call(start.text=="Neue Nachtschicht" and start.tr(start.text)=="Neue Nachtschicht","Main menu does not return to rendered German after leaving settings")
 verify.call(g.captions.line_at("intro",27).contains("rote Tür"),"German speech captions are missing")
 verify.call(AfterPlayLanguage.t("Einstellungen")=="Einstellungen","German UI was overwritten by English")
 g.settings=original;g._apply_settings();g._write_settings();g.player.active=false
