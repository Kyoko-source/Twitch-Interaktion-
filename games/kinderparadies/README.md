# After Play — Kinderparadies

## Ausgeglichene Rundgänge (2.12.2)

Eine frisch begonnene, erfolgreiche Schicht hat **6 Anomalierunden und 7 normale
Runden**. Die erste Runde und die Zeitungsrunden 3, 5, 8 und 11 bleiben garantiert
normal. Auf die acht übrigen Plätze werden sechs Anomalien und zwei weitere
normale Runden zufällig verteilt; alle 28 Anordnungen sind möglich. Dadurch
folgen höchstens zwei Anomalierunden aufeinander. Die 64 Ereignisse stammen
weiter aus einem eigenen gemischten Beutel und wiederholen sich innerhalb
einer erfolgreichen Schicht nicht. Geräusche und gewöhnliche Bewegung bleiben
Atmosphäre und ändern die Türentscheidung nicht.

Die bisherige Mischung von fünf Anomalien zu vier normalen Zufallsereignissen
berücksichtigte die fünf zusätzlich garantierten normalen Runden nicht: Eine
vollständige Schicht hatte im Mittel nur 4,44 Anomalien (34,2 Prozent).
Jetzt beträgt der Anteil über alle Rundgänge 46,2 Prozent. Bestehende
Spielstände behalten ihre bereits gespeicherte Ereignisreihenfolge; die neue
Mischung gilt ab einer neuen Schicht. Die Zeitungsrunden verbrauchen weiterhin
weder Ereignisse noch Zufallszahlen. Fortsetzen würfelt nichts neu.

`--self-test --balance-only` simuliert 2.048 vollständige Schichten, prüft
Schutzrunden, Gesamtverteilung, alle Anordnungen, individuelle Rundenhäufigkeiten,
alle 64 Ereignisse, Wiederherstellung in jeder Rundenart und ältere Spielstände.
Validierung: 18 gezielte Prüfungen, 1.566 Prüfungen im vollständigen nativen
Gesamtlauf sowie beide Web-Abläufe (Kino-Zeitung und kompletter Rundgang samt
Tod/Neustart, 6:7-Verhältnis, Ende 1 und Credits) ohne Fehler bestanden.
Windows-/Web-Paketgrenzen und die lokale itch-Upload-Vorbereitung sind geprüft;
es wurde nichts auf itch.io veröffentlicht.

## Kino-Zeitung und zwei Abschlüsse (2.12.1)

Die 13. richtige Entscheidung endet jetzt mit `ENDE 1/2` und dem vollständigen
Abspann zur Spieluhr. Das Archiv-Ende zeigt `ENDE 2/2` und denselben Abspann.
Ende 1 enthält die Notiz „schau dich für Ende 2 nochmal genauer um in Runde
3,5,8 und 11“ im Bildlauf und nach dem Überspringen bei den Abschlussaktionen.
Es beginnt keine neue Schicht automatisch. Fortsetzen öffnet den erreichten
Abschluss wieder, auch bei älteren gespeicherten 13er-Serien. Ein vollständig
abgeschlossenes Archiv hat bei der Wiederherstellung Vorrang vor Ende 1.
Erst die ausdrückliche Aktion „Neue Nachtschicht“ setzt die Sammlung zurück.
Bereits begonnene Archivaufnahmen aus älteren 13er-Spielständen bleiben dagegen
fortsetzbar; ihr Aufnahmefortschritt und der vorbereitete Abschluss gehen nicht verloren.

Die Zeitung aus Rundgang 5 folgt der leicht eingedrückten Sitzfläche. Der
begehbare, abgerundete Sitzkörper bleibt unverändert; E prüft stattdessen die
tatsächlichen sichtbaren Sitzflächen über einen eigenen Abfrage-Layer. So
blockiert der grobe Laufkörper das Einsammeln nicht mehr, während Rücken- und
Armlehnen weiterhin den Blick auf verdeckte Gegenstände versperren. Alle 24
Sitze besitzen eindeutige Namen, identische Polsterbehandlung und genaue
Interaktionsflächen. Eine Namenskollision hatte die frühere Polsterbehandlung
auf den ersten Sitz beschränkt.

`--self-test --endings-only` prüft den echten E-Strahl vor/hinter dem Sitz,
stehendes und geducktes Einsammeln, gespeicherte Funde, beide Farben der letzten
richtigen Tür, Endkarten, Musik, Hinweis und beide Abschlüsse nach Fortsetzen.
`--render-qa --endings-qa` liefert native Ansichten der Zeitung und beider Enden.
Validierung: 1.547 Prüfungen im Gesamtlauf, 30 abschließende gezielte Prüfungen
und vier Web-Abläufe (Zeitung samt Speicherung, 13-Runden-Ende, vollständiges
Archiv-Ende und alle Kino-Gänge in beide Richtungen) bestanden.

## Fotowand, Kontrollmonitor und physisches Bällebad (2.12.0)

Über der Krabbelröhre an der Südwand hängen sechs vergilbte, schief beklebte
Polaroids, zwei fehlende Abzüge und ein gerahmtes Foto des ehemaligen Teams.
E zeigt die Geburtstags- und Mitarbeiteraufnahmen vergrößert. Die erfundenen
Fotografien wurden mit dem eingebauten OpenAI image_gen erzeugt; der genaue
Prompt liegt privat in `assets/reception-v2120/image-generation-provenance.json`.
Die erwachsenen Mitarbeiter halten die Kostümköpfe mit den daran befestigten
Ohren im Arm; ihre menschlichen Köpfe tragen keine zusätzlichen Tierohren.

Der CRT am Empfang ist von der Besucherseite mit E bedienbar. Sieben Kameras
zeigen dieselbe aktuelle 3D-Welt, einschließlich vorhandener sichtbarer
Anomalien. Kamera 1–7 schalten die Ansichten, ESC beendet die Bedienung.
Keine Kontrollpflicht, keine entfernten Annäherungsangriffe. Bildrauschen
gehört zur normalen Atmosphäre. Nur ein 640×360-Viewport wird eingeschaltet;
beim Schließen wird dessen Renderer vollständig abgeschaltet. Die echten
Kameragehäuse sind an Wand oder Decke befestigt und blenden die eigene Linse
nicht in die Aufnahme ein.

Alle 360 Bälle besitzen kugelförmige RigidBody-Kollisionen mit Schwerkraft,
Reibung, Rückprall und gegenseitigem Kontakt. Eine gemeinsame MultiMesh zeichnet
die tatsächlichen Körperpositionen. Schritte und Sprünge verdrängen die Bälle,
ohne dass ihre Kollisionen den Spieler festhalten. Pause friert die Körper
mitsamt ihren Geschwindigkeiten ein. Bei `balls_missing` verschwinden auch die
Kollisionen; `balls_float` hebt ein Drittel der echten Körper kontrolliert an.
Spielerbewegungen bleiben ausdrücklich keine Anomalie.

Neu: `wc_stall_watcher`, `wc_ceiling_guest` und `snackbar_visitor` (64 insgesamt).
Startkollisionen bei `pit_runner`, `reception_peeker`, `reception_queue` und
`party_guests` wurden beseitigt; die Warteschlangen stehen frei von Theke,
Stühlen und Abfalleimer. Der bleibende Hinweis bei `vent_strike` berücksichtigt
jetzt den Kino-Offset. Alle 37 Besucher-Szenarien werden zusätzlich auf reale
Startkollisionen, begehbare Sichtpunkte und echte Annäherungsauslöser geprüft.
Der Gesamtlauf bestand 1.520 Prüfungen; nach der abschließenden Kameraplatzierung
bestanden weitere 130 gezielte Prüfungen und sechs echte Web-Abläufe.
Native-Render-QA und Playwright prüfen Bedienung, Ansichten und Physik.
Browser plugin not available: Web-Tests laufen
im vorhandenen Playwright-/Edge-Aufbau. Entwicklercode `0712` bleibt erhalten;
Zeitungsrunden 3, 5, 8 und 11 bleiben vollständig anomaliefrei.

## Umgebung und Schlussaufnahme (2.11.0)

An der südlichen Wand neben den Arcade-Automaten stehen ein geschlossener
Snackbar-Tresen und ein alter Fotoautomat. Hinter dessen teilweise geöffnetem
Vorhang liegt ein mit E ansehbarer Fotostreifen. Das korrigierte Bild zeigt den
Mitarbeiter ohne Ohren am menschlichen Kopf; die Ohren gehören zum abgenommenen
Kostümkopf. Beide abgeschnittenen Kabelenden des trotzdem summenden Automaten
sind sichtbar. Der Vorhang bewegt sich leicht durch die Lüftung.

Ein echter Durchgang in der Ostwand führt zum Kinder-WC mit eigener Decke,
grünlichen Fliesen, drei niedrigen Waschbecken, beschädigten Seifenspendern,
offener und verriegelter Kabine sowie Kondenswasser, das in einen Metalleimer
tropft. Dort erhalten Schritte einen eigenen kleinen Raumhall. Fortsetzen
behält die Position im neuen Raum. Verkleidung, Schmutzflächen und die alten
Schaumstoffklötze wurden am Zugang entfernt bzw. versetzt.

Kompressor, Automatenbrummen, Luft und Tropfen sind normale Atmosphäre und
verändern keine Anomalie oder Entscheidung. Bewegung und Audio pausieren mit
dem Spiel. Schallquellen benutzen den vorhandenen Umgebungslautstärke-Regler.
Die Snackbar hat zwei verschmutzte Slush-Maschinen, eine vergilbte DM-Speisekarte,
altes Essen unter dem Tresen und einen verschimmelten Getränkebecher.

Nasse Flächen haben weiche Ränder, geringe Rauigkeit und Glanz im Taschenlampenlicht.
An Halterungen sitzen Rostspuren; die Kinositze besitzen eine eingedrückte,
geschlossene Polsteroberfläche bei unveränderten glatten Kollisionskörpern.
Nach den Credits folgt eine 16 Sekunden lange ruhige Aufnahme des normalen,
leeren Hauptraums. Nur die bereitgestellte Spieluhr läuft, die Beleuchtung erlischt
und das Bild blendet schwarz aus. Danach erscheinen die Abschlussaktionen.
Gehaltene Leertaste kann auch diese Aufnahme überspringen. Licht und Kamera
werden beim Verlassen wieder korrekt hergestellt.

Der Fotostreifen wurde mit dem eingebauten Bildwerkzeug erzeugt und gezielt
korrigiert. Asset: `assets/life-v2110/photostrip-v2.png`. Die beiden verwendeten
Prompts stehen in `assets/life-v2110/image-generation-provenance.json`; diese
Entwicklerdatei wird nicht mit dem Spielerpaket exportiert. Die vier neuen
Geräuschdateien sind projektintern synthetisiert; reproduzierbar mit
`tools/build-after-play-life-audio.py`. `0712` bleibt als Erstellerzugang aktiv.

Eigenständiges 3D-Anomaliespiel, Godot 4.6.2 / GDScript. Gemeinsames Projekt für
Windows x86_64 und WebGL 2.0. Die Windows-Fassung läuft offline ohne Browser,
WebView, Aviary-Konto oder Anmeldung.

## Spielen

`AfterPlay.exe` aus dem Windows-ZIP entpacken und starten. Im Web auf Aviary
unter `/#games/after-play` öffnen und „Im Web spielen“ wählen.

WASD / Pfeiltasten bewegen, Maus umsehen, Umschalt schneller gehen, Leertaste
springen, G Gegenstand aufheben/loslassen, linke Maustaste werfen, F Taschenlampe,
E Tür öffnen, TAB Dienstanweisung, ESC Pause, F11 Vollbild.
Die erste Runde ist normal und dient als Referenz. Bereiche kannst du freiwillig
erkunden; beide Türen sind jederzeit wählbar. Keine Anomalie: grüne Tür.
Anomalie: rote Tür. 13 richtige Entscheidungen
in Folge gewinnen. Eine falsche Tür löst im Flur einen tödlichen Angriff aus, zeigt die überlebten
Runden und lässt dich ohne neuen Chef-Anruf im Startfahrstuhl erwachen. E nimmt den Chef-Anruf an; gehaltene Leertaste überspringt das Intro.
64 Anomalien, ohne Wiederholung innerhalb des Anomalie-Beutels. Normale und
veränderte Runden werden unabhängig vom gewählten Türtyp gemischt.
Die Zeitungsrunden 3, 5, 8 und 11 sind garantiert normal: keine Anomalien und
keine Anomalie-Jumpscares. Dort ist die grüne Tür die richtige Entscheidung.
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

Ergebnisse: `build/windows/AfterPlay.exe`, `build/web/`,
`build/after-play-windows-v2.12.2.zip`. `-WithQA` erzeugt zusätzlich eine separate
Web-Prüffassung mit Test-Hooks; diese darf nicht veröffentlicht werden.

Die Spielerpakete werden über `tools/package-kinderparadies.ps1` aus den Exporten
erstellt. Windows enthält ausschließlich `AfterPlay.exe`, `STARTEN.txt` und
`Lizenzen/`. Die Aufnahme ist in der EXE eingebettet. Interne Anomalienlisten,
Veröffentlichungsentwürfe, Prompts und technische Provenienzdateien bleiben im
Projekt. Das öffentliche Web-Paket wird aus einer festen Liste der benötigten
Engine-Dateien aufgebaut; auch dort liegen Nachweise nur in `Lizenzen/`.
Für Deployment und Browser-ZIP ist `build/browser-package/` maßgeblich, nicht
der rohe Exportordner `build/web/`. Jeder Paketlauf leert nur die dafür
vorgesehenen generierten Ausgabeverzeichnisse und lehnt Verzeichnislinks ab.

`Godot_v4.6.2-stable_win64_console.exe --headless --path games/kinderparadies -- --self-test`
prüft Logik, Save/Restore, alle Anomalien, Bewegung, Boden und beide Tür-Raycasts.
Tests verwenden eigene QA-Spielstände. Die öffentliche EXE enthält keine
Testskripte und ignoriert die früheren Test-Startargumente. Für die gezielte
Archivprüfung im Editor-Binary zusätzlich `--release-only` verwenden.

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
kommt hinzu. Der größere Party Raum besitzt Bastelplätze, Kinderhocker,
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

Das Ostgerüst und seine Rampen stehen vollständig vor der Party Raumwand;
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

Der Durchgang zum Party Raum besitzt einen echten 2,4 Meter breiten und drei
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
Die Bewegungstests laufen real durch Party Raumtür, Rutsche und Brücke; Web-QA
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

Der Party Raum ist über einen nach Norden versetzten, freien Eingang erreichbar.
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
Büchern und Spielzeugkörben ersetzen die leeren Regale. Die Party Raumwand
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

Alle 58 vorhandenen Anomalien stehen mit Bereich und interner ID in
[ANOMALIEN.md](ANOMALIEN.md). Die Schachtgestalt bleibt normale Umgebung.


## v2.0.0 — After Play und die zurückgelassene Geschichte

Das Spiel heißt in Menü, HUD, Fenster, Web-Seite und Windows-Metadaten
After Play. Die bisherige Web-Adresse bleibt als Alias erhalten. Der interne
Speicherordner bleibt absichtlich gleich, damit alte Spielstände und
Einstellungen durch die Umbenennung erhalten bleiben.

E sammelt den vergilbten Zettel und gefundene Zeitungen ein. TAB öffnet das
Inventar; die Dienstanweisung bleibt darin erreichbar. Im Leser stehen die
Artikel als gut lesbarer Text über einer alten Papieroberfläche. TAB oder
ESC schließt den Leser wieder. Solange er offen ist, pausieren Bewegung,
Rundgang und Raumgeräusche.

Vier Zeitungsausgaben erscheinen in den Rundgängen 3, 5, 8 und 11.
Die erste Meldung nennt den 6. Juni. Jede Ausgabe erzählt einen weiteren
Teil der Geschichte des Happyland. Gesammelte Dokumente bleiben bis zum
Ende dieser Schicht erhalten und werden zusammen mit dem Spielstand
gespeichert. Tod und neue Nachtschicht setzen Sammlung und Archiv zurück.

Die stark verrostete Tür im Wartungsbereich hat einen echten Riegel und
ein vierstelliges Zahlenschloss. Nach dem Fund aller Zeitungen lässt sich
die Kombination aus den Artikeln erschließen. Der optionale Archivraum
ist begehbar und wieder verlassbar. Er enthält weitere Unterlagen, löst
jedoch kein alternatives Ende aus und ersetzt keine der 13 Türentscheidungen.
Der Raum, seine Tür und Dokumente zählen nicht als Anomalien.

Druckseiten, Texte, Papier, Aktenblätter und Türmaterialien sind eigens
für das Spiel gestaltet; es werden keine echten Vermisstenfälle verwendet.


## v2.2.0 — Die Besucher

20 entfernte Anomalien wurden durch neue Begegnungen ersetzt, verteilt über Empfang, Bällebad/Kletteranlage, Party Raum, Wartungsgang, Küche, Kino und Krabbelröhren. Kurze Verfolgungen respektieren die Raumkollisionen und lassen einen erkennbaren Resthinweis zurück. Bewegung, Animationen, Schreckgeräusche und Verfolgungsschritte pausieren gemeinsam. Die neuen Besucher sind nicht in normalen Runden vorhanden.

Die Gestalt am Dachfenster der Röhre wird unmittelbar nach dem Verlassen ausgeblendet. Auch die neue Tunnelverfolgung und die Fensterhände sind nur im Inneren zu sehen.

Das Kino zeigt eine eigenständig modellierte knöcherne Schachtkreatur mit tiefen Augenhöhlen, beschädigtem Gebiss und einem Wirbelhals. Das Party Raum-Fresko greift vier leere Stühle als wiederkehrendes Motiv auf. Die vier Zeitungen enthalten eigens generierte fiktive Archivfotos, lesbaren Spaltensatz und beschädigte Papierkanten. Im Inventar bleibt zusätzlich eine Lesefassung erhalten.

Bildmotive: eingebautes OpenAI-Bildwerkzeug, Projektdateien `assets/story/archive-photos-v21.png` und `assets/creatures/party-fresco-v21.png`. Die Prompts beschreiben vier fiktive Schwarzweiß-Archivaufnahmen des Happyland sowie ein gealtertes Clown-Theaterfresko mit vier leeren Stühlen. Keine echten Vermisstenfälle oder fremden Zeitungsscans. Die beiden 3D-Modelle werden durch `tools/model-after-play-nightmares.py` in Blender erzeugt.

## Update 2.1.0

Zwanzig bisherige Anomalien wurden durch körperliche Begegnungen, kurze
Verfolgungen und Schreckmomente in Empfang, Spielhalle, Party Raum,
Wartungsgang, Küche, Kino und Krabbeltunnel ersetzt. Alte Spielstände werden
auf die neuen Ereignisse umgestellt. Alle Röhrengestalten sind ausschließlich
von innen sichtbar. Ein eigenständig modellierter Pferdeschädel hängt an
seiner langen Wirbelsäule im dunklen Kinoschacht; ein neues originales
Clownfresko schmückt die Partywand. Die Zeitungen haben fotografische Motive,
Satzspalten, eingerissene Ränder und gewelltes Papier.

Der Türzettel ist handschriftlich. Die Küchenleuchte hat kurze synchronisierte
Kontaktfehler; Spülbecken, Schwanenhals-Armatur, Topf und Eimer besitzen echte
Innenflächen. Das Bällebad nutzt eine vorberechnete unregelmäßige Schüttung
mit 4 mm Abstand zwischen den Kugeln. Das Krokodil hat einen vollständigen
Hinterkörper mit Rückenpanzer und langem Schwanz. Der Serverraum besitzt
Boden, Decke, Wände und einen freien Durchgang; Speicherstände in diesem
Raum werden fortgesetzt. Geräusche pausieren beim Lesen und im Pausenmenü.

## Archivfinale und Erstellerzugang (2.2.0)

Der frühere Erstellerzugang ist seit der bereinigten Spielerfassung entfernt.
Das Archiv benötigt die vier Zeitungen und den regulären Rätselcode.

Im Archiv liegen angekettete erwachsene Skelettreste und ein Kassettengerät.
E startet die vollständige Aufnahme aus „Horror Audio Marelle.wma“ (etwa 4:40).
Das Original auf dem Desktop bleibt unangetastet; `assets/finale/marelle.ogg`
ist die vollständige konvertierte Fassung. Pause, Inventar und Einstellungen
pausieren die Wiedergabe; Fortsetzen lädt die gespeicherte Audioposition.
Erst nach dem Ende der Aufnahme und beim anschließenden Umdrehen zur Tür
erscheint der Küchenclown. Danach folgen Schwarzbild, ENDE und rollende Credits.
Ein abgeschlossenes Finale setzt beim Fortsetzen direkt bei ENDE/Credits an.
Leertaste halten überspringt die laufenden Credits und zeigt die Menüauswahl.

Credits: Kyoko – Spielidee, Programmierung und Gestaltung; einsmarello –
zusätzliche Ideen und Konzeptbeiträge; Testspieler: einsmarello, __jerry__,
gingerbread, Mozart. Fremdasset-Quellen bleiben unter Mitwirkende und in den
Lizenzdateien des Windows-Pakets aufgeführt. Der neue bearbeitete Schrei stammt
von A New Room / OpenGameArt (CC0); Quelle und Verarbeitung stehen in
`assets/finale/provenance.json`.

## Ruhige Zeitungsrunden (2.2.1)

Die vier Runden mit Zeitungen bleiben immer anomaliefrei, auch wenn das
Fundstück bereits eingesammelt wurde. Die normale Raumkulisse bleibt bestehen.
Der Anomalie-Beutel und die Zufallsfolge werden für diese Runden nicht verbraucht.
Alte Spielstände auf einer Zeitungsrunde werden beim Laden auf einen normalen
Rundgang umgestellt; Fortschritt und Sammlung bleiben erhalten.

## Türsperre während der Archivaufnahme (2.2.2)

Beim Start der Aufnahme schließt und verriegelt sich die echte Archivtür.
Die Sperre bleibt bei Pause und beim Fortsetzen des Spielstands bestehen.
Erst das tatsächliche Ende der Aufnahme entriegelt und öffnet die Tür wieder.
Die Aufnahme lässt sich nur vollständig innerhalb des Raumes starten.
Ältere Spielstände mit laufender Aufnahme außerhalb des Archivs setzen den
Spieler beim Fortsetzen sicher zum Aufnahmegerät in den Raum zurück.

## 16:9, Partywand und Abspannmusik (2.3.0)

Die logische Bildfläche beträgt 1920 × 1080. Windows startet im 1600 × 900-
Fenster; bei anderen Fensterformaten bleiben korrekte Proportionen mit schwarzen
Rändern erhalten. Auch die Web-Einbettung hält 16:9 im Fenster und Vollbild ein.
Der Sicherungskasten hängt im Serverraum an der Westwand, außerhalb der Tür.
Das große Clownfresko befindet sich an der anschließenden freien Südwand des
Party Raums; der zugehörige Anomalie-Besucher steht ebenfalls unter dem Bild.
Die originale Musikbox.mp3 aus dem Party Raum begleitet die rollenden Credits,
wird sanft eingeblendet und endet beim Überspringen bzw. Verlassen des Abspanns.
Die Gesamtlautstärke gilt weiterhin. Die Originaldatei wurde nicht verändert.
Im Web werden Spielstand und Einstellungen zusätzlich unmittelbar lokal
gesichert, damit selbst ein Neuladen direkt nach Pause die jüngste Audioposition
behält. Bestehende Browser-Spielstände werden weiterhin übernommen; die
isolierte Web-Prüffassung verwendet eigene Speicherschlüssel.

## Kollisionsprüfung, Maskottchen und Raumgestaltung (2.4.0)

- Physische Boxen sind Kinder ihrer sichtbaren Geometrie. Positions-, Drehungs- und Skalierungsänderungen bewegen die Kollision zuverlässig mit. Der Tresen besitzt eine physische obere Platte. Importierte Kartons erhalten passende konvexe Formen; die Windows-Stühle verwenden ihre echte Modellgeometrie anstelle der alten Platzhalterkollisionen.
- Ein über fünf Meter hoher, deformierter Stoffhase steht mit genähten Reparaturen, fehlendem Knopfauge, offenen Nähten, Blutflecken und geometrischen Fellbüscheln in der hinteren Hallenecke. Die Figur ist Teil der normalen Umgebung. Die Lichtaufhängung reicht bis zur Decke; Laufwege und Krabbeltunnel bleiben frei.
- Der Server-/Wartungsraum enthält nun eine Werkbank, Werkzeuge, Reparaturteile, Kabelrollen, Unterlagen und einen rostigen Metallboden. Der Wartungsgang erhält angeschlossene Leitungen und montierte Hinweisschilder.
- Das Kino erhält echten verschmutzten Teppich, montierte Akustikpaneele, einen Projektionsarbeitstisch mit Filmspulen, Plakate, Gangmarkierungen, Sitzdetails und gefaltete, zerrissene Vorhänge mit physischer Aufhängung.
- Schritte werden über einen tatsächlichen Strahl auf den Untergrund ausgewählt: Beton, Teppich, Metall, Holz, Gummipolster und Kunststoff. Fünf Varianten pro Oberfläche vermeiden direkte Wiederholungen; Tempo, Landung und Krabbeln beeinflussen die Wiedergabe. Grundlage sind Kenneys CC0-Aufnahmen, einschließlich dokumentierter Mischungen für Metall, Kunststoff und Polster.
- Das Intro zeigt ein physisches Handy mit einer eigenen hochauflösenden Anrufoberfläche, Live-Gesprächszeit, feinerem Griffmodell und vernähtem Ärmelabschluss. Die originale Chef-Aufnahme bleibt unverändert.
- Neue CC0-Materialien von Poly Haven: Curly Teddy Natural, Dirty Carpet, Metal Grate Rusty. Alle Herkunftsangaben und Prüfsummen sind in `assets/polyhaven-provenance.json` dokumentiert; die Originalaufnahmen zusätzlich in `assets/surfaces/provenance.json`.
- Der Build erstellt zusätzlich `build/after-play-web-v2.4.0.zip` mit `index.html` im Hauptverzeichnis. `ITCH-SEITE.md` enthält die Veröffentlichungsvorbereitung und den Seitentext. Die itch.io-Seite selbst wird dadurch nicht veröffentlicht.
- `--self-test --polish-only` prüft die neuen realen Laufwege, Materialwechsel, Modellabstände und Telefonzustände. Die vollständige Validierung enthält diese Prüfungen ebenfalls.
- Ein verspätetes synthetisches Mausereignis beim Aktivieren der Maussteuerung wird verworfen; nachfolgende echte Mausbewegungen bleiben wirksam. Die HUD-Markierung verwendet ein im eingebetteten Font verfügbares Pluszeichen.

## Hauptmenü, Fell und bebilderte Archivaufnahme (2.5.0)

- Neues Hauptmenü mit einer langsamen Kamerafahrt vor dem echten 3D-Maskottchen, schmaler Bodoni-Moda-Typografie, deutlichem Hover-/Tastaturfokus und echtem Fortsetzen-Zustand. Alle sechs Aktionen sind native Controls. Das frühere idealisierte KI-Menümotiv wird nicht mehr angezeigt. „Abandoned Arcade.mp3“ läuft in einer Schleife; unter Audio lässt sich die Menümusik separat regeln oder stummschalten. Die Originaldatei liegt unverändert im Ordner `AFTER PLAY MENUMUSIK` im Repository-Hauptverzeichnis. Party-Spieluhr und Abspann behalten ihre eigene Musik.
- Die Windows-Fassung erhält feinere Rauigkeits- und Normaloberflächen auf Metall, korrodierte statt holzgemaserte Rostteile, glänzende PVC-Polster und gewebte Kinobezüge. Gerichtetes Projektorlicht, kühlere Leinwandreflexion, besser abgegrenzte indirekte Beleuchtung und Kontaktverschattung geben mehr Tiefe. Nebel bleibt im normalen Rundgang vorhanden, verdeckt aber weniger Details. Schatten der Küchenlampe, Werkstattbeleuchtung und Leinwandbeleuchtung folgen nun der tatsächlichen Grafikqualität.
- Der riesige Hase trägt gebogenes geometrisches Fell: rund 56.000 Fasern in der Windows-Fassung und 14.000 in der Web-Fassung. Eine projizierte Blutauflage folgt der echten Körperoberfläche; geronnene Bereiche, feuchte Glanzstellen und verklebte Fasern ersetzen die bisherigen großen roten Farbflächen. Neue Bluttexturen werden auch auf dem Werkstatttuch und am Maskottchenboden verwendet.
- Zwei Kabel verliefen sichtbar durch die Wartungstür; ihre Abschnitte enden jetzt neben den Rahmen. Wartungsleitungen wurden oberhalb der Bilder verlegt und der Feuerlöscher hängt mit Abstand zu Tür und Wandbild. `SceneAudit.placement` prüft sichtbare Dekoration an Türen, den Fahrstuhl, beide Entscheidungstüren und überlappende Wandkunst; der geöffnete Archivdurchgang wird zusätzlich geprüft.
- Die vollständige, unveränderte Marelle-Aufnahme steuert eine Rückblende aus elf KI-generierten Szenen mit langsamer Kamerabewegung und Überblendungen. Die Zeitmarken stammen aus einer lokalen Transkription und wurden den erzählten Ereignissen zugeordnet. Details: `art-direction/v250/NARRATION.md` und `assets/presentation-v250/memories.json`.
- Während der Aufnahme bleibt der Spieler in der Rückblende; ESC pausiert Ton und Bild. Speichern und Fortsetzen stellen die tatsächliche Audioposition samt passendem Bild wieder her. Nach der Aufnahme kehren Archiv und Steuerung zurück; Umdrehen, Koch-Schreckmoment, ENDE und Credits behalten ihren Ablauf.
- `--self-test --v250-only` prüft Menü, Öffnungen, Bilddateien, Zeitmarken, Audiobindung, Bewegungssperre, Pause und Wiederaufnahme. `--render-qa --v250-qa` erstellt native Aufnahmen aller elf Erinnerungen sowie der überarbeiteten Räume und des Hauptmenüs.
- Windows- und Web-Pakete enthalten nur die passende Fell-Fassung. Generierungs-Prompts, Prüfsummen, Herkunft und OFL-Schriftlizenz werden mitgeliefert. Die Menü-Konzeptbilder werden als Entwicklungsunterlagen behalten und nicht ins Spielpaket exportiert.


## Stoffmaskottchen und dichterer Nebel (2.5.1)

- Die großen Figuren sind jetzt vom vorhandenen kleinen Stoffhasen abgeleitet: dieselben texturierten Plüsch- und Stoffoberflächen, dünne anliegende Nähte und ein echter Riss durch den Bauchflicken. Dunkles Innenfutter, ausgefranste Stoffränder und unregelmäßige Füllwatte ersetzen die alte aufgesetzte Wunde und die langen, stacheligen Fellfasern. Die Originalfigur auf der Bank bleibt erhalten.
- Ein zusätzlicher großer Hase steht rechts nach dem Betreten des Party Raums. Beide großen Hasen gehören zur normalen Umgebung und sind keine Anomalien. Das Wandbild wurde etwas nach links verschoben und verkleinert; sein Anomalie-Auslöser folgt ihm. Regal und Sideboard lassen Abstand zu den Pfoten und zu den Laufwegen.
- Windows verwendet etwas dichteren beleuchteten Volumen- und Bodennebel. Der Grundnebel der Web-Fassung ist ebenfalls leicht erhöht. Normale Nebelfarbe, Zeitungsrunden und Anomalie-Regeln bleiben gleich.
- Menümusik, Archivaufnahme, Credits und der reguläre Archivzugang bleiben erhalten. Modelle und Bildnachweise: assets/mascot-v251/LICENSE.txt; reproduzierbare Geometrie: tools/model-after-play-mascot-v251.py.


## Rückkehr, Küche und Schreckmomente (2.6.0)

- Nur ein großer Stoffhase, ausschließlich rechts im Party Raum. Die kleine Bankfigur bleibt. Das reale 3D-Menü zeigt den Party Raum.
- Die Dienstanweisung enthält die vom Autor gewünschte kurze Einleitung und Tastenliste, ohne Rätsel- oder Anomalieauflösung.
- Neue modellierte Küchenschränke, Arbeitsplatten, Herd und Kühlschrank mit versenkten Fronten, Dichtungen, Scharnieren, Griffen, Brennerringen, Ofenfenster und Gebrauchsspuren. Kollisionsformen folgen den Möbelmaßen; das Spülbecken bleibt ausgespart.
- 58 mögliche Anomalien, darunter 13 neue Begegnungen in sieben Bereichen. Acht neue Soundmischungen nutzen die vorhandenen CC0-Kreaturen- und Feldaufnahmen. Einzelne Auslöser, Pause, sichtbare Restspuren und die normalen Zeitungsrunden bleiben erhalten.
- Historisches Verhalten dieser Version: Nach der 13. richtigen Tür führte das Spiel zurück in den normalen Startraum zu einer Hinweiszeitung. Seit 2.12.1 ersetzt ENDE 1/2 mit Credits und Notiz diesen Ablauf.
- Das Archivende bleibt bestehen. Am Ende der Credits folgt die vollständige „Notiz von Kyoko“, mit größerer Leseschrift und langsamerem Bildlauf. Musikbox.mp3 begleitet weiterhin den Abspann.
- Reproduzierbare Quellen: tools/model-after-play-kitchen-v260.py und tools/create-after-play-scares-v260.py. Lizenz- und Soundbearbeitungsnachweise liegen in assets/kitchen-v260 und assets/scares-v260.
- Zusätzliche Prüfungen: --self-test --v260-only und --render-qa --v260-qa.


## Bühne, Kostümraum und Spuren der Nachtschicht (2.7.0)

- Begehbare Geburtstagsbühne mit gepolstertem, geschnitztem Thron, Vorhängen und fest montiertem Bühnenlicht. Eine flache Rampe und ein breiter Durchgang führen in einen vollständigen Kostümraum mit sieben aufgehängten Stoffanzügen, Masken und Schminktisch. Das große Stoffmaskottchen bleibt ausschließlich rechts im Party Raum.
- Der Wartungsraum enthält einen lesbaren Bestandsplan, ein Wartungsbuch und einen von innen eingedrückten Personalspind. E öffnet die Dokumente; beim Lesen pausiert das Spiel. Die Dokumente ergänzen die Geschichte und sind keine zusätzlichen Codehinweise.
- Der Dienstausweis 013 ist unter TAB → Meine Ausrüstung lesbar. Reparaturband und Inventarnummer an der Taschenlampe, ein beweglicher Dienstschlüsselbund mit dezentem aufgenommenem Klang und Gebrauchsspuren am Handy machen die Ausrüstung persönlicher.
- Party Raum: verblichenes Rosé und warmes Bühnenlicht. Küche: kränkliches Gelbgrün. Kino: gedämpfte Pflaumen-/Blautöne. Wartung: kühles Petrol. Backstage: altes Mint. Physische Lampen und lokale Materialien statt eines Bildschirmfilters.
- Neuer verriegelter Lieferflur westlich des Hauptsaals. Die innere Tür lässt sich mit E öffnen und schließen; die Außentür bleibt verschlossen. Keine zusätzliche Entscheidungstür. Die Bewegungssperre verhindert ein Einklemmen an der schwenkenden Tür.
- Drei neue Anomalien, insgesamt 61: ein auf dem Thron sitzender Besucher, ein erwachendes Hängekostüm und ein kurzzeitig sauberer Lieferflur, der nach Lichtausfall verfällt. Entdeckte Kostüm- und Flurzustände bleiben beim Fortsetzen erhalten. Normale Zustände und die vier Zeitungsrunden bleiben frei von diesen Effekten.
- Kollisionsprüfung mit echter Spielerkapsel durch Bühnenrampe, Kostümtür und Lieferflur in beide Richtungen. Alte Wanddekoration wurde aus dem neuen Durchgang entfernt. Speichern, Wiederaufnahme, Pause, sichtbare Türen und Wandkunst werden geprüft.
- Reproduzierbare Modelle und Schlüsselklang: tools/model-after-play-backstage-v270.py; Lizenz und Herkunft: assets/backstage-v270. Prüfungen: --self-test --v270-only sowie --render-qa --v270-qa.

- Reduziertes HUD: Rundgang rechts oben, Fadenkreuz und situationsabhängige Hinweise. Bereichsliste, permanente Tastenlegende, Spieltitel und „kontrolliert“-Einblendungen entfallen im Spiel. TAB → Meine Kontrollliste zeigt ein handschriftliches Blatt mit den im aktuellen Rundgang besuchten Bereichen. Es pausiert das Spiel, wird mit dem Rundgang gespeichert und erzwingt keine Route. Die Dienstanweisung bleibt unverändert. Die lokal mitgelieferte Schrift [Caveat](https://github.com/google/fonts/tree/main/ofl/caveat) steht unter SIL OFL 1.1; Lizenz und Herkunft liegen in assets/backstage-v270.

## Version 2.8

Die Entscheidungstüren liegen an der Südwand rechts der Krabbelröhre. E öffnet
sie, Betreten des Flurs bindet die Wahl. Beide Flure haben echte Kollisionen,
Decken, Beleuchtung und einen Aufzug. Wer die richtige Wahl trifft, steigt ein;
die Türen schließen und öffnen sich direkt im ursprünglichen Startfahrstuhl.
Die falsche Wahl löst einen eigenen 3D-Angriff mit Schrei aus. Auf Schwarz steht
„X Runden überlebt“, dann beginnt Runde 1 im Fahrstuhl ohne wiederholten Anruf.
Neue Schichten beginnen weiterhin mit dem vollständigen Intro. Tod löscht die
Zeitungssammlung; die Zeitungsrunden 3/5/8/11 bleiben anomaliefrei.

Der Kostümraum ist eine Reparaturwerkstatt: Nähmaschine mit Faden und Nadel,
Schnittmuster, Werkzeuge, Ersatzköpfe, Garnrollen, Stoffbahnen, offene Truhe und
handschriftliche Reparaturnotizen. Der freie Gang zum Bühnenausgang bleibt erhalten.
Spielstände speichern Position und verbindliche Flurwahl; unterbrochene Ankunft
oder Tod werden im Startfahrstuhl fortgesetzt. Native Render-QA verwendet einen
eigenen Speicherpfad, getrennt von den Logikprüfungen.

Der neue Flurangreifer verwendet einen verformten 3D-Kopfscan von Lee Perry-Smith
(CC BY 3.0), mit ausgearbeiteten Augen-/Mundhöhlen und unregelmäßigen Zähnen.
Quelle, Bearbeitungen und Lizenz: assets/passage-v280; reproduzierbar über
tools/model-after-play-passage-v280.py. Schrei und Angriff respektieren die
eingestellte Gesamtlautstärke.

## Bereinigte Spielerfassung (2.8.0)

Der frühere Erstellercode ist entfernt. Das Archiv benötigt ausschließlich die vier Zeitungen und den regulären Rätselcode. Alte Spielstände, die nur per Erstellercode geöffnet wurden, gewähren keinen Zugang mehr. Kommandozeilen-Testhelfer sind auf Editor und QA-Builds begrenzt. Entwicklungsunterlagen bleiben im Repository und gehören nicht in Spieler-Downloads.


## Entscheidungstüren und Rückkehr (2.8.1)

Rot und Grün stehen wieder nebeneinander an der ursprünglichen Nordwand
(x = -4,3 / -2,15). Beide Türen haben echte Wandöffnungen und führen durch
getrennte Flure in Fahrstühle. Eine richtige Wahl zählt genau einen Rundgang
und öffnet anschließend den ursprünglichen Startfahrstuhl. Eine falsche Wahl
löst den schreienden 3D-Angreifer aus, zeigt die überlebten Runden und startet
im Startfahrstuhl bei 0; das Telefonintro wird dabei nicht wiederholt.

Die südlichen Ersatzöffnungen sind wieder geschlossen. Küche und Kino liegen
zwölf Meter weiter nördlich, damit die Entscheidungsflure physisch Platz haben.
Der Nebenraum-Flur ist entsprechend verlängert. Decken, Figuren, Lichtquellen,
Geräusche, Laufoberflächen und die beiden Zeitungen folgen den Räumen.
Speicherlayout 11 übernimmt ältere Positionen aus Küche/Kino und setzt alte
Positionen aus den südlichen Entscheidungsfluren sicher in den Startfahrstuhl.
Die bereinigte Paketstruktur und die Entfernung des Erstellercodes bleiben erhalten.


## Einrichtung und Gebrauchsspuren (2.9.0)

17 neue, dauerhaft gleich platzierte Objektgruppen geben dem Happyland mehr
Alltagsspuren. Dazu zählen zwei geformte Arcade-Automaten mit animierten CRTs,
eine verglaste Preisvitrine, Fundfächer, ein abgestellter Kinderwagen, eine
vergessene Tasche und Schuhe auf/an der vorhandenen Wartebank, eine Garderobe,
Eintrittsbänder, gedeckte Geburtstagsplätze, ein Servierwagen, Küchenflaschen,
Abtropfgeschirr, eine Gemüsekiste, ein Popcornwagen sowie Reinigungs- und
Ersatzteilutensilien. Die Tischplätze ersetzen die alten einfachen Teller und
Becher, damit keine doppelte Geometrie ineinanderliegt.

AfterPlayDetails erstellt die Geometrie aus wiederverwendeten Projektmaterialien;
DressingPrint zeichnet eigene, deckende Druckflächen auf die Modelle. Es werden
keine zusätzlichen externen Assets oder Lizenzen benötigt. Bildschirmbewegung
und der sehr leise, räumlich begrenzte Automatenlüfter pausieren mit dem Spiel.
Der Lüfter folgt dem Ambiente-Regler. Die Einrichtung verändert keine Anomalien
und keine Zeitungstermine. Kollisionen folgen den Schränken, Glasflächen und
größeren Wagen; Türdurchgänge werden im Geometrie-Audit mit geprüft.

## Freie Durchgänge und Platzierung (2.9.1)

Der alte importierte Bürotisch ist aus dem verlängerten Nebenraum-Flur entfernt.
Die nativen Küchenkartons folgen nun ebenfalls der nach Norden versetzten Küche.
Unter dem Hinweis zum technischen Dienst hängt ein zusammenhängendes Schlüsselbrett
mit Haken und Schlüsseln statt zweier isolierter, schalterähnlicher Kästchen.

Die Schmutzflächen an der Nordwand liegen ausschließlich auf den festen Wandteilen.
Sie überspannten zuvor die offenen Entscheidungstüren wie eine durchsichtige Wand.
SceneAudit prüft jetzt die vollständigen Flure einschließlich dekorativer Geometrie
und transparenter Overlays. Regressionstests schleusen absichtlich eine Schmutzfläche
und einen nicht kollidierenden Tisch ein und prüfen, ob der Audit beide erkennt.
Zusätzlich werden offene Türflügel und die Bodenunterstützung importierter Kartons geprüft.

## Happyland-Film und offizieller Trailer (2.10.0)

Die Kinositze besitzen jeweils einen zusammenhängenden, an den Ecken abgeschrägten
Kollisionskörper. Der seitliche Gang ist breiter; alle fünf Gänge werden mit
echter Spielerbewegung in beiden Richtungen geprüft. Der Erstellerzugang `0712`
bleibt auf Wunsch aktiv und über Fortsetzen gespeichert. Der reguläre Code
benötigt weiterhin alle vier Zeitungen. Anleitung für die vorbereiteten itch-App-
Updates: [ITCH-UPDATES.md](ITCH-UPDATES.md).

Im Kino liegt auf dem Projektionstisch eine beschriftete, mit E einsammelbare
Filmrolle. Die Wandbedienung neben dem Tisch legt sie in den Deckenprojektor ein
oder stoppt die Vorführung. Der freiwillige Film gehört zur normalen Umgebung;
er verändert weder die Anomalie noch die Rundenzahl. Der Spieler kann frei
weiterlaufen. Die Rolle bleibt während der Schicht und in gespeicherten Spielständen
erhalten; eine neue Schicht oder Tod setzt den Fund zurück.

Das 34-Sekunden-Video zeigt bewegte Aufnahmen derselben Räume in einem helleren,
aufgeräumten Zustand. Absichtlich reduzierte Farbigkeit, Körnung, Filmschrammen,
eine eigene Jahrmarktmelodie und eine lokal erzeugte deutsche Ansage ergeben
einen alten Happyland-Werbefilm. Die 4:3-Projektion behält auf der breiten Leinwand
ihr Seitenverhältnis. Ton kommt räumlich aus dem Kino und folgt dem Ambiente-Regler.
Pause und Inventar halten Bild, Ton und die beiden Filmspulen an. Am natürlichen
Ende sowie beim Stoppen kehrt die Leinwand zu NO SIGNAL zurück. Der Videodecoder
wird erst beim Einlegen geladen; gespeicherte Schichten starten keine laufende
Vorführung ungefragt neu.

Der separate Trailer dauert genau 75 Sekunden: 1920 × 1080, 30 FPS, H.264/AAC,
deutsche Titel, native Spielszenen und Musik/Sounddesign. Das geheime Ende bleibt
ausgespart. `tools/build-after-play-media.py` erstellt die Masterdatei, den alten
Werbefilm, Vorschaubilder und Medienmetadaten aus der privaten Aufnahmeszene
`art-direction/media_capture.tscn`. Der Trailer wird separat als MP4 veröffentlicht
und gehört nicht in den Spiel-Download. Auf der Spielseite lädt er erst nach
Betätigung der Videosteuerung; beim Start des Web-Spiels pausiert er.
