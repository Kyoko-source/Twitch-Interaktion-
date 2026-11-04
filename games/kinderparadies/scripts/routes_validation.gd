extends RefCounted

# Exercise the real player controller, not just rays through intended openings.
const ROUTES:=[
 ["Startfahrstuhl",Vector3(-8,0,19.35),Vector3(-8,0,15.7)],
 ["Empfang Eingang",Vector3(-11.3,0,9.4),Vector3(-6.3,0,9.4)],
 ["Empfang Tresenende",Vector3(-6.3,0,9.4),Vector3(-6.3,0,6.75)],
 ["Empfang Personalplatz",Vector3(-6.3,0,6.75),Vector3(-7.4,0,6.75)],
 ["Kinder-WC",Vector3(18.8,0,7.8),Vector3(21.1,0,7.8)],
 ["Party Eingang",Vector3(5.9,0,-8.7),Vector3(8.,0,-8.7)],
 ["Party Stuehle links",Vector3(8.05,0,-9.7),Vector3(8.05,0,-4.4)],
 ["Party Stuehle rechts",Vector3(12.35,0,-9.2),Vector3(12.35,0,-4.4)],
 ["Geburtstagspodest",Vector3(12,0,-8.),Vector3(12,.2,-10.3)],
 ["Kostuemraum",Vector3(17.3,0,-8.3),Vector3(17.3,.2,-14)],
 ["Wartung Eingang",Vector3(-9.4,0,-5.4),Vector3(-11.5,0,-5.4)],
 ["Archiv Vorbereich",Vector3(-8.7,0,-6.5),Vector3(-8.7,0,-10.)],
 ["Personalflur",Vector3(-7.9,0,-11.),Vector3(-7.9,0,-29.65)],
 ["Kueche Tuer",Vector3(-8.1,0,-29.65),Vector3(-10.8,0,-29.65)],
 ["Kueche Tuerband",Vector3(-8.1,0,-29.29),Vector3(-10.8,0,-29.29)],
 ["Kino Tuer",Vector3(-7.8,0,-29.65),Vector3(-5.3,0,-29.65)],
 ["Kino Tuerband",Vector3(-7.8,0,-30.01),Vector3(-5.3,0,-30.01)],
 ["Kino hinterer Gang",Vector3(-5.3,0,-30.8),Vector3(-5.3,0,-33.3)],
 ["Kino Mittelgang",Vector3(-5.3,0,-29.65),Vector3(1.1,0,-29.65)],
 ["Kino Sitzreihe",Vector3(-3.55,0,-32.9),Vector3(-3.55,0,-30.9)],
 ["Gruene Entscheidungstuer",Vector3(-4.3,0,-10.7),Vector3(-4.3,0,-13.6)],
 ["Rote Entscheidungstuer",Vector3(-2.15,0,-10.7),Vector3(-2.15,0,-13.6)],
 ["Gruener Flurbogen",Vector3(-4.3,0,-13.6),Vector3(-4.7,0,-16.2)],
 ["Roter Flurbogen",Vector3(-2.15,0,-13.6),Vector3(-1.35,0,-16.2)],
 ["Gruene Kabinennaehe",Vector3(-4.7,0,-16.2),Vector3(-4.7,0,-19.3)],
 ["Rote Kabinennaehe",Vector3(-1.35,0,-16.2),Vector3(-1.35,0,-19.3)],
 ["Gruener Fahrstuhlboden",Vector3(-4.7,0,-19.3),Vector3(-4.7,.02,-22.0)],
 ["Roter Fahrstuhlboden",Vector3(-1.35,0,-19.3),Vector3(-1.35,.02,-22.0)],
 ["Klettergeruest Bodenrampe",Vector3(6.4,0,7.5),Vector3(11.1,2.15,7.5)],
 ["Klettergeruest Ostplattform",Vector3(12,2.15,7.5),Vector3(12,2.15,3.6)],
 ["Klettergeruest Bruecke",Vector3(10.8,2.15,3.6),Vector3(4.03,2.977,3.6)],
 ["Aussichtsturm Rampe",Vector3(2.05,2.977,-.1),Vector3(2.05,4.15,-3.7)],
 ["Oberer Turm Rampe",Vector3(16.2,2.15,8.15),Vector3(16.2,4.15,3.7)],
 ["Podest rechte Kante",Vector3(17.85,0,-8.3),Vector3(17.85,.2,-10.3)]
]

func travel(g: Node3D,a: Vector3,b: Vector3,mode: String,crouch: bool=false) -> Dictionary:
 var p: NightGuard=g.player
 var title: String={"carry":"Spielball","carry_block":"Holzbaustein","carry_bucket":"Eimer","carry_plush":"Stoffhase"}.get(mode,"")
 if not title.is_empty():mode="carry"
 p.drop_prop();p.position=a+Vector3.UP*.025;p.velocity=Vector3.ZERO;p.camera.rotation=Vector3.ZERO;p.set_crouch(false)
 var direction:=Vector3(b.x-a.x,0,b.z-a.z).normalized()
 p.rotation.y=atan2(-direction.x,-direction.z)+(PI if mode=="backward" else 0.)
 if crouch:Input.action_press("crouch")
 for i in range(3):await g.get_tree().physics_frame
 var toy: NightProp
 var toy_pose:=Transform3D.IDENTITY
 var toy_frozen:=true
 if mode=="carry":
  for item in g.world.atmosphere.loose:
   if item.title==title:toy=item;break
  toy_pose=toy.global_transform;toy_frozen=toy.freeze;toy.freeze=false;toy.global_position=p.camera.global_position-p.camera.global_basis.z*.9;toy.linear_velocity=Vector3.ZERO;toy.angular_velocity=Vector3.ZERO
  await g.get_tree().physics_frame;await g.get_tree().physics_frame
  p.grab_prop()
 var held:=mode!="carry" or p.carried==toy
 p.active=true
 var action:="back" if mode=="backward" else "forward"
 Input.action_press(action)
 var frames:=ceili(a.distance_to(b)/2.8*60.)+100
 var min_y:=p.position.y
 var collided: Dictionary={}
 for i in range(frames):
  var remaining:=Vector2(p.position.x-b.x,p.position.z-b.z).length()
  if remaining<.12 and (absf(p.position.y-b.y)<.18 or mode=="jump"):break
  if mode=="jump" and i%55==0:p.jump_buffer=.14
  await g.get_tree().physics_frame
  min_y=minf(min_y,p.position.y)
  for j in range(p.get_slide_collision_count()):
   var hit:=p.get_slide_collision(j)
   if absf(hit.get_normal().y)<.5:collided[str(hit.get_collider().get_path())]=true
  if mode=="carry" and p.carried!=toy:held=false
 Input.action_release(action)
 # Let a real jump land before checking floor continuity.
 for i in range(45):await g.get_tree().physics_frame
 p.active=false
 var result:={"ok":Vector2(p.position.x-b.x,p.position.z-b.z).length()<.28 and absf(p.position.y-b.y)<.25 and min_y>-.4 and held,"at":str(p.position),"contacts":collided.keys(),"held":held}
 p.drop_prop()
 Input.action_release("crouch")
 if toy:toy.freeze=toy_frozen;toy.global_transform=toy_pose;toy.linear_velocity=Vector3.ZERO;toy.angular_velocity=Vector3.ZERO
 return result

func run(g: Node3D,verify: Callable) -> void:
 g._new_shift();g.intro.skip();g.player.active=false;g.set_process(false)
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 # Open the actual decision leaves; progression remains frozen so the same
 # geometry can be tested from both sides without boarding or an ambush.
 for lane in g.world.passages.lanes:lane.open=true
 g.world.passages.tick(2.,true,g.player,false,false)
 var total:=0
 for route in ROUTES:
  for mode in ["forward","backward","jump","carry","carry_block","carry_bucket","carry_plush"]:
   for reverse in [false,true]:
    var result:=await travel(g,route[2] if reverse else route[1],route[1] if reverse else route[2],mode)
    total+=1
    verify.call(result.ok,"ROUTE "+route[0]+" "+mode+(" reverse" if reverse else "")+" "+JSON.stringify(result))
  print("ROUTE DONE ",route[0])
 # Crouched passage over each real upper-tube mouth, in both directions, with
 # the same held ball. The full winding tube is covered by climbing_validation.
 var sky: SkyTube=g.world.climbing.sky
 for ends in [[Vector3(3.75,SkyTube.FLOOR,-4.5),sky.route(.7)], [sky.route(sky.length-.7),Vector3(16.05,SkyTube.FLOOR,3.65)]]:
  for mode in ["forward","backward","carry","carry_bucket","carry_plush"]:
   for reverse in [false,true]:
    var a: Vector3=ends[1] if reverse else ends[0];a.y=SkyTube.FLOOR
    var b: Vector3=ends[0] if reverse else ends[1];b.y=SkyTube.FLOOR
    var result:=await travel(g,a,b,mode,true);total+=1
    verify.call(result.ok,"Upper tube mouth "+mode+(" reverse" if reverse else "")+" "+JSON.stringify(result))
 print("Real-controller route traversals: ",total)
 g.player.active=false;g.set_process(true)
