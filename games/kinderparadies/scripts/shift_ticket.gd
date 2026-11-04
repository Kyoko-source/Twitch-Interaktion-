class_name ShiftTicket
extends Node3D

const MESSAGE:="Letzter Kontrollgang. Danach Feierabend."
var paper: Node3D
var text: Label3D
var print_audio: AudioStreamPlayer3D
var amount:=0.
var printing:=false
var floor_number:=1
var revealed:=false
var interaction: CollisionShape3D

func build(w: PlayWorld,cabin: Node3D) -> void:
 name="LastPatrolThermalPrinter";position=Vector3(-1.31,1.27,-.55);rotation.y=PI/2;cabin.add_child(self)
 w.box(self,Vector3.ZERO,Vector3(.31,.34,.105),w.materials.dark)
 w.box(self,Vector3(0,.018,.056),Vector3(.252,.024,.014),w.materials.metal)
 w.box(self,Vector3(0,.021,.065),Vector3(.21,.007,.013),w.materials.dark)
 var logo:=Label3D.new();logo.text="HAPPYLAND / NACHTDIENST";logo.font_size=32;logo.pixel_size=.00037;logo.position=Vector3(0,.11,.055);logo.modulate=Color("c7ba8e");logo.outline_size=0;add_child(logo)
 paper=Node3D.new();paper.name="FinalPatrolReceipt";paper.position=Vector3(0,.015,.066);add_child(paper)
 var thermal:=w.mat(Color("d5d3bc"),null,.98)
 var sheet:=w.box(paper,Vector3(0,-.095,0),Vector3(.197,.19,.001),thermal);sheet.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 text=Label3D.new();text.position=Vector3(0,-.086,.0015);text.font_size=44;text.pixel_size=.00036;text.modulate=Color("29372f");text.outline_size=0;text.text="13 / 13\n\n"+AfterPlayLanguage.t(MESSAGE).replace(". ",".\n");paper.add_child(text)
 var body:=StaticBody3D.new();body.set_meta("interaction","final_receipt");add_child(body)
 interaction=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.21,.21,.025);interaction.shape=shape;interaction.position=Vector3(0,-.08,.069);interaction.disabled=true;body.add_child(interaction)
 print_audio=AudioStreamPlayer3D.new();print_audio.stream=load("res://assets/backstage-v270/keys.wav");print_audio.unit_size=1.8;print_audio.max_distance=5;print_audio.volume_db=-28;print_audio.pitch_scale=.65;add_child(print_audio)
 paper.hide()

func set_floor(value: int) -> void:
 floor_number=value
 interaction.disabled=value!=13
 if value!=13:
  amount=0.;printing=false;revealed=false;paper.hide();print_audio.stop()

func tick(delta: float,active: bool) -> void:
 print_audio.stream_paused=not active
 if not active:return
 if floor_number==13 and not revealed:revealed=true;printing=true;paper.show();print_audio.play()
 if printing:
  amount=move_toward(amount,1.,delta*.65);paper.scale.y=maxf(.001,amount)
  if amount>=1.:printing=false;print_audio.stop()
 text.text="13 / 13\n\n"+AfterPlayLanguage.t(MESSAGE).replace(". ",".\n")
