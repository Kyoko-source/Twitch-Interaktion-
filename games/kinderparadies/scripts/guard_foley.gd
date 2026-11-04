class_name GuardFoley
extends Node

const ROOT:="res://assets/feedback-v403/"
var sound: AudioStreamPlayer
var clips: Dictionary={}
var last:=""
var count:=0

func _ready() -> void:
 name="InteractionFoley"
 clips={"keys":load("res://assets/backstage-v270/keys.wav"),"paper":load(ROOT+"paper.ogg"),"switch":load(ROOT+"switch.ogg")}
 sound=AudioStreamPlayer.new();sound.name="HandsAndObjects";sound.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(sound)

func play(kind: String) -> void:
 if not clips.has(kind):return
 last=kind;count+=1;sound.stream=clips[kind];sound.pitch_scale=1.;sound.volume_db=-19. if kind=="keys" else -15. if kind=="paper" else -17.
 sound.stream_paused=false;sound.play()

func tick(audible: bool) -> void:
 if sound:sound.stream_paused=not audible

func stop() -> void:
 if sound:sound.stop()

func snapshot() -> Dictionary:
 return {"last":last,"count":count,"playing":sound.playing,"paused":sound.stream_paused,"track":sound.stream.resource_path if sound.stream else ""}
