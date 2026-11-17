class_name SystemCheck
extends RefCounted

# 4.8.0 minimum requirements: the main menu names what on this PC falls short
# of them. It only advises; no setting is changed behind the player's back.
const MIN_RAM_GB:=7.5
const MIN_THREADS:=4

# German source strings; AfterPlayLanguage translates them.
const NO_VULKAN:="Deine Grafikkarte unterstützt weder Vulkan noch Direct3D 12. After Play läuft im Notfallmodus und sieht anders aus als vorgesehen."
const INTEGRATED:="Integrierte Grafik erkannt. Für ein flüssiges Spiel stelle die Grafikqualität in den Einstellungen auf Leistung."
const LOW_RAM:="Weniger als 8 GB Arbeitsspeicher. Schließe andere Programme, bevor du spielst."
const FEW_THREADS:="Dieser Prozessor liegt unter den Mindestanforderungen. Es kann ruckeln."

static func issues(preview: bool=false) -> Array[String]:
 var found: Array[String]=[]
 if OS.has_feature("web") or (DisplayServer.get_name()=="headless" and not preview): return found
 if preview or RenderingServer.get_current_rendering_method()!="forward_plus": found.append(NO_VULKAN)
 var adapter:=RenderingServer.get_video_adapter_type()
 if preview or adapter in [RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU,RenderingDevice.DEVICE_TYPE_CPU]: found.append(INTEGRATED)
 var memory:=OS.get_memory_info()
 if preview or (memory.has("physical") and int(memory.physical)>0 and float(memory.physical)/1073741824.<MIN_RAM_GB): found.append(LOW_RAM)
 if preview or OS.get_processor_count()<MIN_THREADS: found.append(FEW_THREADS)
 return found

static func snapshot() -> Dictionary:
 var memory:=OS.get_memory_info()
 return {"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"adapter_type":RenderingServer.get_video_adapter_type(),"ram_gb":snappedf(float(memory.get("physical",0))/1073741824.,.1),"threads":OS.get_processor_count(),"issues":issues()}
