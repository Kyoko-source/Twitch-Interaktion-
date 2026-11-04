class_name PassageLift
extends Node3D

# This is the very same cabin constructor as the entrance lift, including
# its printer, materials, controls, directory and two sliding door leaves.
var doors: Array[Node3D]=[]
var floor_displays: Array[Label3D]=[]
var ticket:=ShiftTicket.new()
var cabin: Node3D

func build(w: PlayWorld,p: Vector3) -> void:
 name="MatchingReturnLift"
 cabin=LiftCabin.new().build(w,self);cabin.position=p;cabin.rotation.y=PI
 ticket.build(w,cabin)
 for i in range(2):doors[i].position.x=(-1 if i==0 else 1)*1.89

func set_floor(value: int) -> void:
 for display in floor_displays:display.text=ElevatorIntro.floor_text(value)
 ticket.set_floor(value)
