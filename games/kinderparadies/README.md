# NACHTWACHE — Kinderparadies

Eigenständiges 3D-Anomaliespiel, Godot 4.6.2 / GDScript. Gemeinsames Projekt für
Windows x86_64 und WebGL 2.0. Die Windows-Fassung läuft offline ohne Browser,
WebView, Aviary-Konto oder Anmeldung.

## Spielen

`Nachtwache.exe` aus dem Windows-ZIP entpacken und starten. Im Web auf Aviary
unter `/#games/nachtwache` öffnen und „Im Web spielen“ wählen.

WASD / Pfeiltasten bewegen, Maus umsehen, Umschalt schneller gehen, Leertaste
springen, G Gegenstand aufheben/loslassen, linke Maustaste werfen, F Taschenlampe,
E Tür öffnen, TAB Dienstanweisung, ESC Pause, F11 Vollbild.
Die erste Runde ist normal und dient als Referenz. Bereiche kannst du freiwillig
erkunden; beide Türen sind jederzeit wählbar. Keine Anomalie: grüne Tür.
Anomalie: rote Tür. 13 richtige Entscheidungen
in Folge gewinnen. Eine falsche Tür beendet die Schicht und startet wieder das
Fahrstuhl-Intro. E nimmt den Chef-Anruf an; gehaltene Leertaste überspringt das Intro.
45 Anomalien, ohne Wiederholung innerhalb des Anomalie-Beutels. Normale und
veränderte Runden werden unabhängig vom gewählten Türtyp gemischt.
Dichter graugrüner Nebel gehört zur normalen Umgebung. Blutroter Nebel ist eine
Anomalie; die frühere reine Dichte-Anomalie wurde ersetzt.

Helligkeit, Lautstärke, Empfindlichkeit, Grafikqualität und Kamerabewegung sind
einstellbar. Spielstand wird pro Runde, bei Pause und alle zehn aktiven Sekunden
lokal gespeichert. Web verwendet den lokalen Browser-Speicher, Windows Godots
Benutzerdatenverzeichnis. Kein Online-Ranking oder Chickens-Buchungen.

Ziel: Desktop mit Maus/Tastatur. Windows verwendet Forward+ mit Vulkan/Direct3D
12 und moderner Grafikkarte. Der automatische OpenGL-Fallback unterstützt die
reduzierte Grafik. Web verwendet WebGL 2.0. Keine Touch-/Controllersteuerung.
„Leistung“ deaktiviert die aufwendigen Schatten, indirektes Licht und Volumen-
nebel; „Hoch“ aktiviert die volle Windows-Grafik. Kein Installationsprogramm,
keine Autostarts und keine Administratorrechte erforderlich.

## Bauen und prüfen

Im Repository `./tools/build-kinderparadies.ps1` ausführen. Das Skript lädt bei
Bedarf die offizielle portable Godot-Version und verifiziert deren SHA512.
`prepare-kinderparadies-templates.py` lädt per HTTP-Range ausschließlich die
Windows- und Web-Templates aus dem offiziellen Archiv; ZIP-CRCs werden geprüft.

Ergebnisse: `build/windows/Nachtwache.exe`, `build/web/`,
`build/nachtwache-windows-v1.9.4.zip`. `-WithQA` erzeugt zusätzlich eine separate
Web-Prüffassung mit Test-Hooks; diese darf nicht veröffentlicht werden.

`Godot_v4.6.2-stable_win64_console.exe --headless --path games/kinderparadies -- --self-test`
prüft Logik, Save/Restore, alle Anomalien, Bewegung, Boden und beide Tür-Raycasts.
Auch die exportierte EXE unterstützt denselben isolierten Testmodus:
`Nachtwache.exe --headless -- --self-test`. Tests verwenden eigene QA-Spielstände.

Browserprüfungen: eigener lokaler HTTP-Server für `build/qa`, dann im Frontend
`NACHTWACHE_QA_URL=http://127.0.0.1:4188 npx playwright test nachtwatch.spec.mjs`.
Produkt-Webexport enthält keine steuerbaren QA-Hooks und verrät keine Anomalie-ID.

## Assets und Lizenzen

Eigene mit Image Gen erstellte Oberflächen und Wandmalerei in `assets/`.
Die ganze Umgebung bleibt echte begehbare 3D-Geometrie mit Kollisionen und
Schatten; das Konzeptbild wird nicht als Spielwelt verwendet. Prompts und
Art-Direction in `art/`. Oswald: SIL Open Font License (beigelegt).
Schritte, Tür und Leitungsgeräusch: Kenney Impact Sounds, CC0 (beigelegt).
`room.wav`: eigene nichtmusikalische Raumtextur aus dem Projekt.
`fan.wav`, `rabbit-scare.wav`, `croc-snap.wav`, `party-burst.wav`: eigene Geräusche,
reproduzierbar mit `tools/generate-nachtwache-encounters.py`.
`drips.wav`: eigene Wasser-/Rohrgeräusche, reproduzierbar mit
`tools/generate-nachtwache-drips.py`. Keine Hintergrundmusik.
Godot MIT-Lizenz und Drittanbieterhinweise liegen dem Windows-ZIP bei.
Windows-Modelle und Materialkarten von Poly Haven: CC0. Quellen, Prüfsummen und
Lizenzhinweise in `assets/polyhaven-provenance.json` und `PolyHaven-CC0.txt`.
Die eigenen Hero-Modelle werden mit `tools/model-nachtwache-heroes.py` in Blender
4.5.9 LTS erzeugt; GLBs und extrahierte Texturen liegen bereits im Repository.
Das überarbeitete Krokodil wird mit `tools/model-nachtwache-crocodile-v2.py` erzeugt.
Der neue Clown verwendet die Geometrie und Oberflächennormalen von „Infinite,
3D Head Scan“ von Lee Perry-Smith (CC BY 3.0), ohne dessen Porträtfarbtexturen. Eigene Proportionen,
Schminke, Blutspuren, Haare und Kostüm ergänzen die Basis. Quelle und Lizenz:
`assets/props/Head-Attribution.txt`, mit SHA256 in `anatomy-provenance.json`.
Das lizenzierte Ausgangsmodell lädt `tools/fetch-nachtwache-anatomy.py`; die
bearbeiteten Modelle erstellt `tools/model-nachtwache-props-v180.py`.

## Version 1.1

Abgenutzte PBR-Oberflächen, schadhafter Putz, vernähter Stoffhase, Seilbrücke,
Schreibtischlampe, Telefon, Geschirr, Papier, Rohrschellen, Ketten und Stoffbahnen.
Bodennebel, Raumdunst, Staub und sechs neue Horror-Anomalien einschließlich
Blutspuren, Handabdrücken und blutendem Wandbild. Der alte Fleck an der
Wartungswand gehört zur Referenzrunde; neue rote Spuren sind Anomalien.

28 lose Objekte besitzen echte starre Körper mit Masse, Reibung, Schwerkraft und
Kollisionen. Anschieben, federndes Tragen und Impulswerfen; physikalische Bewegung
stoppt in Menüs/Pause. Selbst verschobene Objekte zählen nicht als Anomalie.
Jede neue Runde setzt sie zurück. Der Spieler springt mit Bodenkontakt; kein
Doppelsprung. Die dekorativen instanzierten Bälle im Bällebad bleiben statisch,
um die Web-Version spielbar zu halten. Keine vollständige Softbody-Simulation.

## Windows Edition 1.2

Die Windows-Fassung enthält 32 platzierte Modellinstanzen aus zwölf Modelltypen:
acht CC0-Requisiten und vier eigene Modelle (vernähter Hase, gepolsterte Bank,
gefaltete Stoffbahn und Geburtstagstorte). Fünf vollständige PBR-Materialsets,
modellierte Seilnetze, ein gestalteter Empfang und räumlicher Hall ergänzen sie.
SDFGI, SSIL, SSAO, SSR, Raumreflexionen, weiche Lichtschatten, TAA und beleuchteter
Volumennebel werden je nach Grafikprofil auf moderner Hardware aktiviert.
Die Web-Fassung behält die leichtere Szene; native Modelle und Materialkarten
werden aus ihrem Paket ausgeschlossen. Regeln und Spielstände bleiben gemeinsam.

`--render-qa` erstellt isolierte GPU-Aufnahmen und einen Messbericht unter
`%TEMP%/NachtwacheNativeQA`. Alternativ `--capture-dir=<absoluter Pfad>`.
Dieser Modus nutzt eigene QA-Spielstände und zeigt Bewegung, Sprung, Grafik-
wechsel sowie repräsentative Anomalien. Die Bildprüfung erfolgt auf einer RTX
4080 bei 1536×1024; andere GPUs und Auflösungen sind noch nicht systematisch geprüft.

## Kinderparadies 1.3

Die Halle wächst von etwa 460 auf 880 Quadratmeter bei 7,4 Metern Deckenhöhe.
Der Empfangstresen ist jetzt 96 Zentimeter tief und 2,9 Meter lang, mit passenden
Requisiten statt einer riesigen Tischplatte. Die erste Kletteranlage wird höher
und breiter, eine zweite Anlage mit begehbaren Rampen und einer Hängebrücke
kommt hinzu. Der größere Partyraum besitzt Bastelplätze, Kinderhocker,
Geschenke, Geschirr und Wandzeichnungen; weitere Spielzonen füllen die Halle.

Ein etwa zehn Meter langes originales aufblasbares Krokodil hat modellierte
PVC-Kammern, Schweißnähte, Zähne, Augen, Ventil und Halteösen. Die begehbare
Hüpf-Fläche erhöht die Sprunghöhe mit Leertaste. Das ist eine federnde
Charakterphysik, keine vollständige Softbody-Simulation.

Sieben neue Anomalien ergänzen den Katalog auf 43: zuspringender oder dich
beobachtender Hase, atmendes oder sich aufbäumendes Krokodil, folgende oder
plötzlich anschwellende Ballons und ein selbstständig schaukelndes Pferd.
Die drei Schreckmomente lösen einmal pro Runde bei Nähe, Blickkontakt und
freier Sichtlinie aus. Bewegungen, Geräusche und Reaktion pausieren gemeinsam.
Der erste Referenzrundgang bleibt normal; Schreckmomente verursachen keinen
zusätzlichen Tod und ändern die Rot-/Grün-Entscheidungsregel nicht.

36 native Modellinstanzen aus 13 Modelltypen. Neue Grundfläche und Mechaniken
sind auch im Web vorhanden. Ab Version 1.3.1 ist das überarbeitete Krokodil-Modell
ebenfalls gemeinsam; die aufwendigen PC-Lichteffekte bleiben der Windows-Fassung
vorbehalten.

## Krokodil 1.3.1

Die alte Web-Ersatzgeometrie wird vollständig durch das gemeinsame originale
3D-Modell ersetzt. Flache lange Schnauze, Ober- und Unterkiefer, kleine
eingelassene Glasaugen mit detaillierter Iris, unregelmäßige schmutzige Zähne,
PVC-Schweißnähte, Falten und gealterte Haut. Gleichmäßige Texturdichte beseitigt
verzogene Streifen. Das große schwebende Schild weicht einer kleinen Plakette.
Beim Erschrecken schließt sich der separat modellierte Oberkiefer; Bewegung und
Ton halten in der Pause an. Hüpf-Fläche, Kontrollweg und Spielregeln bleiben
gemeinsam. Die Taschenlampe verwendet im Compatibility-Renderer korrigierte
Schattenflächen und einen eigenen Bias gegen diagonale Streifen auf Wand und
Figur. Prompts und Dateipfade in `art/PROMPTS-CROCODILE.md`.

## Umgebung 1.6.0

Das Ostgerüst und seine Rampen stehen vollständig vor der Partyraumwand;
die Brücke verbindet die tatsächlichen Plattformhöhen. Alle sechs Stühle
zeigen zum Tisch, auch das importierte Windows-Modell. Verschwundene Stühle
lassen keine unsichtbaren Kollisionen zurück. 360 Bälle sind mit Abstand
geschichtet; lose Physikbälle starten außerhalb des dekorativen Bällebads.
24 gerahmte Gemälde und gedruckte Schilder ersetzen schwebende Wandtexte.
Die Öffnungszeiten bleiben als gedruckte Variante Teil des Anomaliekatalogs.

Originale kurze Materialgeräusche für Gummi, Holz, Stoff und Kunststoff ersetzen
den wiederverwendeten Schritt-Sound. Gehaltene Gegenstände erzeugen keine
Aufprallgeräusche; Rotation, Kraft und Wiederholrate sind begrenzt.
Dichter Nebel ist immer normal, seine blutrote Verfärbung ist eine Anomalie.
Alte Spielstände behalten den Fortschritt und starten einmal am Eingang.
`scene_audit.gd` prüft Wandüberschneidungen, Stuhllehnen und Kugelabstände.
Im Headless-Modus werden die eingereichten Transformationen geprüft, unter
Windows/Web die vom Renderer zurückgelesenen Daten. Prompts, Bilder und
Authoring-Werkzeuge: `art/PROMPTS-POLISH.md`.

Bekannter Engine-Hinweis: Godot 4.6 meldet bei Verwendung von ReflectionProbe
sieben Textur-RIDs beim Prozessende. Im Lauf treten keine entsprechenden Fehler
auf. Upstream: https://github.com/godotengine/godot/issues/122498.

## Spielanlage und Wandmalereien 1.6.0

Der Durchgang zum Partyraum besitzt einen echten 2,4 Meter breiten und drei
Meter hohen Wandausschnitt mit schlankem Holzrahmen. Die Westanlage rückt
zur Seite; Geburtstagstisch und Stühle geben im Nebenraum mehr Platz frei.

Acht Seilnetz-Paneele verwenden dieselben ausgesparten Öffnungen für sichtbare
Seile, gepolsterte Kanten und Kollisionskörper. Einstieg, Rutsche und Brücke
bleiben frei. Gepolsterte Bögen ersetzen den geschlossenen Tunnel. Die neue
U-förmige Rutsche hat eine dicke geformte Schale und einen exakt passenden
Kollisionskörper; die obere Plattform wird an ihrem Anfang ausgespart.
Die Brücke folgt einer durchgehenden begehbaren Fläche zwischen beiden
Gerüsthöhen. Native Zusatznetze und durchstoßende Requisiten entfallen.

Fünf Wandmalereien zeigen originale gealterte Clowns, ein Karussellpferd,
Sonne und Mond sowie unheimliche Stofftiere. Die transparenten Farbabrisse
lassen den vorhandenen Putz durchscheinen. Sie sind beleuchtete Wandoberflächen,
keine schwebenden Schriftzüge. Quelle und Prompt: `art/PROMPTS-MURALS.md`.

`scene_audit.gd` prüft zusätzlich Objekte gegen die intakten Netzflächen.
Die Bewegungstests laufen real durch Partyraumtür, Rutsche und Brücke; Web-QA
prüft die Brücke in beide Richtungen. `--render-qa --geometry-qa` erstellt
gezielte GPU-Aufnahmen dieser Stellen. Buildfehler und Laufzeit-Skriptfehler
brechen die Verpackung auch bei einem Engine-Exitcode von null ab.
## Krabbelröhren und Geräuschkulisse 1.6.0

Ein 15,5 Meter langer, gebogener Tunnel mit zwei Eingängen und drei echten
Polycarbonatfenstern steht hinten in der Halle. Farbige Kunststoffsegmente,
Verbindungsringe, Schrauben, Innenbeleuchtung und ein durchgehender Boden
verwenden dieselbe Geometrie in Windows und Web. Die Kleinkindzone bleibt
neben der Anlage frei; alte Matten, Zaun und Spielstangen ragen nicht hinein.

C halten duckt die Spielfigur, verkleinert den physischen Körper und
verlangsamt sie. Ein Formtest verhindert das Aufstehen unter der Decke.
Außerhalb kann sie wieder normal laufen. Auch Laden eines Spielstands in
der Röhre stellt den geduckten Körper wieder her.

Das frühere globale Regenrauschen entfällt. Leiser tiefpassgefilterter Regen
ist nur noch an der entfernten Wand zu hören. Lüftung, Türknarzen, Rohrklopfen,
Relaisklicken, Tropfen und Kunststoffkontakt ergänzen räumlich verteilte Quellen.
Echte Aufnahmen von Kinderlachen und Weinen wechseln mit Pausen im Tunnel;
außerhalb werden sie gedämpft. Diese Geräusche sind in normalen und anomalen
Runden identisch möglich und beeinflussen die Rot-/Grün-Regel nicht.
Die separate Sound-Zufallsquelle verändert den Anomaliekatalog nicht.

Neue 44. Anomalie: Eine blasse Gestalt blickt durch das Dachfenster.
Sie ist im Referenzrundgang unsichtbar und verschwindet in normalen Runden.
Pause hält Geräusche, Stimmen und Ereigniszeiten gemeinsam an.

Feldaufnahmen: Joseph SARDIN / BigSoundBank, CC0 (Türknarzen mit Axeline T.).
Quelldatei-Prüfsummen, Quellseiten und Bearbeitung in
`assets/ambience/provenance.json`; reproduzierbare Verarbeitung:
`tools/prepare-nachtwache-ambience.py`. Kein Musikloop im Hintergrund.
`--render-qa --tubes-qa` erstellt gezielte Innen-/Außenaufnahmen.
Gesichtstextur der Gestalt: art/PROMPTS-WATCHER.md. Die neue Geräuschkulisse verwendet explizite Stream-Wiedergabe auch im Web und ändert den Pausenzustand nur bei einem tatsächlichen Wechsel. Damit bleiben Ende, Lautstärke und Wiederaufnahme der Aufnahmen zuverlässig.


## v1.7.0 — Küche, Lichtspiel und neue Kreaturen

Der Wartungsbereich führt nun in einen schmalen Flur: links liegt eine verlassene
Küche, rechts das Mini-Kino. Alle Räume sind frei begehbar; es gibt weiterhin
keine verpflichtenden Kontrollpunkte. Der Küchenclown rührt normalerweise mit
einem animierten Löffel in verschimmeltem Essen. Nur die neue 45. Anomalie
`clown_lunge` löst bei Nähe, Blickkontakt und freier Sicht einen einmaligen
räumlichen Sprung aus. Danach bleibt der Clown stehen und beobachtet den Spieler.
Das flackernde NO SIGNAL-Bild, Projektorgeräusch und Topfrühren sind normal.
Pause friert Animationen und Geräusche ein. Spielstände unterstützen beide Räume;
ältere Raumlayouts setzen nur die Position zurück und erhalten den Rundgang.

Das Krokodil ist als gemeinsames GLB neu modelliert: längere Schnauze, kleinere
zurückgesetzte Augen, geformter Gaumen, unregelmäßige Zähne, Schuppenhaut,
Zehen, Schweißnähte, Reparaturen und aufblasbare Kammern. Der Kiefer bleibt für
die bestehende Schnapp-Anomalie beweglich. Die Fenstergestalt trägt prozedurale
dunkelrote Oberflächenspuren auf Gesicht und Händen.

Neue Texturen: `art/PROMPTS-ANNEX.md`; Sounds und Schilder werden reproduzierbar
mit `tools/prepare-nachtwache-annex.py` erzeugt. Das neue Krokodil entsteht mit
Blender im Hintergrund aus `tools/model-nachtwache-crocodile-v3.py`.


## v1.8.0 — Modellierter Clown, Taschenlampe und direkte Übergänge

Der Küchenclown verwendet jetzt ein geschlossenes, dreidimensional ausgeformtes
Kopfmodell mit vertieften Augenlidern, modellierter Nase, Lippen und einzelnen
Haarsträhnen. Blutspuren und Schminke sind Vertexfarben; eine Gesichtsfotografie wird
nicht mehr verwendet. Körper, Kleidung und Kragen sind ebenfalls neu modelliert.
Die Taschenlampe besitzt Griff, Schalter, Kühlrippen, Clip, Reflektor und LED.
Kurze Wackelkontakte treten unabhängig von Anomalien auf und frieren in Pause ein.

Die Küche enthält Hängeschrank, Pfannen, Lüftung, Rohrleitungen, Mauerwerk,
Vorbereitungstrolley und montierte Küchenunterlagen. Am Empfang stehen Monitor,
Standfuß und Tastatur in gemeinsamer Ausrichtung auf dem Pult. Sechs zusätzliche
CC0-Aufnahmen liefern lokale Kühlschrank-, Fliegen-, Geschirr-, Ketten-, Atem-
und Knarzgeräusche. Quellen, Lizenznachweise und Bearbeitung liegen in
`assets/ambience-v180/provenance.json`; die Lautstärke bleibt räumlich begrenzt.

Nach einer Türentscheidung folgt automatisch der nächste Rundgang. Falsche
Entscheidungen spielen davor einen einmaligen, etwa einsekündigen Schreckmoment
mit beleuchtetem 3D-Clown und geschichtetem Sound. Die Serie wird zurückgesetzt;
eine zusätzliche Bestätigung gibt es nicht. Ein kurzer Hinweis erklärt danach
die übersehene Veränderung. Nach 13 richtigen Entscheidungen folgt der Abschluss.

Modelle: `tools/model-nachtwache-props-v180.py` (Blender im Hintergrund).
Audio und Küchenunterlagen: `tools/prepare-nachtwache-v180.py` (Python/NumPy/Pillow).
Keine Änderungen an Benutzerkonten, Chickens oder anderen Minispielen.

## v1.9.3 — Freier Gerüst-Ausgang, Schritte und Hände

Der Gerüsteingang besitzt eine durchgehende Rampe mit ebenem Übergang über die
Netzebene. Die frühere geneigte Box konnte die Kapsel beim Herausgehen an der
Kante festhalten. Die Prüfung läuft nun mittig und seitlich in beide Richtungen,
ohne Springen und Ducken.

Sieben zusätzliche Bearbeitungen echter CC0-Aufnahmen ergänzen die Atmosphäre:
Geh- und Laufschritte, Tropfen, Metallknarzen, Geschirr, Schachtgeräusche und ein
auslaufender Motor. Schritte bewegen sich als unsichtbare räumliche Quelle in
den Gängen. Alle Geräusche pausieren mit dem Spiel und sind keine Anomalien.
Quellen und Bearbeitung stehen in assets/ambience-v193/provenance.json.

Der Küchenclown hat überarbeitete Kopfproportionen, Greasepaint, Schürze und
gefaltete Ärmel. Modellierte Hände mit Fingergelenken, Daumen, Nägeln und
Falten ersetzen die einfachen Handschuhe; auch am Taschenlampengriff ist eine
Hand sichtbar. Die CC-BY-3.0-Attribution der anatomischen Kopfbasis bleibt erhalten.

## v1.9.2 — Spieluhr, Decken und Kino-Gestalt

Der Feierraum ist über einen nach Norden versetzten, freien Eingang erreichbar.
Auf dem Sideboard steht eine modellierte Spieluhr mit drehender Hasenfigur; sie
spielt die gelieferte Musikbox.mp3 räumlich und pausiert mit dem Spiel. Die Datei
liegt für künftige Builds unter NACHTWACHE MUSIKBOX/Musikbox.mp3.

Küche und Kino besitzen sichtbare, gealterte Deckenplatten, Fugen und befestigte
Schutzleuchten. Kurze, versetzte Wackelkontakte betreffen einzelne Glühbirnen und
die Pendelleuchten. Die organisch modellierte Kino-Gestalt krallt sich am
Lüftungsschacht fest: langer S-Hals, verzerrter Pferdeschädel, eingesunkene Augen
und einzeln geformte Zähne. Spieluhr, Flackern und Gestalt sind normale Umgebung,
keine neuen Anomalien. Ältere Spielstände behalten die Serie, werden wegen der
versetzten Tür aber an eine sichere Position gesetzt.

## v1.9.1 — Aufgenommener Chef-Anruf

Die vom Nutzer gelieferte Aufnahme ist in Windows und Web eingebunden. Der
Aufzug wartet auf das Ende der MP3, legt auf und öffnet nach dem Ankunftston die
Türen. Während der Aufnahme werden keine erfundenen Ersatz-Untertitel gezeigt;
der Text-Fallback bleibt für Builds ohne Aufnahme erhalten. Pause, Fortsetzen
und das Überspringen mit gehaltener Leertaste funktionieren auch mit der Stimme.

## v1.9.0 — Fahrstuhl, Chef-Anruf und befestigte Einrichtung

Jede neue Schicht beginnt in einer begehbaren 3D-Fahrstuhlkabine. Das Telefon
klingelt und wird sichtbar herausgeholt. E oder die Schaltfläche nimmt den
Chef-Anruf an. Nach dessen Ende folgen Aufzugsgong und sich öffnende Türen;
der Spieler geht selbst in die Halle. Gehaltene Leertaste (1,35 Sekunden)
überspringt die Szene, ESC pausiert sie einschließlich Audio und Fortschritt.
Eine falsche Entscheidungstür bedeutet Tod: Jumpscare, kompletter Neustart
und erneut das Intro. Auch ein Abbruch während des Todes umgeht den Neustart
nicht. Ein im Intro gespeicherter Spielstand startet wieder im Fahrstuhl.

Die Chef-Aufnahme ist noch nicht geliefert. Bis dahin stehen Untertitel anstelle
einer erfundenen Sprecherstimme bereit. Datei unter `NACHTWACHE INTRO/chef.mp3`
ablegen: Der Build übernimmt sie in Windows und Web, die Aufnahmelänge steuert
den Ablauf. Windows liest außerdem eine `Intro/chef.mp3` neben der EXE direkt;
dafür ist kein neuer Build nötig. Die separate MP3 liegt außerhalb von Git.
Klingeln und Aufzugsgong sind eigene, neu erzeugte Tonsignale.

Die Leuchtstreifen im Klettergerüst und die frei schwebenden Laken entfallen.
Deckenlampen erhalten Befestigungen bis zur Decke; Träger, Rohrschellen,
Dunstabzug und Kinoprojektor sind angeschlossen. Neue Regale mit Böden,
Büchern und Spielzeugkörben ersetzen die leeren Regale. Die Partyraumwand
erhält eine niedrige Kommode mit Geschirr und Geschenken. Zusätzliche
Arbeitsflächen, Vorräte, Fliesen, Geschirr und Reinigungsutensilien füllen die
Küche; die Laufwege und der Vergleichszustand der Anomalien bleiben frei.

## v1.9.4 — Schachtgestalt, Hauptmenü und Modelle

Die Kinogestalt besteht nur noch aus Kopf und langem Hals. Torso, Arme,
Beine und Rippen wurden aus dem GLB entfernt. Der Hals beginnt oberhalb
der Decke in einem 1,25 Meter tiefen, dunklen Luftschacht. Dach,
Akustikplatten und Tragschienen haben dieselbe ausgeschnittene Öffnung.
Ein knochiger Pferdeschädel, tiefe Augenhöhlen, ein verdrehter Unterkiefer,
eingerissene Wangen und unregelmäßige Zähne ersetzen die rundliche Form.

Ein natives Hauptmenü über der echten 3D-Spielwelt ersetzt die alte lange
Menüspalte. Bild-, Audio-, Steuerungs- und Spieleinstellungen sind getrennt:
Sichtfeld, Renderauflösung, Bildratenlimit, V-Sync (Windows), Filmkorn,
Helligkeit, Qualität, Gesamtlautstärke, Raumklang, Chef-Stimme, Maus-Y-Umkehr,
Empfindlichkeit, Kamerabewegung, Fadenkreuz und Bereichsliste werden
auf diesem Gerät gespeichert und tatsächlich angewendet. Zurücksetzen
stellt die Werkseinstellungen wieder her. Im Web begrenzt zusätzlich
der Browser die mögliche Bildrate.

„Jumpscares Off / On“ ist ein Menü-Prank: ein kurzer 3D-Angriff mit eigenem
Klang, anschließend Rückkehr zur gleichen Seite. Er ändert weder den
Spielablauf noch den Fortschritt und überschreibt nie die Gesamtlautstärke.

Der Fahrstuhl hat befestigte Schienen und Handläufe, Verkleidungsfugen,
Schrauben, Schwellenrillen, Lüftungsgitter und Etagenanzeigen. Das Handy
ist ein maßstäbliches GLB mit abgerundeten Kanten, Glas, Kameras, Tasten
und Anschlüssen; Anrufanzeige und Display bleiben echte UI. Eine eigens
modellierte Hand greift um die Gerätekante.

Der Küchenclown trägt einen neu modellierten zusammenhängenden Rumpf,
geformte Hosenbeine, Schuhe und eine dicke, genähte Schürze. Die erhaltene
und weiterhin genannte Scan-Basis hat einen geometrisch geöffneten Mund
mit unregelmäßigen Zähnen und eingerissenen Mundwinkeln.

Alle 45 vorhandenen Anomalien stehen mit Bereich und interner ID in
[ANOMALIEN.md](ANOMALIEN.md). Die Schachtgestalt bleibt normale Umgebung.
