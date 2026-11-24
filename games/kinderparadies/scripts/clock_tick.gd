class_name ClockTick
extends RefCounted

# 5.6.1: one mechanical wall-clock tick, built once and shared by the reception
# clock in After Play and the control-room clock in Nightwatch Protocol. A
# sharp escapement click with a short wooden body resonance; "tock" is the
# slightly lower second half of the pair.

static var cache: Dictionary={}

static func stream(tock: bool=false) -> AudioStreamWAV:
 if cache.has(tock):return cache[tock]
 var rate:=22050;var length:=.09;var count:=int(length*rate)
 var noise:=RandomNumberGenerator.new();noise.seed=561 if tock else 560
 var body:=1650. if tock else 1900.
 var data:=PackedByteArray();data.resize(count*2)
 for i in range(count):
  var t:=float(i)/rate
  var click:=(noise.randf()-.5)*1.8*exp(-t*900.)
  var ring:=.55*sin(TAU*body*t)*exp(-t*140.)+.25*sin(TAU*body*2.7*t)*exp(-t*260.)
  var thump:=.3*sin(TAU*260.*t)*exp(-t*90.)
  data.encode_s16(i*2,int(clampf(click+ring+thump,-1.,1.)*30000.))
 var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=rate;wav.stereo=false;wav.data=data
 cache[tock]=wav
 return wav
