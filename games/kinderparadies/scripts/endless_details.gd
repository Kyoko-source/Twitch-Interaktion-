class_name EndlessDetails
extends RefCounted

# Endless mode (4.14.0): procedural detail anomalies on existing furniture.
# A seed picks one curated object and one change; the strength (1.0 at round
# 31, 0.08 at round 500) scales how far it turns, moves, grows or tints.
# Everything is applied to a fresh world, so every normal round is untouched.

const TINTS:=[Color(1.,.42,.36),Color(.45,.58,1.),Color(.5,1.,.5),Color(.42,.42,.42)]
# id, German name, zone, allowed changes, axis (local for tilt/spin,
# parent space for shift: along the wall for wall-mounted things).
const TARGETS:=[
 ["car","das rote Spielauto","Bällebad",["turn","shift","grow","shrink","tint"],Vector3.RIGHT],
 ["chair","ein Stuhl am Geburtstagstisch","Party Raum",["turn","shift","tilt"],Vector3.RIGHT],
 ["balloon","ein Geburtstagsballon","Party Raum",["shift","grow","tint","hide"],Vector3.RIGHT],
 ["star","ein Stern im Wartungsgang","Wartungsgang",["spin","grow","shrink","tint","hide","drop"],Vector3.FORWARD],
 ["clock","die Wanduhr am Empfang","Empfang",["spin","grow","shrink"],Vector3.FORWARD],
 ["mural","das große Wandbild","Wartungsgang",["spin","shrink","tint"],Vector3.FORWARD],
 ["hours","das Schild mit den Öffnungszeiten","Empfang",["spin","drop","tint"],Vector3.FORWARD],
 ["extinguisher","der Feuerlöscher","Wartungsgang",["turn","shift","grow","tint"],Vector3.BACK],
 ["bin","der Mülleimer am Empfang","Empfang",["shift","grow","shrink","tint"],Vector3.BACK],
 ["table","der Geburtstagstisch","Party Raum",["turn","shift"],Vector3.RIGHT],
 ["noticeboard","die Pinnwand am Empfang","Empfang",["spin","drop","tint"],Vector3.FORWARD],
 ["croc","das aufblasbare Krokodil","Bällebad",["turn","grow","shrink","tint"],Vector3.RIGHT],
]
const VERBS:={"turn":"war verdreht","shift":"stand ein Stück versetzt","grow":"war größer als sonst","shrink":"war kleiner als sonst","tilt":"stand schief","spin":"hing schief","tint":"hatte eine andere Farbe","hide":"fehlte","drop":"hing tiefer als sonst"}

static func nodes(w: Node3D, id: String) -> Array:
 var p: Dictionary=w.props
 match id:
  "car":return [p.get("car")]
  "chair":return p.chairs.get_children() if p.has("chairs") else []
  "balloon":return p.balloons.get_children().slice(0,3) if p.has("balloons") else []
  "star":return p.stars.get_children() if p.has("stars") else []
  "clock":return [p.get("clock")]
  "mural":return [p.get("mural")]
  "hours":return [p.get("hours")]
  "extinguisher":return [p.get("extinguisher")]
  "bin":return [p.get("reception_bin")]
  "table":return [p.get("party_table")]
  "noticeboard":return [p.get("reception_noticeboard")]
  "croc":return [p.get("inflatable")]
 return []

# Applies the detail for this seed and returns its description.
static func apply(w: Node3D, spec: Dictionary) -> Dictionary:
 var rng:=RandomNumberGenerator.new();rng.seed=int(spec.get("seed",1))
 var strength:=clampf(float(spec.get("strength",1.)),.05,1.)
 var order:=range(TARGETS.size())
 for i in range(order.size()-1,0,-1):
  var j:=rng.randi_range(0,i);var t=order[i];order[i]=order[j];order[j]=t
 for index in order:
  var row: Array=TARGETS[index]
  var candidates:=nodes(w,row[0]).filter(func(n):return n is Node3D and is_instance_valid(n))
  if candidates.is_empty():continue
  var node: Node3D=candidates[rng.randi_range(0,candidates.size()-1)]
  var kinds: Array=row[3]
  var kind: String=kinds[rng.randi_range(0,kinds.size()-1)]
  var side:=-1. if rng.randf()<.5 else 1.
  _change(node,kind,strength,side,row[4],TINTS[rng.randi_range(0,TINTS.size()-1)])
  node.set_meta("endless_detail",kind)
  return {"target":row[0],"node":node,"kind":kind,"text":"%s: %s %s."%[row[2],_upper(row[1]),VERBS[kind]]}
 return {}

static func _upper(text: String) -> String:
 return text.substr(0,1).to_upper()+text.substr(1)

static func _change(node: Node3D, kind: String, s: float, side: float, axis: Vector3, tint: Color) -> void:
 match kind:
  "turn":node.rotate_y(side*deg_to_rad(lerpf(14.,90.,s)))
  "spin","tilt":node.rotate_object_local(axis,side*deg_to_rad(lerpf(7.,35.,s)))
  "shift":
   node.position+=axis*side*lerpf(.14,1.1,s)
  "drop":node.position.y-=lerpf(.08,.6,s)
  "grow":node.scale*=1.+lerpf(.14,.7,s)
  "shrink":node.scale*=1.-lerpf(.12,.45,s)
  "hide":
   node.hide()
   for body: CollisionObject3D in node.find_children("*","CollisionObject3D",true,false):body.collision_layer=0;body.collision_mask=0
  "tint":
   var overlay:=StandardMaterial3D.new();overlay.blend_mode=BaseMaterial3D.BLEND_MODE_MUL;overlay.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
   overlay.albedo_color=Color.WHITE.lerp(tint,lerpf(.3,.85,s))
   var shapes:Array=node.find_children("*","GeometryInstance3D",true,false)
   if node is GeometryInstance3D:shapes.append(node)
   for shape: GeometryInstance3D in shapes:
    if shape.visible and not shape.material_overlay:shape.material_overlay=overlay
