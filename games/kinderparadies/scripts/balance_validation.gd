extends RefCounted

func run(_game: Node3D, verify: Callable) -> void:
 var protected_ok:=true;var counts_ok:=true;var spacing_ok:=true
 var save_ok:=true;var quiet_rng_ok:=true;var unique_ok:=true
 var patterns: Dictionary={};var slot_counts: Dictionary={}
 var all_ids: Dictionary={};var total_anomalies:=0
 for seed_value in range(1,2049):
  var patrol:=PatrolState.new();patrol.start(seed_value)
  var count:=0;var consecutive:=0;var pattern:="";var ids: Dictionary={}
  for stage in range(1,14):
   var anomalous:=patrol.current!="none"
   if stage in [1,3,5,8,11]: protected_ok=protected_ok and not anomalous
   else: slot_counts[stage]=int(slot_counts.get(stage,0))+int(anomalous)
   count+=int(anomalous);consecutive=consecutive+1 if anomalous else 0
   spacing_ok=spacing_ok and consecutive<=2
   pattern+="A" if anomalous else "N"
   if anomalous:
    unique_ok=unique_ok and not ids.has(patrol.current)
    ids[patrol.current]=true;all_ids[patrol.current]=true
   var before:=patrol.serialize().duplicate(true)
   var restored:=PatrolState.new()
   if seed_value<=64:
    save_ok=save_ok and restored.restore(JSON.parse_string(JSON.stringify(before)))
    save_ok=save_ok and restored.serialize()==before
   patrol.decide(anomalous)
   if seed_value<=64:
    restored.decide(anomalous)
    save_ok=save_ok and restored.serialize()==patrol.serialize()
   if stage+1 in [3,5,8,11]:
    quiet_rng_ok=quiet_rng_ok and patrol.deck==before.deck and patrol.bag==before.bag and str(patrol.rng.state)==before.rng
  counts_ok=counts_ok and count==6 and patrol.completed and patrol.streak==13
  patterns[pattern]=true;total_anomalies+=count
 verify.call(protected_ok,"Balancing puts an anomaly in the first or a newspaper round")
 verify.call(counts_ok,"A fresh thirteen-round shift does not contain six anomalies and seven normal rounds")
 verify.call(spacing_ok,"Balancing chains more than two anomaly rounds without a quiet round")
 verify.call(patterns.size()==28,"Random normal rounds do not reach all twenty-eight possible placements")
 for stage in slot_counts:
  var share:=float(slot_counts[stage])/2048.
  verify.call(share>.68 and share<.82,"An unprotected round is biased or has a fixed outcome: "+str(stage))
 verify.call(save_ok,"Reload changes the current event or remaining balance, including newspaper rounds")
 verify.call(quiet_rng_ok,"A protected newspaper round consumes a random event")
 verify.call(unique_ok and all_ids.size()==PatrolState.ANOMALIES.size(),"Balanced shifts repeat their anomaly IDs or omit catalog entries")
 var legacy:=PatrolState.new();legacy.start(99);legacy.streak=5;legacy.current="clown_lunge"
 legacy.deck.assign(["normal","normal","normal","normal","anomaly","anomaly","anomaly"])
 var saved:=legacy.serialize().duplicate(true);var migrated:=PatrolState.new()
 verify.call(migrated.restore(JSON.parse_string(JSON.stringify(saved))) and migrated.serialize()==saved,"An update rerolls a legacy saved deck or loses progress")
 legacy.decide(true);migrated.decide(true)
 verify.call(migrated.serialize()==legacy.serialize(),"Continuing a legacy deck changes its next decision")
 var reset:=PatrolState.new();reset.start(118)
 for i in range(6): reset.decide(reset.current!="none")
 reset.decide(reset.current=="none");reset.start(118)
 var fresh:=PatrolState.new();fresh.start(118)
 verify.call(reset.serialize()==fresh.serialize(),"Death/new shift retains the old balance or anomaly bag")
 print("Balance sample: 2048 shifts; ",total_anomalies," anomaly rounds; ",2048*13-total_anomalies," normal rounds; ",patterns.size()," layouts")
