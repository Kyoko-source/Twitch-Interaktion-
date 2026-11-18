extends RefCounted

# Load-time benchmark (render QA: --load-qa).
# 1. Times every construction step of a fresh (hidden) world.
# 2. Times what the player sees on a round change: from the build call until
#    frames run normally again (under 40 ms), five times in a row.
func run(game: Node3D, output: String) -> void:
 var report:={}
 var world:=PlayWorld.new();world.hide();game.add_child(world)
 var steps:=world.construction_steps();var times:={}
 for i in range(steps.size()):
  var t0:=Time.get_ticks_usec();steps[i].call()
  var args:=steps[i].get_bound_arguments()
  times[str(steps[i].get_method())+":"+str(args[1] if args.size()>1 else i)]=(Time.get_ticks_usec()-t0)/1000.
 world.queue_free();await game.get_tree().process_frame
 var keys:=times.keys();keys.sort_custom(func(a,b):return times[a]>times[b])
 var top:=[]
 for k in keys.slice(0,15): top.append("%s=%.0f"%[k,times[k]])
 print("LOAD steps ",", ".join(top))
 report.steps=times
 var freezes:=[]
 for round_index in range(5):
  var t0:=Time.get_ticks_usec();game._build_world("none");var built:=(Time.get_ticks_usec()-t0)/1000.
  var last:=Time.get_ticks_usec();var frames:=0
  while frames<60:
   await game.get_tree().process_frame;var now:=Time.get_ticks_usec();frames+=1
   if (now-last)/1000.<40. and frames>2: break
   last=now
  var total:=(Time.get_ticks_usec()-t0)/1000.;freezes.append(total)
  print("LOAD freeze round=",round_index," build_ms=",snappedf(built,1)," total_ms=",snappedf(total,1)," frames=",frames)
 report.freezes=freezes
 var file:=FileAccess.open(output.path_join("load-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
