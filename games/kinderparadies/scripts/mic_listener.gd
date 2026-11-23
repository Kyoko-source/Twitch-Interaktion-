class_name MicListener
extends Node

# 5.4.0: microphone mode. Only the loudness of the microphone is measured,
# frame by frame; nothing is recorded, stored or sent anywhere. The signal runs
# into its own silent bus with a capture effect, so the player never hears it.
const BUS:="AP.Mic"
var enabled:=false
var player: AudioStreamPlayer
var capture: AudioEffectCapture
var level_db:=-80.
var peak_db:=-80.
var injected:=false

static func supported() -> bool:
 return not OS.has_feature("web")

static func devices() -> PackedStringArray:
 return AudioServer.get_input_device_list() if supported() else PackedStringArray()

# Streamers often route the real microphone through a mixer: let them pick it.
func set_device(device: String) -> void:
 if not supported():return
 if device not in devices():device="Default"
 if AudioServer.input_device!=device:AudioServer.input_device=device

func enable(on: bool) -> void:
 on=on and supported()
 if on==enabled:return
 enabled=on
 if on:
  var index:=AudioServer.get_bus_index(BUS)
  if index<0:
   AudioServer.add_bus();index=AudioServer.bus_count-1;AudioServer.set_bus_name(index,BUS)
   capture=AudioEffectCapture.new();capture.buffer_length=.25;AudioServer.add_bus_effect(index,capture)
  else:capture=AudioServer.get_bus_effect(index,0) as AudioEffectCapture
  # The capture effect sits before the fader: the bus itself stays silent.
  AudioServer.set_bus_volume_db(index,-80.);AudioServer.set_bus_send(index,"Master")
  if not player:
   player=AudioStreamPlayer.new();player.name="MicrophoneInput";player.stream=AudioStreamMicrophone.new();player.bus=BUS;add_child(player)
  player.play()
 else:
  if player:player.stop()
  if capture:capture.clear_buffer()
  level_db=-80.;peak_db=-80.

# Tests and the calibration preview can feed a level directly.
func inject(db: float) -> void:
 injected=true;level_db=db;peak_db=maxf(peak_db,db)

func release_injection() -> void:
 injected=false;level_db=-80.;peak_db=-80.

func _process(delta: float) -> void:
 if injected:return
 if not enabled or not capture:
  level_db=-80.;return
 var frames:=capture.get_frames_available()
 if frames<=0:
  level_db=maxf(-80.,level_db-delta*40.);return
 var buffer:=capture.get_buffer(frames)
 var sum:=0.
 for f in buffer:sum+=maxf(f.x*f.x,f.y*f.y)
 var rms:=sqrt(sum/maxf(1.,buffer.size()))
 var db:=linear_to_db(rms) if rms>.00001 else -80.
 # Fast attack, slower release, so a scream reads as one steady block.
 level_db=db if db>level_db else lerpf(level_db,db,minf(1.,delta*6.))
 peak_db=maxf(level_db,peak_db-delta*12.)
