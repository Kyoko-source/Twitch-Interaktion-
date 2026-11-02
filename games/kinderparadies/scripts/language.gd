class_name AfterPlayLanguage
extends RefCounted

static var code:="de"
static var messages: Dictionary={}
static var templates: Array[Dictionary]=[]
static var translation: Translation
static var cache: Dictionary={}

static func setup() -> void:
 if translation:return
 messages=JSON.parse_string(FileAccess.get_file_as_string("res://locales/ui_en.json"))
 translation=Translation.new();translation.locale="en"
 for source: String in messages:
  translation.add_message(source,str(messages[source]))
  if "%" in source:
   var pattern:=RegEx.new()
   # Formatted strings are translated after their values are inserted, too.
   var escaped:=source
   for special in ["\\",".","+","*","?","[","]","(",")","{","}","^","$","|"]:escaped=escaped.replace(special,"\\"+special)
   var slots:=RegEx.new();slots.compile("%0?[0-9]*[dsf]")
   var matches:=slots.search_all(escaped)
   for i in range(matches.size()-1,-1,-1):
    var hit: RegExMatch=matches[i];escaped=escaped.substr(0,hit.get_start())+"(.+?)"+escaped.substr(hit.get_end())
   if not matches.is_empty():
    pattern.compile("^"+escaped+"$");templates.append({"pattern":pattern,"target":str(messages[source]),"count":matches.size(),"source":source})
 templates.sort_custom(func(a: Dictionary,b: Dictionary):return str(a.source).length()>str(b.source).length())
 TranslationServer.add_translation(translation)
 TranslationServer.set_locale(code)

static func choose(value: String) -> void:
 setup();code="en" if value=="en" else "de";cache.clear();TranslationServer.set_locale(code)

static func english() -> bool:
 return code=="en"

static func t(value: String) -> String:
 if not english() or value.is_empty():return value
 return english_text(value)

static func english_text(value: String) -> String:
 if messages.has(value):return str(messages[value])
 if cache.has(value):return str(cache[value])
 var result:=value
 for row in templates:
  var hit: RegExMatch=row.pattern.search(value)
  if not hit:continue
  result=row.target
  var slots:=RegEx.new();slots.compile("%0?[0-9]*[dsf]")
  for i in range(int(row.count)):
   var slot:=slots.search(result)
   if slot:result=result.substr(0,slot.get_start())+english_text(hit.get_string(i+1))+result.substr(slot.get_end())
  break
 cache[value]=result
 return result
