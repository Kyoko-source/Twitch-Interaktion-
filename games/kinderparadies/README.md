# After Play — Kinderparadies

## Neues Hauptmenü (5.8.0)

- Dunkles Glas-Panel mit kaltem Rand über der echten 3D-Szene; der Partyhase steht rechts frei im Raum. Der große AFTER-PLAY-Schriftzug bleibt.
- Gespeicherte Schicht als Karte ganz oben: „Schicht fortsetzen“ mit „Rundgang 04 von 13 · 12 Min. im Dienst“ (`Game.shift_save_info()`).
- Hauptpunkte: Neue Nachtschicht, Weitere Spielmodi, Tutorial. Darunter klein „Extras · Einstellungen“ und „Spiel beenden“, unten „Mitarbeiterzugang · Nachtschicht“.
- Neues Untermenü **Extras** (`NightMenus.extras`): Erinnerungsalbum, Anomalie-Album, Erfolge, Mitwirkende.
- Knopfnamen bleiben `MainMenuAction0`–`6` (0 neu, 1 fortsetzen, 2 Modi, 3 Tutorial, 4 Extras, 5 Einstellungen, 6 beenden). Tutorial-Abbruchbild Karte 1 zeigt das neue Menü. Tests: `--tutorial-only` (29 Prüfungen, inkl. Fortsetzen-Karte), Album-Test prüft Extras.

## Tutorial-Abbruchbild mit echten Screenshots (5.7.1)

- Das Bild nach der dritten falschen Tür zeigt echte, zusammengeschnittene Screenshots statt nachgebauter Kästen: Dienstpause + Hauptmenü („Spiel beenden“), Windows-Taskleiste und Startmenü („Einstellungen“), Einstellungs-Leiste („Apps“), Installierte Apps mit „…“ → „Deinstallieren“ unter After Play. Bilder in `assets/uninstall-v571/` (680×800, halbe Größe angezeigt), Ringpositionen in `AfterPlayTutorial.STEPS`.
- `--tutorial-only` prüft die vier Bilder (27 Prüfungen); mit `--capture-dir=DIR` speichert der Test Hauptmenü, Dienstpause und Abbruchbild.

## Tutorial (5.7.0)

- **Neuer Hauptmenüpunkt „Tutorial“** (`NightMenus.tutorials`): After Play ist spielbar, Partynacht und Nightwatch Protocol stehen ausgegraut daneben („In Development“).
- **After-Play-Tutorial** (`scripts/after_play_tutorial.gd`): Start im Fahrstuhl, großer lila Text „Willkommen zu After Play“: jeden Raum ansehen, dann die grüne Tür. Danach geht es zurück an den Anfang, und der große Partyhase schwebt (Anomalie-Runde, rote Tür). Nach ein paar Sekunden weicht der große Text einer kleinen Erinnerung oben.
- **Falsche Tür in der Anomalie-Runde**: 1× zurück vor den Hasen („Vielleicht hab ich mich nicht richtig ausgedrückt …“), 2× zusätzlich viele blinkende Pfeile durch alle Wände zur roten Tür („Oh man … und du willst 13 Runden schaffen?“), 3× ein Bild mit rot eingekreisten Schritten zum Beenden und Deinstallieren („Spiel einfach mit Bauklötzen oder so“), dann zurück ins Hauptmenü. Rote Tür in der Normalrunde: Hinweis und zurück an den Anfang.
- Im Tutorial wird nichts gespeichert; eine laufende Schicht wird vorher gesichert und bleibt unverändert. Keine Jumpscares, kein Verfolger, kein Pferd, kein Mikrofon-Wächter, der Wachmann schweigt.
- Tests: `--tutorial-only` (26 Prüfungen, auch im vollen Lauf). QA: `--render-qa --tutorial-qa`.

## Nightwatch Protocol: der Stoffhase, Fehlklick-Limit, tickende Uhren (5.6.1)

- **Der Stoffhase ab Nacht 3** (`scripts/nightwatch_bunny.gd`): Anders als Krabbler und Clown läuft er wirklich über die Kameras – Kostümfundus → Snackbar → Party-Tisch → Halle → Empfang → Treppentür. Er bewegt sich nur, solange ihn niemand ansieht: Ist seine Kamera auf dem Hauptmonitor (oder im Vollbild) und schaut man auf die Monitorwand, bleibt er stehen. Pro Raum braucht er unbeobachtet 16–42 s (`bunny` je Nacht in `NightwatchConfig.NIGHT`: 0/0/6/10/14). Bei jedem Schritt quietscht leise ein Spielzeug. An der Tür: Rolltor 2,2 s unten → er fängt wieder im Kostümfundus an; sonst kommt er nach 8–4,5 s herein (Grund `bunny`, „DER HASE IST HEREINGEKOMMEN“, Sprung ins Gesicht). Ein Klick auf ihn im Vollbild zählt nicht als Fehlklick. Ergebnis zeigt „Hase zurückgeschickt“.
- **Maximal 10 Fehlklicks pro Nacht** (`MAX_MISSES`): Die Meldung zählt mit („Fehlklick 3 / 10“), beim zehnten ist die Nacht verloren (Grund `clicks`, „ZU VIELE FEHLKLICKS“).
- **Kameras dunkler**: Belichtung 1,6 → 1,05, Umgebungslicht 0,8 → 0,35, Infrarot 3 → 2, Nebel 0,5 → 0,7.
- **Wanduhr im Kontrollraum** über dem linken Regal: Stunden- und Minutenzeiger zeigen die Nacht (00:00–06:00), der rote Sekundenzeiger springt und tickt jede echte Sekunde, auch im Stromausfall.
- **Die Empfangsuhr im Hauptspiel tickt**: roter Sekundenzeiger, der jede Sekunde springt, mit Tick-Tack direkt an der Uhr (bis ca. 13 m hörbar). Bei der Anomalie „Uhr dreht zu schnell“ rattert sie. Der alte, nicht synchrone Uhr-Loop in `AmbientLife` ist raus. Der Tick ist ein synthetischer Uhrwerk-Klick (`scripts/clock_tick.gd`) und wird von beiden Uhren geteilt.
- **Deckenröhren aus 5.3.1 hängen jetzt an der Decke**: Ihre Höhe kam aus der groben Raumtabelle, dadurch schwebten sie in Küche, Personalflur und Kinder-WC bis zu 90 cm unter der echten Decke, und die Wartungsröhre steckte in der Wand zum Serverraum. Jetzt steht die gemessene Deckenhöhe in `RoomMood.LIGHTS` (`ceiling`); die Wartungsröhre sitzt frei neben der vorhandenen Leuchte, die im Personalflur längs im Deckenraster. Test in `--mood-only` prüft per Strahl nach oben, dass jede Röhre bündig sitzt. QA: `--render-qa --lamps-qa`.
- Tests: `--nightwatch-only` (93 Prüfungen). QA: `--render-qa --bunny-qa` (Hase an jeder Station, Uhr, Tür).

## Nightwatch Protocol (Beta): fünf Nächte bis 06:00 (5.6.0)

- **Nächte 1–5** von 00:00 bis 06:00 Uhr (eine Stunde = 80 s). Wer 06:00 erreicht, schaltet die nächste Nacht frei; jede geschaffte Nacht lässt sich im Menü wieder wählen. Gespeichert wird die letzte geschaffte Nacht (`nightwatch_night`). Alle Werte je Nacht in `NightwatchConfig.NIGHT`.
- **Anomalien sind nur noch Veränderungen am Raum**, keine Besucher oder Erscheinungen mehr: Gegenstand fehlt, schwebt, steht verschoben, ist doppelt, wackelt, fremdes Licht, **schwebende Bälle** über dem Bällebad und **„Raum ganz anders“** (alles im Bild gedreht, verschoben, umgekippt oder auf dem Kopf, grünes Licht). Gedreht wird um die Mitte des Objekts, nicht um seinen Ursprung (manche Requisitengruppen haben ihn weit weg).
- **Beheben mit Linksklick**: Im Vollbild der Kamera auf die Veränderung klicken – sie springt in den Normalzustand zurück. Ein Fehlklick sperrt das Klicken 1,5 s. Meldebuch und Art-Auswahl entfallen.
- **Statuszeile auf jeder Kamera**: 1 offen „WARNING – UNUSUAL ACTIVITY DETECTED“, 2 „ALERT – ANOMALY LEVELS RISING“, 3 „CRITICAL – ANOMALY THRESHOLD EXCEEDED“. Ab 3 offenen (oder einer, die zu lange offen ist) läuft der **kritische Alarm**: rotes Rundumlicht und Ton, immer schneller; in den letzten 7 s flackert das Licht und die Zeile wird groß. Nach 25 s ist die Nacht verloren (gottloser Jumpscare). Anomalien kommen im Lauf der Nacht immer häufiger (Abstand bis auf die Hälfte).
- **Tür links und Schacht rechts**: Die Gestalten laufen nicht mehr über die Kameras, sie sind einfach da, wenn man hinschaut. Kleine Pfeile am linken und rechten Bildrand (oder A/D) drehen den Blick. Krabbler an der Tür: Rolltor runter (Leertaste oder Knopf, **20 % Strom** auf einmal), es geht danach von selbst wieder hoch. Clown im neuen Lüftungsschacht (`scripts/nightwatch_vent.gd`, bodennah, im Dunkeln kaum zu sehen): **Taschenlampe mit F** (10 % pro Einschalten, brennt 3 s) hineinhalten, dann kriecht er zurück. Zu langsam: Sprung ins Gesicht.
- **Strom läuft durchgehend** ab. Reicht er nicht für Tor oder Lampe, hilft nur der Generator: anklicken und die Wörter tippen (Strom wieder 100 %). Bei 0 % wird es dunkel, das Tor geht hoch – auch dann rettet der Generator noch, sonst kommt es nach 8–16 s.
- **06:00**: Glockenton, Karte „06:00 · NACHT n GESCHAFFT“, Ergebnis mit behobenen Anomalien, Abwehr an Tür und Schacht, Generator, Reststrom.
- Erfolge umgewidmet: erste behobene Anomalie, 10 in einer Nacht, eine Nacht überstanden, alle fünf Nächte, fünf Generator-Neustarts, geheim: nach Stromausfall bis 06:00.
- Beim Clown werden die Render-Ebenen außerhalb des Szenenbaums gesetzt; nachträglich umgestellt ließ der Renderer veraltete Lichtpaare zurück und stürzte beim Beenden ab.
- Tests: `--nightwatch-only` (79 Prüfungen). QA: `--render-qa --watch-qa`.

## Nightwatch Protocol (Beta): etwas kommt zu dir, Melden direkt im Bild (5.5.0)

- **Freigeschaltet als Beta** unter „Weitere Spielmodi“ (seit 5.2.4 ausgegraut). Etappe 1 des großen Nightwatch-Ausbaus; Generator neu, lebendigere Kameras und Nächte 1–5 folgen.
- **Der Krabbler kommt** (`scripts/nightwatch_stalker.gd`): Ab der ersten Minute kriecht er auf einer von vier Routen von Kamera zu Kamera Richtung Kontrollraum – sichtbar auf freiem Boden, jeder Standort wird gegen Wände, Möbel und Bildrand geprüft. Auf dem Hauptmonitor beobachtet, bewegt er sich kaum (22 % Tempo). Aus dem letzten Raum hört man ihn im Treppenhaus näherkommen, dann hockt er links in der Tür im Licht einer flackernden Birne. Er ist **keine Anomalie** und wird nicht gemeldet.
- **Rolltor** an der neuen Treppenhaustür links (Blick mit A/←, drei Richtungen: Tür, Monitore, Generator): Knopf am Panel oder Leertaste. Unten kostet es zusätzlich Strom. Ist es unten, kratzt er, schlägt dagegen und zieht ab; ist es oben, hat man 3 Sekunden – oder er kommt herein: Sprung ins Gesicht mit Jumpscare, Schicht vorbei („ES IST HEREINGEKOMMEN“). Tempo und Pausen steigen mit der Stufe (`NightwatchConfig`).
- **Melden direkt im Bild**: Im Vollbild einer Kamera auf die Stelle klicken – der nächstgelegene Bereich ist vorausgewählt (bei mehreren Bereichen umschaltbar), ein Klick auf die Art meldet. Rechtsklick bricht ab. Das Meldebuch bleibt.
- Gemeldete Gestalten nehmen ihre Materialien ab und verschwinden einen Moment später, statt sofort gelöscht zu werden (sonst fragte der Renderer nach schon freigegebenen Materialien).
- Tests: `--nightwatch-only` (71 Prüfungen, neu `nightwatch_stalker_validation.gd`). QA: `--render-qa --watch-door-qa`, `--watch-cams-qa`.

## Mikrofon-Modus: die echte Flüsterstimme (5.4.1)

- Beim dritten Mal flüstert es hinter dir jetzt wirklich: „Dreh dich NICHT um.“ (`assets/mic-v540/whisper.ogg`, eingesprochen mit ElevenLabs, geschnitten von `tools/generate-after-play-v540-audio.py`). Der erzeugte Platzhalter springt nur noch ein, wenn die Datei fehlt.

## Mikrofon-Modus: Weck es nicht auf. Neue Jumpscare-Sounds, Ballons platzen wieder (5.4.0)

- **Mikrofon-Modus** (`scripts/mic_listener.gd`, `scripts/mic_warden.gd`, Einstellungen > Mikrofon, standardmäßig aus): Im Gebäude schläft etwas. Es ist **keine Anomalie** – es entscheidet keine Tür und muss nicht gemeldet werden; das steht im Menü und bei jeder Warnung. Wer etwa eine halbe Sekunde am Stück im roten Bereich ist, weckt es ein Stück:
  1. Alle Lampen flackern gleichzeitig, groß in Rot: „DU BIST ZU LAUT. WECK ES NICHT AUF.“
  2. Ein Schrei hallt durchs Gebäude, stärkeres Flackern: „PROVOZIER ES NICHT.“
  3. Das Flackern wird wild, der Schrei aggressiver – dann ist alles stumm. Du kannst dich nicht mehr bewegen, hinter dir flüstert etwas, dein Kopf dreht sich langsam von selbst um. Da ist nichts. Zwei Sekunden Stille. Dann füllt sein Gesicht den Bildschirm: der gottlose Jumpscare (eigenes Bild, heranrasend, wackelnd, mit Glitch, RGB-Versatz, Blut, Blitzen, zweitem Schlag). Die Nacht ist verloren.
  Drei ruhige Minuten lassen es eine Stufe zurück einschlafen; nach jeder Stufe gibt es 10 Sekunden Schonfrist. Unten links zeigt ein Pegel dauerhaft deine Lautstärke und die rote Zone, daneben drei Punkte für die Stufen. **Jede Runde wird es empfindlicher** (1,1 dB pro Runde, bis Runde 14). Im Menü: Gerätewahl (wichtig bei Voicemeeter & Co.), Empfindlichkeit, Live-Pegel zum Testen. Es wird nur die Lautstärke gemessen, nichts aufgenommen oder gesendet. Nicht in der Web-Version.
- **Flüstern**: Bis die eingesprochene Zeile da ist, flüstert ein erzeugter Platzhalter. Eine Datei `assets/mic-v540/whisper.ogg` (oder .wav/.mp3) ersetzt ihn automatisch (seit 5.4.1 vorhanden).
- **Neue Jumpscare-Sounds** (`assets/jumpscare-v540/sting-1…6.ogg`, aus „Medien After Play und Stream/02 …/Jumpscare Sounds“, Pixabay-Lizenz): Jeder Jumpscare – Besucher, Krabbler, Stromausfall, falsche Tür, Pferd, Clown, Kostüm – legt einen davon über den Schrei, nie zweimal derselbe hintereinander. Neu schneiden mit `tools/generate-after-play-v540-audio.py`.
- **Ballons platzen wieder**: Die Anomalie „Die Ballons blähen sich mit einem Knall auf“ spielte versehentlich einen Schrei. Jetzt quietscht das Gummi und dann platzen mehrere Ballons.
- QA: `--self-test --mic-only`, `--render-qa --mic-qa` (`--mic-menu` für den Einstellungs-Reiter).

## Jumpscares, der Krabbler, Lampen statt Leuchtkugeln (5.3.1)

- **Echter Jumpscare** (`scripts/jumpscare_fx.gd`): Springt dich ein Besucher an (Schreckmomente der Schicht, Stromausfall, falsche Tür), gehört ihm für eine Sekunde der ganze Bildschirm. Das Gesicht kommt bis auf 27 cm heran und füllt das Bild mit seinem Gebiss, dazu Zoom mit Fischaugen-Verzerrung, Bewegungsunschärfe, starke Farbverschiebung, Blutrot, Blutspritzer und herablaufende Tropfen von den Rändern, Bildstörungs-Streifen, Rauschen, ein Blitz, heftiges Wackeln, ein tiefer Schlag und Rauschen unter dem Schrei. Mit "Stroboskop" aus kein Blitz und kein Flackern, mit "Kamerabewegung" aus kein Wackeln.
- **Der Krabbler** (`assets/crawler-v531`, eigenes Image-to-3D-Modell): Er spielt die Krabbelszenen (unter dem Partytisch, Küchenboden, Bällebad-Rahmen, Rutsche) und die Krabbelröhre, statt eines umgekippten stehenden Besuchers. Er huscht wippend auf allen Vieren, bäumt sich beim Angriff auf und wächst dir ins Gesicht. Die stehenden Besucher bleiben überall sonst.
- **Keine Leuchtkugeln mehr**: Die neuen Akzentlichter aus 5.3.0 leuchteten im Raumdunst als Kugeln ohne Lampe in der Luft. Sie färben jetzt nur Wände und Boden; flackernde Röhren und das Empfangs-Neon hängen als echte Deckenleuchten unter der Decke, deren Röhre mitflackert und beim Stromausfall ausgeht. Auch das Gesichtslicht der Angreifer erzeugt keine Kugel mehr im Dunst.
- QA: `--render-qa --jumpscare-qa`, `--crawler-qa`.

## Lichtstimmung, etwas folgt dir, Funkeln an der Abzugshaube behoben (5.3.0)

- **Jeder Raum hat seine eigene Lichtstimmung** (`scripts/room_mood.gd`): Empfang Amber-Neon und Pink, Halle kaltes Blau gegen die warmen Pendelleuchten, Bällebad tiefes Blau mit gelben und grünen Reflexen über dem Bad und Automaten-Glühen, Party Raum Gold und Magenta, Wartung kränkliches Grün, Personalflur kalte Röhre und grünes Notausgangsschild, Küche warmes Zündflammen- und Röhrenlicht, Kino blaues "NO SIGNAL"-Flackern, Kinder-WC Cyan, Eingang Natriumlicht. Auf Forward+ färbt ein Dunstvolumen pro Raum die Luft.
- **Bewegung im Licht**: Röhren und Neon stottern ab und zu, Licht atmet langsam, die Pendelleuchten in der Halle schwingen an ihren Kabeln und werfen wandernde Schatten. Fährt draußen ein Auto über den Parkplatz (Ambient-Sound), streichen seine Scheinwerfer durchs Hallenfenster oder durch den alten Eingang, die Wände werfen dabei Schatten. Die Parkplatzlaternen brennen jetzt orange.
- Kein Hinweis auf Anomalien: gleich in jeder Runde, eigener Zufall, keine roten Akzente (rote Deckenlampen sind eine Anomalie), die Party-Akzente gehen bei "party_dark" mit aus, die warmen Küchenlichter bei "cold_breath". Beim Stromausfall gehen alle Innenlichter aus, Straßen- und Scheinwerferlicht bleiben.
- **Etwas folgt dir** (`scripts/night_follower.gd`): Alle ein, zwei Minuten gehen Schritte hinter dir auf deinem eigenen Weg, im Takt deiner Schritte. Bleibst du stehen, kommt noch ein Schritt zu viel. Drehst du dich um, ist nichts da und es ist still. Drehst du dich nie um, kommt es näher, bis etwas direkt hinter dir atmet und die Taschenlampe stottert. Manchmal fällt stattdessen eine Tür hinter dir ins Schloss. Nur Ton, keine Anomalie, nie während anderer Schreckmomente oder in der Röhre.
- **Funkeln an der Abzugshaube und am Clown behoben**: Die Ursache war die Lederkappe des Küchenclowns. `pow(0, y)` im Shader ergab auf manchen Treibern NaN-Pixel, die Glow und SSR zu aufblitzenden Lichtpunkten unter der Haube aufbliesen (gemessen 8060 flackernde Pixel, jetzt 71, gleich viel wie ganz ohne Clown). Fünf weitere Shader mit `pow(abs(...))` sind vorsorglich abgesichert.
- Leistung: im Mittel +0,2 ms pro Frame (RTX 4080, 1080p, Hoch).
- QA: `--render-qa --mood-qa` (jeder Raum aus einer Ecke), `--render-qa --sparkle-qa` (Kamerafahrt an Haube und Clown, Varianten mit `--variants=`), `--perf-qa --no-mood`; Tests `-- --self-test --mood-only`.

## Anomalie-Album (5.2.8)

- Neuer Menüpunkt **Anomalie-Album**: Jede Anomalie, die man mit der roten
  Tür richtig meldet (Schicht und Endlosmodus), wird ein Polaroid. 68 Karten
  mit Fortschrittsbalken; gefundene zeigen ein echtes Spielfoto mit
  handschriftlicher Beschriftung (Caveat), noch fehlende ein dunkles Foto mit
  Fragezeichen und dem Raum als Hinweis. Ein Klick öffnet das große Polaroid
  mit Raum, ganzer Beschreibung, Datum der ersten Meldung und wie oft man sie
  erkannt hat.
- Neue Einblendung „Neues Polaroid“ mit Stand x / 68; Erfolge „Schnappschuss“
  (10), „Halbes Album“ (34) und geheim „Lückenlos“ (alle).
- Gespeichert in `user://after-play-anomalies.json`, unabhängig von Schicht,
  Tod und neuer Schicht. Umbenannte Anomalien alter Stände werden übernommen.
- Fotos: `--render-qa --album-photos-qa` rendert jede Anomalie im Spiel
  (Schreckfiguren eingeblendet, Taschenlampe an), 
  `tools/develop-after-play-album-photos-v528.py` entwickelt sie zu 640×480
  im Sofortbild-Look nach `assets/album-v528/`. `--album-menu-qa` zeigt das
  Menü. Test: `-- --self-test --album-only` (auch in der Gesamtsuite).

## Mehr Leben, jede Anomalie nur einmal, Partynacht-Spawns, kein Funkeln am Clown (5.2.7)

- **Jede Anomalie höchstens einmal pro Schicht.** Innerhalb einer Schicht zog
  das Spiel schon ohne Zurücklegen, aber jeder Tod (falsche Tür, Pferd) rief
  `PatrolState.start()` auf und mischte den Beutel neu, sodass die Anomalien
  des gescheiterten Versuchs gleich wiederkamen. Ein Tod ruft jetzt
  `retry()`: Fortschritt und Rundenverteilung beginnen von vorn, der Beutel
  läuft weiter. Ein Anomaliebeutel reicht damit für rund neun Versuche, bevor
  sich etwas wiederholt, und auch beim Nachfüllen bleibt alles draußen, was
  der laufende Versuch schon gezeigt hat. Die direkt nach der tödlichen Tür
  gezogene, nie gezeigte Anomalie kommt zurück in den Beutel. Alte
  Spielstände mit doppelten Einträgen (umbenannte Anomalien) werden beim
  Laden bereinigt. Eine neue Schicht aus dem Menü mischt weiterhin neu.
- Multiplayer: Im Rundenplaner kann Spieler 2 jede Anomalie nur einmal
  setzen (erneutes Ablegen verschiebt sie); der Server lehnt doppelte Pläne
  ab.
- **Partynacht: keine Zombies mehr im Krokodil oder hinter Wänden.** Das
  Navigationsraster tastet den Boden mit Strahl und Kapsel ab; unter dem
  hohlen aufblasbaren Krokodil und in Nischen hinter Wänden galten dadurch
  338 Zellen als begehbar, obwohl man sie nie erreicht (28 davon am
  Krokodil). Gegner entstanden zufällig in den gekauften Zonen und konnten
  dort landen. Jetzt füllt `refresh_reach()` vom Start aus die wirklich
  erreichbaren Zellen (neu nach jeder geöffneten Absperrung), und alle
  Spawnwege nutzen nur diese: normale Gegner, Bosse, Risse, Boss-Diener,
  Teleport, Notfall-Platz. Ein Zombie, der 1,5 s außerhalb steht oder 6 s
  festhängt, holt sich einen neuen Platz (Bosse treten auf den nächsten
  erreichbaren Boden).
- **Clownhaare ohne Funkeln.** Das Haar aus 4.0.4 bestand aus 11 000
  Einzelsträhnen, dünner als ein Pixel, plus abstehenden Einzelhaaren. Auf dem
  Bildschirm zerfiel es in lose Punkte, die bei jeder Bewegung flimmerten,
  wie Partikel über und um den Kopf. Jetzt sind es 1 500 verfilzte Büschel
  aus je zwei gekreuzten Bändern, 10–26 mm breit, ohne abstehende Haare
  (`tools/model-after-play-clown-hair-v527.py`, `assets/clown-v527/`). Die
  Faserstruktur kommt aus dem Shader und blendet aus, bevor sie kleiner als
  ein Pixel wird. Web: 700 Büschel.
- **Ambient-Leben** (`scripts/ambient_life.gd`): 53 Schnitte aus 38 echten CC0-Aufnahmen von
  freesound.org (`tools/prepare-after-play-ambient-life-v527.py`, Herkunft in
  `assets/ambient-v527/provenance.json`).
  - Raumtöne an ihrer echten Quelle: Neon am Empfang, Röhrenbrummen in Halle,
    Flur und Küche, die Empfangsuhr tickt, Wind pfeift durch den alten
    Haupteingang, Regen am Fenster, der Heizkessel im Wartungsraum, der
    Snackautomat im Party Raum, tropfende Spülen in Küche und WC, Rauschen
    aus dem toten Kinolautsprecher. Alles am Stromnetz verstummt beim
    Stromausfall.
  - Alle 2,5 bis 6,5 Sekunden ein Geräusch in Hörweite: Knarzen in Decken
    und Böden, Heizungsrohre, das Plastik des Klettergerüsts, Ratten und
    Mäuse in den Wänden, eine Taube unterm Dach, quietschendes Spielzeug,
    Aufziehautos, ein Xylophon, springende Bälle, Bälle im Bällebad,
    Ballons, ein Münzschacht am Automaten, die Spieluhr, ein sprechendes
    Spielzeug, Spülkasten und Händetrockner im WC, draußen Autos im Regen,
    Hunde, eine Eule, eine ferne Sirene, die klappernde Tür. Jede Datei hat
    eine Abklingzeit (seltene Sachen bis 4 Minuten); Wände dämpfen über die
    bestehende Raumakustik.
  - Eigener Zufallsgenerator, gleiches Verhalten in normalen und
    Anomalie-Runden: Kein Geräusch verrät eine Runde.
  - Test: `-- --self-test --ambient-only` (auch Teil von
    `--shift-release-only`).

## Partynacht: Absturz beim Wechsel auf Runde 10 behoben (5.2.6)

- **Ursache:** Runde 10 ist die erste Boss-Runde und ruft immer das Krokodil.
  Dessen Modell `assets/creatures/night-crocodile-v4.glb` stand in allen drei
  Export-Presets im `exclude_filter`, fehlte also im gebauten Spiel; das Laden
  lieferte `null` und das Spiel stürzte ab. Im Editor war die Datei da, und der
  Test spawnte nur den ersten Boss, deshalb fiel es nicht auf.
- Der Krokodil-Boss nutzt jetzt `assets/croc-v385/crocodile.glb` (wird überall
  mitgeliefert, Skalierung 1,17 für dieselbe Größe). Für die Web-Fassung, die
  `assets/hero/*` und `clown-desktop.glb` auslässt, haben Plüsch-Koloss und
  Marell ein `web_model` (Feier-Hase bzw. `clown-web.glb`).
- Fehlt ein Gegnermodell trotzdem, lädt der Gegner das Partykind-Modell und
  meldet einen Fehler, statt das Spiel abzustürzen.
- Der Partynacht-Test prüft jetzt jedes Gegner- und Boss-Modell gegen die
  Ausschlussfilter jedes Export-Presets.

## Partynacht: Ruckler beim Schießen behoben (5.2.5)

- **Ursache 1, Effekt-Materialien:** Mündungsfeuer, Leuchtspuren, Blitze,
  Explosionsringe, Konfetti, Fleischbrocken und andere Kurzeffekte bauten bei
  jedem Auftreten ein eigenes Material. Ein frisches Material an den Renderer
  zu geben wartet auf den Render-Thread, im Gefecht ein ganzes Frame: rund
  25 ms pro Schuss. Effekte teilen sich jetzt ein Material pro Aussehen und
  Farbe (`ZombiesFx.cached`) und blenden pro Instanz über `transparency` aus.
  Ihre Shader werden beim Laden einmal vorgewärmt; die zwei Effekt-Shader
  (Alien-Haut, Achter Sinn) werden nicht mehr bei jedem Aufruf neu angelegt.
- **Ursache 2, Schatten:** 40 Lampen warfen Schatten und mussten mit der
  Horde darin immer wieder neu gerendert werden. In der Partynacht werfen nur
  noch die 4 Lampen nächst dem Spieler Schatten (alle 0,3 s neu gewählt); beim
  Verlassen bekommen alle Lampen ihre Schatten zurück.
- Messung mit 22 Gegnern (Windows, ohne VSync): SMG-Dauerfeuer 21–35 → 68–75
  FPS, Schrotflinte 36–48 → 76 FPS, Leerlauf 35–58 → 98 FPS; Draw Calls im
  Gefecht von 13 000–21 000 auf 3 700–5 000. Die Wegfindung war mit 0,04 ms
  pro Pfad nie das Problem.

## Partynacht: Jingles für alle Perks, Nightwatch in Arbeit (5.2.4)

- **Nightwatch Protocol** ist unter „Weitere Spielmodi“ vorerst ausgegraut
  und nicht startbar; beim Drüberfahren steht dort „In Development“.

- Jeder der zwölf Perks spielt beim Kauf sein eigenes Jingle (3 bis 4 s)
  statt des synthetischen Brummens. Die sieben ausgesuchten Pixabay-Jingles
  aus „Zombie Sounds“ liefern je eine oder zwei verschiedene Phrasen, auf den
  Takt geschnitten, mit Ausblendung und angeglichener Lautstärke; Plüschsegen
  und Grabesschritt behalten das echte Ende ihres Stücks.
- `tools/prepare-after-play-perk-jingles-v524.py` erzeugt die Schnitte nach
  `assets/zombies-v524/jingles/`; der Partynacht-Test prüft, dass jeder Perk
  ein passend langes Jingle hat und es beim Kauf erklingt.

## Partynacht: alle Bonis eingesprochen (5.2.3)

- Die elf restlichen Bonis haben jetzt eigene Ansagen statt des synthetischen
  Brummens: Maximalmunition, Kriechzeit, Plüschschild, Vergessen, Kritische
  Nacht, Feuerkinder, Kettenblitz, Schwerelos, Alien-Segen, Zeitlupe und
  Blutrausch. Damit sind alle 17 Bonis vertont.
- `tools/prepare-after-play-zombies-audio.py` liest dafür zusätzlich den
  Desktop-Ordner „Zombie Sounds“; der Partynacht-Test prüft jetzt, dass jeder
  Bonus eine Aufnahme hat.

## Partynacht: keine Blendflecken mehr bei Bossen (5.2.2)

- Bugfix: Das Leuchtlicht von Bossen und Elite-Gästen wurde bei jedem
  Treffer heller und klang nie ab. In langen Bosskämpfen mit schnellen
  Waffen wurde es unendlich hell und legte riesige weiße und schwarze
  Flecken über das Bild. Jetzt blitzt es kurz auf und beruhigt sich wieder.
- Explosionen direkt vor dem Gesicht blenden nicht mehr: Feuerball, Kugel
  und Rauch werden in der Nähe kleiner und durchsichtiger.
- Etwas kleineres Mündungsfeuer; Effekt-Lichter leuchten nicht mehr in den
  Nebel.
- Neuer Trailer (Autoren-Werkzeug `scripts/trailer_director.gd`,
  `tools/make-after-play-trailer-v521.py`).

## Partynacht: durch die Netze schießen (5.2.1)

- Schüsse, Tesla-Blitze, Flammenwerfer, Riss-Kanone und Tortenwerfer
  fliegen durch die Sicherheitsnetze des Klettergerüsts. Vom Gerüst aus
  lassen sich Gäste unten abschießen; Wände und Böden halten weiter auf.

## Partynacht: Effekt-Gewitter, Partywaffen, Neon und Musik (5.2.0)

- **Effekte**: Mündungsfeuer mit Sternblitz, Seitenflamme, Rauch und
  Funken, ausgeworfene Hülsen, leuchtende Leuchtspuren in Elementfarbe,
  Einschläge mit Funken, Staub und Einschusslöchern.
- **Blut und Party**: Blutfontänen und Blutnebel bei jedem Treffer,
  Blutflecken auf Boden und Wänden, Fleischbrocken bei Kopfschüssen und
  Explosionen, Konfetti bei jedem Kill.
- **Explosionen**: Feuerball, Druckwelle, Rauchsäule, Brandfleck und
  Kamerawackeln. Außerdem zuckende, verzweigte Kettenblitze, brennende
  Gäste mit Flammen und Licht, Leere-Implosionen und schwebende
  Schadenszahlen (Kopfschuss gold).
- **Neue Partywaffen**:
  - Kuchenbrenner F-9 (Flammenwerfer, an der Wand im Boss-Bereich, 3000),
  - Gewitterkind Tesla-Spule (Blitz mit Zielhilfe, springt auf bis zu
    fünf Gäste),
  - Tortenwerfer TW-3 (Torte im Bogen, explodiert in Feuer und Konfetti).
- **Waffen-Design**: je nach Seltenheit leuchtende Spulen, Energiezellen,
  Holo-Visiere und Finnen.
- **Waffen-Upgrades**: aufgewertete Waffen bekommen eine animierte
  Leuchttarnung und Funken. Die Upgrades stapeln sich jetzt: Stufe 1
  brennt, Stufe 2 brennt und kettet Blitze, Stufe 3 zerreißt zusätzlich
  mit Leere-Implosionen. Die Sterne der Stufe stehen im HUD. Die
  Fleischmaschine blitzt und explodiert beim Veredeln.
- **Lebensbalken über den Köpfen** der Gäste (nach Treffern; Elite-Gäste
  immer, mit Namen), Farbe von Grün über Gelb zu Rot.
- **Neue Runden groß**: riesige Rundenzahl knallt ins Bild, wackelt, Blut
  läuft vom Bildschirmrand, dazu ein Gong und bunte Blitze um den Spieler.
- **Absperrungen und Schriften**: Absperrband, Pfosten mit Warnleuchten,
  Neonschilder mit flackerndem Rahmen und Preis an allen Absperrungen,
  Wandwaffen, Perks, Munition, Fleischmaschine und Chaos-Geschenk.
  Absperrungen fliegen beim Öffnen mit Explosion und Konfetti auseinander.
- **Musik**: eigene gruselige Spieluhr-Melodie; eine Bedrohungsspur mit
  Herzschlag wird mit Runden, Horde und Bossen lauter.
- **Zombie-Stimmen**: Stöhnen, Knurren beim Zuschlagen und Röcheln beim
  Sterben (Pixabay-Sounds des Besitzers), räumlich und mit
  Tonhöhen-Varianten.
- **Erzeugt per Code**: Effekttexturen, Sounds und Musik entstehen mit
  `tools/make-after-play-zombies-fx-v520.py`, die Stimmen mit
  `tools/prepare-after-play-zombie-voices.py`.

## Hellere Nightwatch-Kameras mit Vollbild, Partynacht mit Schlägen und Lebensbalken (5.1.2)

- **Nightwatch Protocol**: jede Kamera sieht mit eigener Nachtsicht
  (höhere Belichtung, Umgebungslicht, weniger Nebel), stärkere
  Infrarotlampen; die Anomalien sind klar zu erkennen, auch im Kino.
  Linksklick auf einen Monitor zeigt die Kamera im Vollbild (Kameraname,
  Strom, Uhrzeit), Rechtsklick oder ESC führt zurück; 1–0 und Mausrad
  wechseln dort die Kamera, B öffnet das Meldebuch.
- **Partynacht**: zwei kräftige Schlag-Animationen (Krallenhieb von oben,
  doppelter Wischer, jeweils mit Ausfallschritt), rote Kratzspuren auf dem
  Bildschirm bei Treffern, ein Lebensbalken mit Zahlen (blinkt unter 35 %),
  das große schwarze Kreuz der Treffermarke ist weg.

## Aufgeräumtes Hauptmenü mit „Weitere Spielmodi“ (5.1.1)

- Im Hauptmenü stehen nur noch Neue Nachtschicht, Schicht fortsetzen und
  **Weitere Spielmodi**; dahinter liegen Endlosmodus, Nightwatch Protocol,
  Partynacht und Multiplayer mit je einer kurzen Beschreibung. ESC führt aus
  den Modus-Menüs zurück zu dieser Übersicht.

## Partynacht: geriggte Partykinder, Waffensounds, leichterer Einstieg (5.1.0)

- **Eigener Avatar als Hauptgegner**: das selbst erstellte 3D-Modell des
  Partykinds (Bild-zu-3D, 19.400 Flächen, 2K-Texturen) ist ausgerichtet, auf
  1,45 m Kindergröße gebracht, mit 20 Knochen geriggt und animiert
  (`tools/rig-after-play-party-avatar-v510.py`, Ausgabe
  `assets/zombies-v510/party-avatar.glb`). Es ist das normale Partykind, der
  Krabbler, der Springer und der Riss-Mutant.
- Die selbst modellierten Partykinder sind jetzt echte Skelett-Modelle
  (`tools/model-after-play-party-zombie-v510.py`): ein Körper auf 20 Knochen
  mit weicher Haut-Verformung und eigenen Animationen für Leerlauf, Gehen,
  Rennen, Angriff, Treffer, Tod und Krabbeln. Gesicht neu bemalt nach der
  Vorlage (kalkweiß, schwarze Augenhöhlen mit laufender Schminke, rot
  verschmiertes Grinsen), Kleider mit Stoffmuster, Schmutz und Blut, eine
  zweite Rüschenlage (`tools/paint-after-play-party-zombie-v510.py`). Die
  Kopftreffer-Zone hängt am Kopfknochen.
- Schuss-, Treffer- und Kill-Sounds (`tools/make-after-play-zombies-sfx-v502.py`):
  geschichtete Schüsse pro Waffentyp (Knall, Explosion, Bass, Mechanik,
  Raumhall), Körper- und Kopftreffer, Splat beim Kill, Bestätigungs-„Ding“ beim
  Kopfschuss-Kill, Hitmarker, Magazin raus/rein, Durchladen, Leerklick,
  Waffenwechsel und Nahkampf; jeweils mehrere Varianten.
- Leichter: weniger und langsamere Gegner am Anfang, weniger Leben und
  Schaden, seltenere Schläge und Eliten, schwächere Bosse, stärkere
  Startpistole (55 Schaden, 10 Schuss), 750 Startpunkte, schnellere Erholung.

## Partynacht: eigene Ansagen (5.0.1)

- Die ersten eingesprochenen Ansagen sind drin: Start der Partynacht, Doppelte
  Punkte, Sofortkill, Geburtstagsbombe, Endlose Munition, Doppelter Schaden
  (vorher „Blutkraft“) und das neue Pickup **Doppeltes Tempo** (20 s doppelte
  Laufgeschwindigkeit). Eine neue Ansage unterbricht die vorige.
- `tools/prepare-after-play-zombies-audio.py` übernimmt die Aufnahmen aus dem
  Desktop-Ordner „Ansagen Bonus“, schneidet die Stille am Ende ab, gleicht
  die Lautstärke an und legt sie als OGG unter dem passenden Namen ab.

## Partynacht: Wellen-Überlebensmodus (5.0.0, Grundprojekt)

- Neuer Menüpunkt **Partynacht** (`scripts/zombies_*.gd`): rundenbasiertes
  Überleben im Spieleparadies. Start im Empfang mit der P-9 Knochenbeißer und
  500 Punkten; Gegnerzahl, Leben, Tempo, Spawnrate und Elite-Chance steigen
  jede Runde. Ab Runde 5 Elitegäste, ab 10 Bosse (alle 5 Runden), ab 15
  Realitätsrisse, schwebende Trümmer und Glitches, ab 20 mehr Eliten, ab 25
  Albtraumphasen mit Dauer-Alarmlicht, ab 30 doppelte Bosse. Alle Werte in
  `scripts/zombies_config.gd`.
- **Gegner**: das Partykind nach der Vorlage (Blender,
  `tools/model-after-play-party-zombie-v500.py`: Partyhut, wirres Haar,
  Grinsen, Rüschenkragen, zerrissenes Kleid mit Luftschlangen, Ringelstrümpfe,
  Stiefel) in zwei Varianten, dazu Sprinter, Krabbler, Springer, Spucker,
  Kreischerin, Flackerkind (teleportiert), Plüsch-Koloss und Riss-Mutant.
  Bosse: Marell, der Plüsch-Titan, das mutierte Krokodil und der
  Geburtstagsjäger, mit drei Phasen, Sturmangriff, Schockwelle, Beschwörung.
- **Zonen**: Empfang, Halle, Bällebad, Party Raum mit Kostümfundus, Wartung,
  Küche & Kino, Kinder-WC, getrennt durch kaufbare Bauzäune (750–1500).
- **30 Waffen** auf acht modellierten Grundformen
  (`tools/model-after-play-zombies-gear-v500.py`): Wandkäufe, Chaos-Geschenk
  (zieht nach einigen Öffnungen weiter), Fleischmaschine mit drei Stufen
  (Feuer, Blitz, Leere). Zwei Waffen gleichzeitig, Zielen, Nachladen,
  Nahkampf, Durchschuss bei Scharfschützengewehren, Rift Cannon mit
  Explosion und Kettenblitzen (begrenzt nachfüllbar).
- **12 Perks** an verdorbenen Automaten (Limit 4, jeder Boss +1),
  **Munitionskisten** in jeder Zone, **16 Bonus-Pickups** (Doppelte Punkte,
  Maximalmunition, Sofortkill, Geburtstagsbombe, Schild, Endlose Munition,
  Kettenblitz, Schwerelos, Zeitlupe, Blutrausch …), **12 Spezialereignisse**
  (Blutmond, Alien-Invasion, Schwerkraftausfall, Dunkelheit, Flackerphase,
  Giftnebel, Zeitstillstand, Klonwelle, Doppelter Geburtstag …).
- Rekorde: höchste Runde, bester Punktestand, Kills, Kopftreffer, Bosse,
  längste Zeit, Pickups, Perks, verwendete Waffen; vier neue Erfolge.
- **Sounds**: Eigene Aufnahmen kommen nach
  `assets/zombies-v500/audio/` und heißen wie ihr Anlass (ogg, wav oder mp3):
  `start`, `round`, `round_end`, `boss`, `boss_phase`, `boss_down`, `perk`,
  `door`, `box`, `box_result`, `box_troll`, `upgrade`, `upgrade_start`,
  `reality`, `game_over`, `ammo_empty`, `pickup` (oder `pickup_<id>`),
  `event_<id>`. Bis dahin spielen synthetische Platzhalter; Schüsse sind
  ebenfalls synthetisch.
- Neue Testsuite `--zombies-only`.

## Nightwatch: echter Kontrollraum und flüssige Blicksteuerung (4.16.0)

- Der Kontrollraum besteht jetzt aus echten Modellen statt Platzhalter-Kisten:
  Poly-Haven-Modelle (CC0, `tools/fetch-after-play-nightwatch-v4160.py`) für
  Metallschreibtisch, Gelenklampe, drei verwitterte Metallregale, den
  tragbaren Generator EN2500, die Leder-Ringmappe als Meldebuch, Klemmbrett,
  Notizblöcke, Funkgerät, Neonröhren, Stromkästen, Arbeitslampe, Mülleimer und
  Multimeter; Wände, Boden und Decke mit PBR-Putz und Beton.
- Selbst modelliert (`tools/model-after-play-nightwatch-v4160.py`, Blender):
  4:3-CCTV-Röhrenmonitore mit Stahlgehäuse, Bildröhrenhaube, Lüftungsschlitzen,
  Drehknöpfen, Betriebs-LED und gewölbtem Glas, auf dem das Kamerabild läuft,
  und ein Kamera-Umschaltpult mit zehn Tasten, Joystick und Anzeige. Die Taste
  der gewählten Kamera leuchtet; ein Klick auf eine Taste schaltet um.
- Stromanzeige mit LED-Ziffern an der Wand über dem Generator.
- Blicksteuerung neu: Maus an den rechten oder linken Bildrand schwenkt den
  Kopf weich, A/D und Klicks gleiten zu Monitorwand oder Generator, die Kamera
  folgt gedämpft und bildratenunabhängig, mit leichtem Mitgehen der Maus.

## Nightwatch Protocol, aufgeräumtes Hauptmenü, Toiletten-Graffiti (4.15.0)

- Neuer Spielmodus **Nightwatch Protocol** (`scripts/nightwatch*.gd`): Du sitzt
  im Kontrollraum unter Happyland und überwachst das Spieleparadies über zehn
  Kameras (Empfang, Halle, Bällebad, Spielhalle, Party Raum Tisch und
  Snackbar, Kostümfundus, Wartung, Küche, Kino). Die Bilder zeigen die echte,
  laufende Welt mit CCTV-Optik (Rauschen, Zeitstempel, Kameranummer, Störungen);
  jede Kamera hat eine Infrarotlampe, damit dunkle Räume lesbar bleiben.
  Monitor anklicken, 1–0, Q/E oder Mausrad wechseln die Kamera.
- Anomalien erscheinen während des Zuschauens und werden genau zurückgesetzt,
  sobald sie gemeldet sind: Gegenstand fehlt, schwebt, ist verschoben,
  zusätzlicher Gegenstand, Besucher im Raum, ungewöhnliche Bewegung,
  Erscheinung, rotes Licht. Jede hat ihren eigenen Countdown.
- **Meldebuch** auf dem Schreibtisch: Raum, Bereich und Art wählen, Meldung
  abgeben. Nur wenn alles stimmt, verschwindet die Anomalie.
- **Strom** sinkt ständig. Unter 50 % flackern die Bildschirme leicht, ab 20 %
  piept eine Warnung, die immer schneller wird, unter 10 % wird es hektisch.
- **Generator** rechts (D/→ oder rechter Bildrand): anklicken und die Wörter
  tippen. Stufe 1: ein Wort in 20 s, Stufe 6: fünf Wörter in 10 s. Klappt es,
  ist der Strom wieder bei 100 %; misslingt es, bleibt der Strom, wie er ist,
  und man darf es noch einmal versuchen. Während des Tippens warten die
  Anomalie-Timer und es erscheinen keine neuen, der Strom sinkt aber weiter.
- Die Schicht endet sofort bei einer übersehenen Anomalie, der dritten
  Fehlmeldung oder 0 % Strom. Danach: Punkte, Zeit, Meldungen, Fehlmeldungen,
  Generator-Neustarts, Stufe, Serie und eigener Highscore (getrennt vom
  Endlosmodus). Sechs neue Erfolge.
- Alle Zahlen stehen zentral in `scripts/nightwatch_config.gd`: Stufen alle
  75 s, Abstand der Anomalien 34 → 13 s, gleichzeitig 1 → 5, Meldezeit
  110 → 55 s, Stromverbrauch 0,40 → 0,84 %/s.
- **Hauptmenü** aufgeräumt: die Spielmodi groß oben, Einstellungen, Album,
  Erfolge, Mitwirkende und Beenden kleiner darunter. „Schicht fortsetzen“
  erscheint nur noch mit Spielstand; der Hintergrund ist etwas heller.
- **Toiletten**: jede Kabinenwand und Tür hat eigene Kritzeleien
  (`tools/make-after-play-cubicle-graffiti-v4140.py`, fünf Varianten).
- Neue Testsuite `--nightwatch-only`.

## Endlosmodus und Erfolge (4.14.0)

- Neuer Menüpunkt **Endlosmodus**: bis zu 500 Rundgänge mit drei Leben. Eine
  falsche Tür, das Pferd oder die abgelaufene Zeit kosten ein Leben; die Runde
  wird danach neu ausgelost. Beim dritten Fehler endet der Lauf mit einer
  Übersicht (erreichte Runde, Fehler, bester Lauf).
- Schwierigkeit steigt stufenweise: Runde 1–5 nur laute, große Anomalien
  (Stufe 1), danach mittlere (Stufe 2), ab Runde 16 leise (Stufe 3). Ab Runde 31
  kommen **Detail-Anomalien** dazu: ein Stuhl ist verdreht, ein Stern hängt
  tiefer, der Mülleimer ist etwas größer, die Pinnwand hängt schief, ein Ballon
  hat eine andere Farbe. Ihre Stärke sinkt von Runde 31 bis 500 auf etwa ein
  Zehntel; ab Runde 150 sind drei Viertel aller Anomalien solche Details
  (`scripts/endless_details.gd`).
- Ab Runde 15 läuft pro Runde ein Timer von fünf Minuten (Hinweis bei einer
  Minute und bei zehn Sekunden). Läuft er ab, packt dich ein Besucher.
- Anzeige oben rechts: `ENDLOS · RUNDE 017 / 500 · LEBEN 3/3 · 04:32`. Nach
  einem Fehler wird angezeigt, was die Anomalie war.
- Eigener Spielstand: Der Endloslauf überschreibt nie die normale Nachtschicht,
  beide lassen sich getrennt fortsetzen. Im Endlosmodus gibt es keinen
  Multiplayer; ein erreichtes Ende beendet den Lauf.
- **Erfolge** (Hauptmenü und Endlosmenü): 19 Erfolge, lokal gespeichert, mit
  Einblendung beim Freischalten. Runde 10/15/25/50/100/200/250/350/500, Makellos
  (50 Runden ohne Lebensverlust), Adlerauge (25 Detail-Anomalien in Folge),
  Gegen die Uhr (unter 10 s Rest), Blitzrunde (unter 60 s), dazu die vier Enden,
  alle Puppen und ein paar geheime (`???`).
- Neue Testsuite `--endless-only`.

## Fotobox, Kino und Waschraum aufgewertet (4.13.0)

- Fotobox: zweifarbige 70er-Kabine mit Chromleiste und Dachkappe, rundem
  Kamerafenster, Blitzfeld, Münzprüfer, Fotoausgabe, Faltenvorhang-Hintergrund,
  Drehhocker und Musterfotos an der Seite; der vergessene Fotostreifen liegt auf
  dem Hocker (`tools/model-after-play-photobooth-v4130.py`).
- Jetonautomat: roter Wechsler mit leuchtendem Schild, grün beleuchtetem
  Scheinschlitz, Münzschlitz, Schloss und Münzschale mit ein paar Jetons.
- Kino: alle 24 Sitze als Klappsitze mit Gusseisen-Seitenteilen, Holz-Armlehnen,
  gerolltem Polster und abgestepptem Rücken; jeder fünfte ist aufgerissen und
  zeigt Schaumstoff. Nummern, Becherhalter und Kollisionen bleiben.
- Popcornwagen: Speichenräder, Schiebegriff, Schublade mit Goldlinie,
  Glaskasten, Kupferkessel und Kuppeldach.
- Waschraum: Kindertoiletten aus Porzellan mit Kalkrand, Sitz, Deckel und
  Spülkasten; Waschbecken mit Säulenhahn, Kreuzgriffen und Siphon, Rost am
  Abfluss, eines gesprungen, an einem tropft der Hahn; Seifenspender mit
  Sichtfenster; Kinderkritzeleien auf den Kabinenwänden
  (`tools/model-after-play-annex-v4130.py`,
  `tools/make-after-play-cubicle-graffiti-v4130.py`).

## Arcade-Ecke und Snackbar aufgewertet (4.12.1)

- Die zwei Arcade-Automaten „Lunar Orbit“ und „Star Hopper“ sind modelliert:
  bedruckte, ausgeblichene Seitenkunst (Ringplanet, Komet), Kantenschutz,
  Bildschirmrahmen, bedrucktes Bedienfeld mit Kugel-Joystick und drei Knöpfen,
  Chrom-Münztür mit leuchtenden Münzschlitzen, Lüftungsblech und
  Lautsprechergitter. Das animierte Bild bleibt
  (`tools/model-after-play-arcade-v4120.py`).
- Preisautomat: acht Plüschhasen mit Schlappohr, Knopfaugen, gesticktem
  Lächeln und Puschelschwanz statt Kugelfiguren
  (`tools/model-after-play-prize-bunny-v4120.py`).
- Snackbar: Slush-Maschinen mit Edelstahlsockel, klarem Behälter, Kühlwalze,
  Förderspirale, eingetrockneter Sirupkruste (Kirsche, Waldmeister), Zapfhahn
  und Tropfgitter; Chrom-Serviettenspender (`tools/model-after-play-slush-v4120.py`).
- Test: Die Gestalt vor der Snackbar wird jetzt bis zu vier Sekunden
  beobachtet (zufälliger Angriffszeitpunkt seit 4.9.2).

## Details der Nacht und aufgewertete Räume (4.12.0)

Böden und Licht:
- Spielhallenboden aus EVA-Puzzlematten (60 cm) in verblassten Farben mit
  durchgehenden Puzzle-Nasen, Schmutz in den Fugen, glänzend abgelaufenem Weg,
  alten Kaugummis und Schuhstreifen (`assets/look-v4120/playmat.gdshader`).
- Zwei defekte Leuchtstoffröhren (Serverraum, Flur) flackern in Schüben, der
  Starter klickt hörbar (`scripts/night_details.gd`).
- Regen auf den Scheiben: Tropfen und Rinnsale, die bei Blitzen aufleuchten.
- Kein Funkeln mehr zwischen Clown und Abzugshaube: kleine Lampen werfen keine
  Lichtkegel mehr in den Nebel, das Nebelraster ist auf „Hoch“ feiner.

Details der Nacht:
- Der Wachmann hinterlässt Schuhabdrücke im Staub, abwechselnd links und rechts.
- Flüstern: Wer länger als sieben Sekunden still steht, hört manchmal leises
  Flüstern aus einer anderen Ecke.
- Neue Anomalie „Kinderspuren“ im Bällebad: eine Spur kleiner nackter Füße.
- Neue Anomalie „Kalter Atem“ in der Küche: Raureif, kaltes Licht und sichtbarer
  Atem des Wachmanns nur in der Küche.

Aufgewertete Gegenstände:
- Bastelecke im Feierraum: runder Basteltisch mit Kreidekritzeleien, Kleberingen
  und Gummikante, Kinderhocker mit Sitzschale, Kinderzeichnungen auf vergilbtem
  Papier (`tools/model-after-play-craft-corner-v4120.py`).
- Kostümraum: die sieben leeren Maskottchen-Anzüge per Stoffsimulation entleert,
  schlaff an Holzbügeln, die Füße sacken auf dem Boden zusammen
  (`tools/model-after-play-costume-room-v4120.py`).
- Schminktisch mit Schminkpalette, offener Puderdose, Pinselbecher, Haarspray,
  Lippenstift und Styroporkopf mit Clownsperücke; vier leuchtende Glühbirnen,
  eine durchgebrannt. Die Kreidetafel zeigt verwischte alte Kreidereste.
- Alte schwarze Nähmaschine mit Goldlinien statt Klotz
  (`tools/model-after-play-dressing-v4120.py`).

Bildkontrolle: `--render-qa --heroprops-qa [--only=costume]`, `--details-qa`.
Test: `--self-test --night-details-only`.

## Großes Grafik-Update (4.11.0)

Licht und Kamera:
- Kamera-Look über das ganze Bild (`scripts/cinematic_look.gd`): kühle Schatten,
  warme Lichter, weiche Kontrastkurve, Vignette, Filmkorn in den Schatten,
  leichte Farbsäume am Bildrand, Nachschärfen. Der Schalter „Filmkorn“ bleibt.
- Licht-Pass (`scripts/look_pass.gd`): weniger grauer Dunst, tiefere Schatten
  und Kontaktschatten, sichtbare Lichtkegel im Nebel, Bloom, weichere
  Schattenkanten auf „Hoch“, nassere spiegelnde Böden.
- Sechs Industrie-Hängelampen über der dunklen Hälfte der Halle; sie werden bei
  „Lampen rot“ rot und gehen beim Stromausfall aus.
- Rund 120 im Code erzeugte Decals: Schmutzränder am Wandsockel, Wasserflecken,
  Schimmel, Bodenflecken.
- Taschenlampe mit Reflektor-Muster (heller Kern, Ring, Streulicht) und Strahl.

Modelle und Materialien:
- Sicherheitsnetze am Klettergerüst als geknotete Rautennetze aus Seil mit
  leichtem Durchhang und Schattenwurf (`PlayGeometry.knotted_net`).
- Polster aus glattem PVC-Kunstleder mit Narbung, Glanzschicht und ungleich
  abgegriffenem Glanz; gewölbte Polsterkappen auf allen Pfosten
  (`scripts/soft_play_finish.gd`).
- Geburtstagstisch: Klapptisch mit per Stoffsimulation drapierter, vergilbter
  Papiertischdecke (`tools/model-after-play-party-table-v4110.py`).
- 70er-Jahre-Stereoanlage mit Nussbaumboxen, offener Box, Aluminiumfront und
  Plattenspieler (`tools/model-after-play-stereo-v4110.py`); VU-Lampen des
  Partymodus bleiben.
- Dreieckige Stoffwimpel statt flacher Quadrate (`scripts/pennant.gd`).

Gewitter: Blitze flackern durch das Parkplatzfenster und die Glastür am
Eingang, werfen die Schatten der Rahmen in den Raum und zeichnen Lichtstrahlen
in den Dunst, auch während eines Stromausfalls (`scripts/thunderstorm.gd`).
Der Donner folgt je nach Entfernung 0,2 bis 3,8 Sekunden später; nahe
Einschläge krachen laut (synthetisch erzeugt:
`tools/make-after-play-thunder-v4110.py`), ferne grollen dumpf.

Geheimes Ende: Die Kinderstimme am Telefon ist jetzt eine echte Aufnahme
(`assets/secret-v4100/girl-call.ogg`).

Bildkontrolle: `--render-qa --perf-qa --perf-capture`, `--closeup-qa`,
`--heroprops-qa`, `--history-qa`, `--storm-qa` (gleiche Kamerapunkte wie die erste Version).

## Geheimes Ende: Alle wieder da (4.10.0)

- Hält man eine der fünf Creator-Puppen hoch, legt E sie ins Inventar
  (TAB zeigt „Puppen x / 5“). Aufheben und Drehen bleiben wie bisher.
  Gesammelte Puppen bleiben über Rundenwechsel im Inventar, ein Tod oder eine
  neue Schicht nimmt sie wieder weg.
- Mit allen fünf klingelt das Telefon am Empfang. Abheben: „Du hast uns alle
  gefunden. Lass uns zum Abschluss einen Kuchen essen.“
- Die Puppen werden mit E auf die Stühle am Geburtstagstisch im Party Raum
  gesetzt. Sitzt die fünfte, hebt die Kamera ab, die Decken verschwinden und
  der Laden bekommt Raum für Raum seinen Glanz zurück (Licht, Funkeln, kein
  Nebel mehr), dazu „Happy Birthday“ als Spieluhr (gemeinfreie Melodie,
  synthetisch erzeugt: `tools/make-after-play-birthday-v4100.py`).
- Danach öffnet sich der alte Haupteingang und 30 Kinder laufen herein: ins
  Bällebad, auf beide Klettergerüste, durch die Krabbelröhre, an den
  Geburtstagstisch und durch die Halle. Abblende, Abspann „Geheimes Ende“.
- Das bisherige geheime Ende (Glastür, Heimfahrt) heißt jetzt ENDE 3/3. Das
  Erinnerungsalbum hat vier Plätze.
- Testcode am Archivschloss: `55555555` (alle Puppen gefunden, Telefon klingelt).

Prüfung: `--self-test --plush-ending-only`, Bildkontrolle
`--render-qa --plush-ending-qa` und `--topdown-qa`.

## Jumpscares neu, Hauptschalter umgesetzt (4.9.2)

Die Besucher-Anomalien sind nicht mehr vorherzusehen:

- Vorher steht keine Gestalt mehr im Raum, es gibt kein Vorwarn-Geräusch,
  keine Seile und keine wartenden Gruppen.
- Laufende Besucher (auch die Kriecher): Betritt man ihren Raum, schlagen sie
  nach zufälligen 0,6 bis 2,6 Sekunden zu. Rennende Schritte kommen von hinten
  oder von der Seite, die Taschenlampe setzt kurz aus, dann steht die Gestalt
  schreiend vor dem Gesicht, egal wohin man schaut.
- Hängende und fallende Besucher stürzen genau dort herab, wohin man gerade
  schaut, mit Seil von der echten Decke.
- Besucher an festen Gegenständen (Topf, Kuchen, Bällebad, Thron, Röhre,
  Schacht) sind bis zum Schreck unsichtbar und schlagen ohne Vorwarnung zu,
  wenn man direkt davorsteht.
- Danach verschwinden sie wie bisher; die Kratzspuren am ursprünglichen Platz
  bleiben der Hinweis für die rote Tür.

Der Hauptschalter des Stromausfalls sitzt jetzt rechts am Schaltschrank, frei
über der Werkbank; die Beschriftung steht auf dem gelben Warnstreifen.

Prüfung: `--self-test --scare-flow-only`, `--nightmare-only`, `--blackout-only`,
Bildkontrolle `--render-qa --breaker-qa`.

## theraidenlena-Puppe und Testspielerin (4.9.1)

- Neue Plüschpuppe von theraidenlena auf der Holzkiste im Wartungsraum, direkt
  neben dem Hauptschalter. Dunkle Haare mit roten Strähnen und Antenne, rote
  Blume, rote Augen mit kleinem Eckzahn, rot-schwarzes Kleid mit Goldborte,
  Korsett und Schleife, Stiefel mit roten Rüschen
  (`tools/model-after-play-theraidenlena-v490.py`, Blender 5.0).
- Beim Aufheben spielt eine kurze, fröhliche Spieluhr-Melodie, für das Spiel
  synthetisch erzeugt (`tools/make-after-play-theraidenlena-v490.py`), und der
  Wachmann sagt: „ahh theraidenlena, kein Horrorspiel kann ihr was anhaben“.
- theraidenlena steht im Abspann unter Testspieler und mit eigener
  Puppen-Nennung, im Hauptmenü unter Mitwirkende und in den Lizenzhinweisen.

Prüfung: `--self-test --rosenyan-only`, Bildkontrolle `--render-qa --rosenyan-qa`.

## Stromausfall als Event-Anomalie (4.9.0)

Neue Anomalie „Stromausfall“ (Wartungsgang). Etwa sechs Sekunden nach
Rundenbeginn flackert das Licht und fällt aus: alle Lampen, Grundlicht,
Nebelleuchten, leuchtende Schilder, Bildschirme, Displays, Partymodus,
Kinofilm und Maschinengeräusche. Nur die Taschenlampe bleibt.

- Die rote Tür bleibt zu („Ohne Strom bleibt die Tür zu“), bis der neue
  Hauptschalter am Schaltschrank im Wartungsraum wieder umgelegt ist. Eine rot
  blinkende Lampe und Knistern führen dorthin.
- Im Dunkeln steigt die Angst: lauteres, schnelleres Atmen, zitternde Kamera,
  häufiger flackernde Taschenlampe. Nach 40 Sekunden springt eine Gestalt
  schreiend ins Gesicht, danach beginnen die 40 Sekunden von vorn.
- Mit dem Strom kehren Licht, Maschinen und ein zuvor laufender Partymodus
  zurück. Speichern und Laden mitten im Ausfall setzen ihn fort.
- Testcode am Archivschloss: `40404040`.

Prüfung: `--self-test --blackout-only` (`scripts/power_blackout.gd`).

## Kürzere Ladezeiten beim Rundenwechsel (4.8.1)

Zwischen zwei Runden wird die Welt neu gebaut. Das Spiel stand dabei 3,6 bis
4,2 Sekunden still, jetzt rund 2 Sekunden. Optisch ändert sich nichts:

- Identische Shader-Codes teilen sich ein Shader-Objekt
  (`scripts/shared_shaders.gd`), statt jede Runde neu kompiliert zu werden.
- Die Polsterfarben luden je Runde fünfmal eine Leder-Textur, die sofort
  wieder ersetzt wurde (`native_art.gd`, `surface(..., albedo=false)`).
- Dreiecks-Kollisionen gleicher Geometrie (Kinosessel, Krokodil) werden
  wiederverwendet (`scripts/shape_cache.gd`).
- Die alte Welt wird einen Frame später gezielt freigegeben statt über die
  Lösch-Warteschlange (`game._retire_world`), die neue versteckt gebaut.
- Fehlerbehebung: Wurde eine Schicht über den Ladebildschirm gestartet, fehlten
  in der ersten Runde Wandschäden, Materialveredelung und die Sitzflächen im
  Kino, weil diese Schritte die Sichtbarkeit der noch versteckten Welt
  abfragten. Sie fragen jetzt `PlayWorld.shown()`.

Messen: `--render-qa --load-qa`.

## Knochenarme im Bällebad, flüssigeres Spiel, Systemanforderungen (4.8.0)

Die Anomalie „Knöcherne Arme schnellen aus dem Bällebad“ ist neu gebaut. Statt
der Ärmel eines kopfüber gestellten Besuchers brechen jetzt fünf echte
Skelettarme (Oberarm, Elle und Speiche, Handwurzel, Fingerglieder mit
Krallen) aus den Bällen und schleudern die Kugeln hoch. Der lange Arm bricht am
Rand direkt vor dem Wächter hervor und greift mit gespreizten Fingern nach
seinem Gesicht, die übrigen krallen in die Luft. Nach gut einer Sekunde reißt
es alle zurück unter die Bälle. Als Hinweis stehen schon vorher und danach zwei
knöcherne Hände zwischen den Bällen. Der Ton ist kein Flüstern mehr, sondern
Knochenknacken mit einem Schrei direkt ins Ohr (`scripts/pit_bones.gd`,
`scripts/night_terrors.gd`).

Flüssiger, ohne die Grafik anzufassen: Wände und große undurchsichtige Körper
sind jetzt Occluder (`scripts/play_occluders.gd`). Der Renderer zeichnet
Räume hinter Wänden nicht mehr, im Kostümraum sinkt die Frame-Zeit um rund
40 %, im Kino um 30 %, über alle Messpunkte um rund 20 %. Ein Pixelvergleich
mit und ohne Culling (`--render-qa --occlusion-qa`) zeigt, dass nichts
Sichtbares wegfällt. Das Bällebad schreibt nur noch Bälle neu, die sich bewegt
haben. Messen: `--render-qa --perf-qa` (Optionen `--perf-quality=0..2`,
`--perf-size=BxH`).

Systemanforderungen stehen in `distribution/STARTEN.txt` und auf der
Webseite. Liegt ein PC darunter (kein Vulkan/Direct3D 12, nur integrierte
Grafik, unter 8 GB RAM, unter 4 Threads), nennt das Hauptmenü das unten rechts,
ohne Einstellungen zu ändern (`scripts/system_check.gd`).

## Untertitel ohne Warteschlange (4.7.0)

Wird ein neuer Wächter-Kommentar ausgelöst, während noch einer läuft, bricht der
alte sofort ab und der neue startet im nächsten Bild. Bisher stellte sich der neue
hinten an und kam erst, wenn der alte komplett getippt, gehalten und herabgefallen
war, plus 1,2 s Pause. Es gibt keinen Rückstau mehr: Nur der neueste Kommentar zählt.
Buchstaben, die schon fallen, fallen weiter. Prüfung: `--self-test --dialogue-only`.

## Hissybusa- und Jule_heartbeat-Puppe, Puppen verteilt (4.7.0)

Neue Plüschpuppe von **Hissybusa**: schwarze Cap mit weißem Logo, braune Haare,
voller Vollbart, braune Herzaugen, lachender Mund, schwarze Kopfhörer mit
rot-blau leuchtendem Rand, schwarzer Hoodie mit lila Streifen und Kordeln,
lila Chat-Patch und Gamepad-Sohlen. Beim Aufheben ruft er „Simon, you jerk!
Move! Please move! Damn it!“. Der Nachtwächter kommentiert:
„Hissybusa. Brüllt einen Dino an und verliert trotzdem. Chaos auf zwei Plüschbeinen.“

Neue Plüschpuppe von **Jule_heartbeat**: lange, wellige rotbraune Haare, weiße
Kopfhörer mit grauen Polstern und lila Herz, große blaue Augen mit Herz-Glanzpunkten,
schwarzer Hoodie mit Herz-Stickerei, Jogginghose mit weißen Nähten, weiße Socken
und eine schlafende schwarz-weiße Katze im Arm. Beim Aufheben schnurrt die Katze.
Das Schnurren ist synthetisch erzeugt, es gibt also keine fremde Aufnahme (`tools/make-after-play-jule-v470.py`). Der Wächter
kommentiert: „Jule_heartbeat mit schlafender Katze. Pssst, die beiden haben schon Feierabend.“
Modell: `tools/model-after-play-jule-v470.py`.

Die vier Puppen sitzen nicht mehr zusammen in der Spielecke:

- **Hissybusa:** am Anfang auf der Bank neben dem großen Hasen
- **einsmarello:** oben im Klettergerüst auf der Aussichtsplattform
- **Rosenyan:** im Feierraum auf dem Partytisch neben der Torte
- **Jule_heartbeat:** im Kino auf dem Teppich vor der ersten Reihe (die Sessel haben
  massive Kollisionsblöcke, darauf würde sie beim Anfassen herausgedrückt)

Figur und Stimme gehören Hissybusa und werden im Menü „Mitwirkende“, im Abspann,
in `Lizenzhinweise.txt` und in `assets/hissybusa-v470/LICENSE.txt` genannt.
Quellen:
- `tools/model-after-play-hissybusa-v470.py` (Blender 5.0)
- `tools/make-after-play-hissybusa-v470.py` (10,45–15,95 s seines Clips „NEW DINOSAUR
  HORROR GAME!“; die Stelle wurde lokal per faster-whisper bestimmt)

Prüfung: `--self-test --rosenyan-only` prüft für alle vier Puppen:
- Platz
- Auflage (weder schwebend noch eingesunken)
- Aufheben
- Stimme
- Untertitel
- Credits

Bildkontrolle: `--render-qa --rosenyan-qa`.

## Neue Jumpscares der Nachtbesucher (4.7.0)

Die Besucher-Jumpscares sind neu getaktet. Bisher löste ein Besucher schon aus
5,4 m Entfernung aus, lief 1,3 s lang mit 1,9–4,5 m/s auf den Wächter zu, blieb
an Möbeln hängen und stand danach verdreht im Raum.

- **Timing:** Ein Besucher wartet, bis man wirklich nah ist (3,3–4,4 m, Renner
  5,6 m). Wer ihn aus der Ferne länger als rund 2 s anstarrt, wird trotzdem
  angegriffen.
- **Angriff:** Nach einem kurzen Erstarren mit zuckendem Kopf (0–0,3 s) sprintet
  der Besucher mit 6–9 m/s los und springt dem Wächter ins Gesicht (Schrei,
  flackerndes Licht). Versperren Tresen oder Sitzreihen den Weg, springt er
  darüber, solange er den Wächter sieht. Sonst verschwindet er. Hängenbleiben
  ist damit ausgeschlossen.
- **Danach unsichtbar:** Jeder Besucher (auch Hände, Mund, Thron, Deckengast,
  Fallgast, Röhrenkriecher) verschwindet nach seinem Schreck. Die Taschenlampe
  flackert dabei kurz, damit er nicht sichtbar wegploppt. Als Hinweis für die
  Türentscheidung bleiben nur die Kratzspuren.
- **Querläufer** (`corridor_crossing`) rennt quer durchs Blickfeld und ist weg.
- **Lautstärke:** Die Schrecktöne liefen bisher über den Ambience-Bus mit −5 dB.
  Jetzt haben sie einen eigenen Bus `AP.Scare` mit Limiter (+3 dB Vorverstärkung),
  sind 3D-seitig +3 dB lauter und tragen weiter. Das gilt auch für Hase, Krokodil
  und Küchenclown.
  Der Ambience-Regler dämpft sie nicht mehr.

Prüfung: `--self-test --scare-flow-only` spielt jeden laufenden Besucher Bild
für Bild aus echten Annäherungspositionen durch. Geprüft wird, ob er den
Wächter erreicht, wie schnell das geht und ob er danach verschwunden ist.
Außerdem `--nightmare-only`. Nicht angehört; vor Veröffentlichung im Spiel
gegenhören.

## Puppen drehen und leiser (4.6.1)

Getragene Spielsachen lassen sich drehen: Mausrad dreht um 15 Grad, R um 45 Grad,
Umschalt + Mausrad kippt nach vorn oder hinten. Die Haltung bleibt beim Tragen erhalten.
Die Stimmen der Rosenyan- und der einsmarello-Puppe sind rund 9 dB leiser und tragen
weniger weit. Steuerungshilfe und Hinweiszeile nennen die neue Taste.

Fehlerbehebung: Bei der Anomalie „Der Pferdeschädel stößt bei Annäherung aus dem
Schacht nach unten“ (`vent_strike`) wurde beim Auslösen fälschlich die versteckte
Platzhalter-Besucherin sichtbar und hing mitten im Kinoflur, genau dort, wo der
Schädel zustößt. Jetzt erscheint nur der Pferdeschädel. Prüfung: `--self-test --horse-only`.

## einsmarello-Puppe (4.6.0)

Neben der Rosenyan-Puppe sitzt jetzt eine Plüschpuppe von **einsmarello**:
langes blondes Haar, schwarzer Katzenohren-Kopfhörer mit leuchtend pinken
Ohren, pinke Herzaugen, „:3“-Mund, schwarzer Hoodie mit pinken Streifen und
Kronen-Patch, ein Glas Rotkohl im Arm (mit Aufschrift), Pfotenabdrücke unter
den Füßen und Katzenschwanz. Beim Aufheben singt sie „I'm a Barbie girl in a
Barbie world“; der Nachtwächter kommentiert mit
„Oh, einsmarello. Mit Rotkohl. Peak Gesang, ehrlich.“

Beide Puppen laufen jetzt über `scripts/creator_plush.gd`. Figur und Gesang
gehören einsmarello (Mitwirkende, Abspann, `Lizenzhinweise.txt`,
`assets/einsmarello-v460/LICENSE.txt`; Lied und Text: „Barbie Girl“ von Aqua).
Quellen: `tools/model-after-play-einsmarello-v460.py`,
`tools/make-after-play-einsmarello-v460.py` (12,95–16,85 s des Clips).
Prüfung: `--self-test --rosenyan-only` (beide Puppen),
Bildkontrolle: `--render-qa --rosenyan-qa`.

## Rosenyan-Puppe (4.5.0)

Im Spielbereich neben Holzbausteinen und Stoffhase sitzt eine rosa
Plüschpuppe von **Rosenyan**: Wellenhaar, Katzenohren, Herz-Ahoge, runde Brille,
große blaue Augen, Jacke, Rüschenrock, Ringelstrümpfe, Schwanz mit Schleife und
Haarschmuck. Sie lässt sich wie die anderen Spielsachen mit G aufheben, tragen
und werfen und klingt beim Aufprall nach Stoff. Bei jedem Aufheben sagt sie
„I am defeated“; der Nachtwächter kommentiert mit
„uhh RosenyanVT. Mehr Cozyness geht nicht“ (bei eingeschalteten Untertiteln,
nie doppelt in der Warteschlange).

Figur und Stimme gehören **RosenyanVT** (https://www.twitch.tv/rosenyanvt) und
werden im Menü „Mitwirkende“, im Abspann, in `Lizenzhinweise.txt` und in
`assets/rosenyan-v450/LICENSE.txt` genannt. Quellen:
`tools/model-after-play-rosenyan-v450.py` (Filzmodell, sitzend, ca. 89.000
Dreiecke) und `tools/make-after-play-rosenyan-v450.py` (Schnitt der letzten
Sekunde ihres Clips, nur Lautstärke angepasst; Satzposition lokal per
faster-whisper bestimmt). Prüfung: `--self-test --rosenyan-only`,
Bildkontrolle: `--render-qa --rosenyan-qa`.

## Neu abgemischte Schrecktöne (4.2.1)

Alle Jumpscare-Geräusche sind neu und mehrschichtig abgemischt statt je ein
einzelnes, leicht verschobenes Monster-Take zu verwenden: eine Größen-Ebene
(tiefer gestimmte Dopplung), ein Akzent aus dem neuen CC0-Kreaturenpaket
(Brüllen, Schreien, Knurren statt derselben zehn Stimmen von vorher), eine
kurze Hall-/Echofahne und stärkere Sättigung für Aggression. Jede der zehn
Klangfamilien (rabbit, clown, ossuary, crawler, window, fall, crowd, charge,
whisper, crocodile) sowie Pferd, Granny und Tür klingen jetzt hörbar
unterscheidbar und deutlich lauter (−1 bis −2,4 dBFS Spitzenpegel statt
einheitlich −5 dBFS). Granny bleibt absichtlich eine unveränderte menschliche
Stimme ohne Tonhöhenverschiebung. Der Pferde-Angriffsschrei (erster/zweiter
Kontakt) ist am lautesten und am stärksten geschichtet; der finale, dritte
Angriffsschrei bekommt zusätzlich eine tiefe Bass-Ebene. Die Verfolgungslaute
des Pferdes (`joint-*.ogg`, bisher ein dünnes Metallknarren) sind jetzt ein
nasses, nach Atem und Gurgeln klingendes Geräusch mit leichter
Bitcrusher-Körnung. Quellen: `tools/make-after-play-scare-audio-v421.py`,
`tools/boost-after-play-horse-fatal-v421.py`. Zusätzliches Rohmaterial: "80
CC0 creature SFX" von rubberduck, CC0 1.0. Prüfung: `--self-test
--quality-only` (prüft u. a., dass alle vier Varianten je Familie real und
unterschiedlich sind).

Diese Datei-für-Datei-Abmischung wurde nur numerisch geprüft (Pegel,
Verzerrung, Stille, spektrale Unterscheidbarkeit) — nicht angehört. Vor der
Veröffentlichung sollte sie im Spiel gegengehört werden.

## Neu aufgebaute Nachtbesucher

Alle vier wandernden Schreckbesucher (Kapuzenfigur, gespaltenes Gesicht,
zugenähte Lumpengestalt, Thronsitzerin) sind komplett neu modelliert statt
weiterhin die alte generisch umgekleidete Figur zu verwenden. Jeder hat einen
eigenen, ausgemergelten Körper über einem echten Skin-Skelett, einen eigenen
Kopf mit individuellem Gesicht (gespaltener Schädel mit Fängen im Rachen,
zugenähte Augen mit hängendem Kiefer, hohle Augenhöhlen unter einer Kapuze,
schreiendes Gesicht auf dem Thron) sowie knochige Hände mit geschwärzten
Krallen. Die Kleidung hängt per Tuchsimulation echt über den Körper statt als
starre Hülle; Kapuze und Thronfigur sind wegen Kollisionsproblemen der
Simulation als fest geformte Hüllen gebaut, die an Kopf bzw. Sitzhaltung
angepasst sind.

Die Köpfe nutzen weiterhin den bereits lizenzierten Gesichtsscan (Lee
Perry-Smith, CC BY 3.0) als Grundlage, individuell verformt und bemalt; Körper,
Kleidung, Hände, Zähne und Nähte sind Originalarbeit. Die Rig-Struktur
(NightVisitor > Torso/HeadRig/ArmL/ArmR/LegL/LegR) bleibt kompatibel, daher
funktionieren Posen, Sichtbarkeits-Tricks (z. B. nur Arme bei "Hände"-Schrecken)
und die Begegnungslogik unverändert. Die alte Umkleide-Pipeline (ScareSculpt)
lief sonst über die neuen Modelle und hätte Kopf und Kleidung wieder ersetzt;
sie wird für diese Begegnungen jetzt übersprungen. Quellen:
`tools/model-after-play-visitors-v421.py`,
`tools/paint-after-play-visitors-v421.py`. Prüfung: `--self-test
--nightmare-only`, `--self-test --revamp-only`, Bildkontrolle:
`--render-qa --visitors-qa`.

## Überarbeitetes Lüftungspferd

Der Kopf des Pferdes im Kinoschacht ist dunkel, faulig und nass statt hell.
In den Augenhöhlen sitzen trübe, glänzende Augen mit schmalen Pupillen. Dazu
kommen längere, schiefere Zähne, herabhängende Hautstreifen und eine lange,
nass verklumpte Mähne. Der Hals wird mit 126 weich interpolierten Ringen
zwischen den 32 animierten Stützpunkten gebildet. Er zeigt Wirbelhöcker,
Sehnen, Hautfalten, räudige Stellen und Wunden; lange Strähnen hängen
schwerkraftgerecht herab. Kollisionsfreiheit, Kiefergelenk, acht Kopfteile und
das stille Referenzpferd bleiben unverändert. Quelle:
`tools/model-after-play-long-horse-v420.py`. Bildkontrolle:
`--render-qa --long-horse-qa`.

## Neuer Küchenclown (4.2.0)

Der Küchenclown ist neu aufgebaut: ein hagerer, gebückter Körper mit Schürze,
zweilagiger Halskrause und langen Schuhen sowie ein lebensnah skalierter Kopf.
Das Gesicht trägt rissige Schminke, tiefe Augenhöhlen, offene Augen und einen
aufgerissenen Mund mit Zähnen. Beide Arme haben feste Längen und beugen sich
über eine Zwei-Gelenk-Lösung, statt gedehnt zu werden.

Bemerkt der Clown den Wächter, dreht sich nur der Kopf zu ihm. Beim Angriff
öffnet sich der Kiefer, und beide Krallenhände greifen zu. Der Clown steht
20 cm näher am Topf. Quellen: `tools/model-after-play-clown-v420.py` und
`tools/paint-after-play-clown-v420.py`. Prüfung: `--self-test --clown-style-only`
und `--render-qa --clown-style-qa`.

## Nahaufnahmen, Materialklang und Licht (4.1.0)

Die Windows-Fassung verwendet verfeinerte Hand-, Clown-, Hasen-, Pferde- und
Schreckgesichtmodelle mit den vorhandenen Quellenangaben. Gefittete Fingernaegel,
Hautfalten, kurzer gekaemmter Stoffflor und ein durchgehender Clownkragen
verbessern die Nahansichten. Ein eigener Uniformaermel ersetzt den Clownstoff;
der Interaktionsaermel wird einmal erzeugt und im Shader mit der Hand bewegt.

Ein ausgearbeitetes Empfangstelefon, eine Kassenschublade, gewoelbte Keramikteller,
Automatenbeschlaege und ueberarbeitete Geschenkbaender ergaenzen bestehende
Gegenstaende. Die Laufkollisionen werden durch diese Details nicht erweitert.
Die Taschenlampe reduziert ihre Leistung direkt vor Oberflaechen und erholt
sich beim Zuruecktreten; Kontaktverschattung, Reflexionen und Nebel wurden
abgestimmt. SDFGI bleibt wegen der vorher behobenen Bildartefakte deaktiviert.

141 neue und ueberarbeitete kurze Audioclips liefern vier Varianten pro
Schreckfamilie, Materialgeraeusche und acht abgestimmte Schritte je Boden.
Wiederholschutz, Raumfilter, Positionsnachfuehrung und Pausenverhalten bleiben
aktiv. Der normale Pferdekopf erzeugt keine Bewegungsgeraeusche. Granny nutzt
eine trockene Stimme in Originaltonhoehe. Hasensprung, Clownansturm und
kriechende Besucher besitzen unterschiedliche Bewegungsablaeufe.

Die Browserfassung behaelt die kompakteren Figurenmodelle und teilt die neuen
Audio-, Material-, Interaktions- und Animationsverbesserungen. Native Modelle
und private Herkunftsmanifeste gelangen nicht ins oeffentliche Web-Paket.

## Drei weitere Kommentare (4.0.9)

Einmalige Kommentare beim ersten Krabbeln in einer der beiden Röhren,
nach dem ersten überlebten Pferdeangriff und nach 30 Sekunden am Stück in
einer Röhre. Pause zählt nicht; Verlassen oder ein Raumneuaufbau setzt die
Aufenthaltszeit zurück. Schrecken und laufende Texte haben Anzeigevorrang.
Der allgemeine Stillstands-Spruch wird in der Röhre unterdrückt. Wiederholschutz
und Sprachwahl verwenden das bestehende Kommentarsystem; neue Schichten
setzen die Kommentare wieder frei. Keine neue Sprachausgabe.

## Empfangsnotizen und Interaktionsarm (4.0.8)

Fünf unterschiedliche handbeschriebene Aushänge ersetzen die Putztextur und
farbigen Balken am Empfang. Dünnes gewölbtes Papier mit Falten, Fasern,
Randspuren und kleinen Reißzwecken; englische Lesetexte bei Bedarf.
Die Finger beugen sich beim Drücken zur Handfläche. Der Ärmel hat korrekte
Außenflächen und bleibt vor der Kameraebene. Mechanismen außerhalb der
natürlichen Armreichweite funktionieren ohne künstlich verlängerten Arm.
Aus erreichbarer Nähe trifft der Zeigefinger die tatsächliche Klingeltaste.

## Tunnelgeräusche (4.0.7)

Die Geräuschbeschreibungen „Kinder lachen“ und „Kinder weinen“ erscheinen
in keiner Sprache mehr als Untertitel. Die Geräusche, der einmalige Kommentar
des Nachtwächters und die Untertitel gesprochener Aufnahmen bleiben erhalten.

## Kommentare, Fahrstühle und Details (4.0.6)

Die 13 Szenen aus dem Untertitel-Dokument erscheinen als innere Kommentare,
mit Schreibmaschineneffekt, leisem Tippen und einzelnen hervorgehobenen Wörtern.
Anschließend fallen die Buchstaben in die Spielwelt, bleiben kurz auf dem Boden
liegen und verschwinden. Sie besitzen keine Laufkollisionen. Die Kommentare
warten auf freie Sprechpausen und werden im Spielstand gemerkt. Fortsetzen und
Fehlentscheidungen wiederholen sie nicht; eine neue Nachtschicht schaltet sie
wieder frei. Deutsch und Englisch sind enthalten.

Beide Rückkehrkabinen nutzen denselben Aufbau wie der Startfahrstuhl, inklusive
Drucker, Bedienfeld, Etagenanzeigen, Türen und Innenausbau. Die Flure führen
mittig hinein. Der Spieler wird vor dem geschlossenen Übergang auf denselben
Standpunkt geführt. Ältere Flur-Spielstände werden an die neue Geometrie angepasst.

Eine heruntergekommene Topfpflanze mit gebogenen, geaderten Blättern ersetzt
die Stoffformen. Kleine unregelmäßig aufgeplatzte Maiskörner füllen die
Popcornmaschine; dieselben Formen liegen im Kino. Die Küche erhält eine
stabile Beleuchtung ohne die bisherigen Rasterflecken.

## Mechanische Spielereien und Kochplatz (4.0.5)

Am Empfang lassen sich die Messingklingel drücken und der leere
Kaugummiautomat drehen. An der Kartenkontrolle im Kino arbeitet ein alter
Ticketentwerter. Alle drei besitzen sichtbare Feder-, Kurbel- oder
Hebelbewegungen und eigene kurze Geräusche. Sie reagieren auf E und zählen
zur normalen Umgebung. Die vorhandenen Laufwege bleiben frei.

Der Küchenclown umfasst seinen Holzlöffel zwischen den gekrümmten Fingern.
Hand, Ärmel und Löffel bewegen sich zusammen; der ausgehöhlte Löffelkopf
folgt dem Topfinneren. Bei gelegentlichem Kontakt am Rand erklingt ein
kurzes, räumliches Klacken. Pausen und Angriffe unterbrechen das Kochen.

## Clownfrisur und Kostümmütze (4.0.4)

Der Küchenclown trägt jetzt 5.600 modellierte blonde Haarsträhnen mit mehr
Volumen, längeren Seiten und einzelnen abstehenden Haaren. Die Web-Frisur
verwendet 2.500 Strähnen derselben Gestaltung mit weniger Segmenten. Das
bisherige separate Haarmodell wird nicht mehr ausgeliefert.

Eine eingesackte, seitlich geknickte Kostümmütze aus hautähnlichem Kunstleder
sitzt oberhalb der Augen. Sechs unterschiedlich gealterte Flächen besitzen
modellierte Nahtwülste, einzelne gewachste Stiche, Quernähte, einen gerollten
Saum und eine stumpfe Kostümglocke. Der Shader ergänzt Poren, Falten und
wechselnde Rauheit. Es werden keine menschlichen Körperteile dargestellt.

Beide Accessoires hängen am bestehenden Kopf und erhalten keine Kollisionen.
Küchenclown, Küchenangriff, Pferdeauflösung und Archivschreck verwenden dieselbe
Gestaltung. Die freundliche Abschlussfeier nutzt weiterhin ihre eigene Figur.
Prüfung: `--self-test --clown-style-only` und native Vorder-/Seitenansicht über
`--render-qa --clown-style-qa`. Webprüfung: vorhandenes Playwright/Edge, da kein
Browser-Plugin verfügbar ist; Küche → pausierte Ansicht → Anspringen → Rückkehr.

## Laufwege und Klangfiguren (4.0.3)

Die Prüfung `--self-test --routes-only` bewegt den echten Spielercontroller
440-mal durch 30 Laufwege und beide oberen Röhrenmündungen: vorwärts,
rückwärts, springend und mit Spielball, Holzbaustein, Eimer oder Stoffhase.
Geprüft sind Türen, Empfang, Party-Sitzreihen, Kino-Sitzreihen und Mittelgang,
Personalflur, Küche, WC, Kostümraum, Podest, Rampen, Brücke und Aufzugböden.
Die Prüfung bleibt von der normalen Spielmechanik getrennt und wird nicht
ausgeliefert. Dabei wurde keine neue Blockade festgestellt. Die vollständigen
oberen und unteren Krabbelwege bestehen außerdem `--climbing-only`.

Pferdekontakt, Granny und Türangreifer besitzen jeweils drei separate
Stimmvarianten. Die Granny verwendet eine trockene Einzelaufnahme in originaler
Tonhöhe; das Pferd einen schrillen Klang und die Türgestalt einen kurzen,
schweren Angriff. Aufeinanderfolgende Auftritte wiederholen nicht dieselbe
Variante. Der dritte Pferdetreffer behält seinen eigenen tödlichen Schrei.
Tür- und Clownangriffe verpassen ihren Ton nun auch bei einem langsamen Frame
nicht mehr: Der Ton startet einmal beim Überschreiten seiner Zeitmarke.

Der Parkplatzschlüssel klirrt bei der tatsächlichen Übergabe und beim
Aufschließen. Papier raschelt beim Einsammeln und Lesen. Taschenlampe,
Partyknopf, Projektor und Aufnahmegerät klicken beim Betätigen. Diese
Rückmeldungen funktionieren auch bei ausgeschalteten Handanimationen und
respektieren Pause und Gesamtlautstärke. Die natürliche Spieleratmung aus
4.0.2 bleibt bestehen.

Weitere Prüfungen: `--feedback-only` (Stimmen, Varianten, reale Handkontakte,
Schlüssel, Zeitung, Lesen, Schalter und Pause), `--catch-only`, `--v280-only`,
`--update-v3810-only` und `--revamp-only`. Browserprüfung über vorhandenes
Playwright/Edge; Browser plugin not available. Testablauf: Spielstart,
Taschenlampe, Schlüssel, Zeitung lesen, rückwärts durch die Kinotür und durch
die Sitzreihe, danach Überprüfung der Granny-Klangzuordnung.

## Natürlichere Spieleratmung (4.0.2)

Die eigene Atmung nutzt jetzt einen separaten, leiseren Schnitt aus der
unveränderten menschlichen Originalaufnahme. Tiefes Mikrofonrauschen und die
starke Nasenresonanz sind reduziert. Sprinten und Erholung verändern die
Lautstärke, ohne die Tonhöhe zu verschieben. Zwei vollständige Atemzüge laufen
mit ihren natürlichen Pausen in einer Schleife. Pause, Lautstärkeeinstellung und
allmähliche Erholung bleiben erhalten. Die räumlichen Gruselgeräusche verwenden
weiterhin ihre bisherigen Aufnahmen.

Prüfung: `--self-test --tactile-only` mit Sprint, normaler Tonhöhe, Erholung,
Pause, Stummschaltung und Rücksetzen der Spielergeräusche.

## Drei Treffer bei der Pferdeverfolgung (4.0.1)

Der erste Kontakt hinterlässt einen leichten blutunterlaufenen Bildschirmrand,
der zweite verstärkt ihn. Die Bildmitte bleibt frei. Trefferzahl und Darstellung
werden gespeichert; ältere Spielstände mit beliebig vielen Kontakten werden
auf höchstens zwei Verletzungen übernommen. Die ersten beiden Schreckmomente
behalten Rückzug, Wiederaufnahme der Verfolgung und sechs Sekunden Abstand.
Der Clown kann die Verfolgung weiterhin lösen und die rote Tür freigeben.

Der dritte Kontakt startet einen eigenen tödlichen Angriff: Das Pferd richtet
den Kopf auf, reißt das Maul weit auf und stößt ein eigenes schrilles Kreischen
aus. Bewegung und Interaktionen sind währenddessen gesperrt. Danach folgen
Schwarzblende, überlebte Rundgänge und Erwachen im ursprünglichen Fahrstuhl bei
Rundgang eins. Ein sofortiger Neustart des Spiels lädt ebenfalls diesen Neubeginn.
Verfolgungsmusik und Kreischen stoppen beim tödlichen Einschlag. Außerhalb der
Anomalie greift das Referenzpferd weiterhin nicht an.

Die Wegsuche nutzt denselben Kapselradius wie der Spieler. Der bisher breitere
Prüfkörper hatte den Zugang zur Toilettenanlage fälschlich als versperrt erkannt.
Die Prüfung der vollständigen Köderroute läuft mit echtem Sprinten und bleibt
mit höchstens zwei Treffern bis zum Küchenclown spielbar.

Prüfungen: `--self-test --catch-only`, `--render-qa --horse-damage-qa` sowie
Playwright `v4.0.1 horse injuries` (Code, drei echte Kontakte, Pause, Neuladen,
Schadenssteigerung, Tod und Fahrstuhlrückkehr in Edge bei 1920 × 1080).

## Greifbare Interaktionen und Spielergefühl (4.0.0)

Eine originale, durchgehend gewichtete Hand mit 17 Knochen bedient Türklinken,
Taster und das Türterminal, nimmt Schlüssel und Zeitungen auf und führt den
Parkplatzschlüssel zum Schloss. Aktionen werden beim Kontakt ausgeführt;
erneutes E startet währenddessen keine zweite Aktion. Pause oder ein Wechsel
der Welt verwirft eine noch nicht ausgeführte Aktion. Mit ausgeschalteten
Handanimationen bleiben Interaktionen sofort verfügbar.

Türklinken besitzen getrennte Federhebel, Rosetten, Schrauben und Schlüssellöcher;
der Parkplatz bekommt einen drehbaren Zylinder, das Terminal einzelne Tasten
und der Partytaster eine bewegliche Kappe. Zeitungen haben eine bedruckte
Vorderseite, gealterte Rückseite und dünne Kanten. Die gebogene Kinozeitung
behält ihre an den Sitz angepasste Form. Die Details erzeugen keine zusätzlichen
Laufkollisionen. Die Browserhand verwendet eine reduzierte Version desselben
Modells; nur das passende Modell wird je Plattform ausgeliefert.

Nach Sprinten klingt die eigene Atmung allmählich ab. In beiden Krabbelstrecken
reibt die Kleidung hörbar am Kunststoff, solange sich der Spieler bewegt.
Eine gedämpfte Bewegung lässt die Ausrüstung beim Abbremsen leicht nachfedern.
Die vorhandenen CC0-Aufnahmen werden wiederverwendet. Einstellungen für eigene
Atmung/Kleidung, Körperbewegung und Handanimationen werden gespeichert und sind
auf Deutsch und Englisch verfügbar. Die Geräusche sind normale Atmosphäre.

Prüfungen: `--self-test --tactile-only` einschließlich Rundgangsverteilung,
`--render-qa --tactile-qa` sowie Playwright `v4.0.0 tactile interactions`.
Browserprüfung über das vorhandene Playwright/Edge-Setup, da kein Browser-Plugin
zur Verfügung steht.

## Startfahrstuhl und Handy (3.9.1)

Die ursprüngliche Kabine bleibt am bisherigen Ort. Gealterte Emaille-Paneele,
dunkle Holzverkleidung, gebürstete Türblätter mit Falzen und Dichtungen,
eingelassene Taster mit Blindenschriftpunkten sowie gerahmte Deckenleuchten
ersetzen die bisher überwiegend glatten Flächen. Eine gezeichnete Happyland-
Druckkarte mit Messingrahmen sitzt an der Rückwand. Etagenanzeige und
Kontrollzetteldrucker behalten ihre Funktion. Die Details sind pro Material
zusammengeführt; nur die bisherigen fünf einfachen Kabinenflächen kollidieren.
Türschwelle und Bodeneinfassung liegen flach unter der üblichen Schritthöhe.

Handy und Hand wurden neu modelliert: abgerundeter Schutzrahmen, gefasstes
Frontglas, versenkte Kameras, Tasten, Ladebuchse, Lautsprechergitter und
Gebrauchsspuren. Die Hand ist eine durchgehende, passend um das Gehäuse geformte
Oberfläche mit Hautpigment, Falten, Nägeln und gewebtem Uniformärmel. Das
abgerundete Live-Display sitzt innerhalb des Glasrandes. Annahme, Gesprächsuhr,
Pause, Untertitel und Überspringen behalten den bisherigen Ablauf. Die
Annehmen-Schaltfläche ist kompakter; alte Telefonmodelle werden nicht mehr
exportiert. Englische Schilduntertitel erfassen auch die Kabine. Pfeile und
Tastersymbole bestehen aus echter Geometrie, damit fehlende Browser-Schriftzeichen
keine Lücken hinterlassen.

Prüfungen: `--self-test --lift-only` (Startablauf, Etagen, Display, Pause,
Rückkehr und echter Physikweg über die Türschwelle), `--render-qa --lift-qa` und
Playwright `v3.9.1 redesigned lift`. Browser plugin not available; browser QA
uses the existing Playwright/Edge setup at 1920 × 1080. The flow under test is:
main menu → new shift → accept call → pause/resume → skip → walk out of lift.

## Persönliche Nachtschicht und neue Schreckfiguren (3.9.0)

Das Erinnerungsalbum im Hauptmenü speichert entdeckte Enden und echte, ohne HUD
aufgenommene Bilder der Schlusssequenzen in einer eigenen Profildatei. Neue
Schichten und falsche Türen löschen diese Einträge nicht. Unentdeckte Enden
zeigen weder Titel noch Bilder. Die Vorschau 07122000 schaltet nichts frei.
Nach zwölf richtigen Entscheidungen druckt der Startfahrstuhl einen Zettel:
„Letzter Kontrollgang. Danach Feierabend.“ E zeigt ihn zusätzlich groß an.

Die Taschenlampe hat ein neu modelliertes Metallgehäuse mit Griff, Kühlrippen,
Reflektor und Schutzglas. Das Licht ist rund 17 Prozent heller. Gedämpftes
Nachziehen, Laufbewegung und eine stabile Landefeder folgen der Einstellung
Kamerabewegung. Eine kurze Kollisionsabfrage zieht das Modell vor Wänden ein.
Deckel und Jacke reagieren ausschließlich auf Kontakt; ein einzelner einfacher
Pappbecher rollt beim Anstoßen. Alle Reaktionen und Geräusche folgen Pause und
Lautstärke und verändern die Anomalieentscheidung nicht. Dieselbe verblasste
Happyland-Sonnenmarke erscheint auf Karten, Bechern, Jacke und Automatenmarken.

Die Startwarnung ist neu gesetzt und behält Sprachwahl, Gesundheitsinformation,
bewusste Bestätigung und Stroboskop-Schalter. Besucherin und Angreifer an der
falschen Tür erhalten anatomische Köpfe auf Basis des bereits attribuierten
Lee-Perry-Smith-Scans: originale UVs, echte Augenöffnungen, eingesetzte Augen und
Zahnreihen, gealterte Haut, schmutzige Haare, Stofffalten und Hände. Die bekannten
Anomalien, ihre Auslöser und die geschützten Zeitungsrunden bleiben erhalten.

Die Feier nach Ende 1 dauert jetzt zwei Minuten. Die Kamera fährt die bestehende
freie Strecke weich hin und zurück, statt nur eine langsamere Einstellung zu
halten. Musik und Licht folgen weiter Rolling Acid; die letzten drei Sekunden
blenden den Song aus. Gedrückte Leertaste überspringt die Feier weiterhin.

Prüfungen: `--self-test --shift-only`, `--self-test --balance-only` und
`--render-qa --shift-qa`. Die Galerie nutzt im Browser denselben lokalen
Speichermechanismus wie die Spielstände. Bilder werden nur lokal gespeichert.

## Überarbeitete Feierfiguren im Originalraum (3.8.14)

Der Partyraum behält seine echten Wände, Böden, Bühne, Tische, Stühle, Snackbar,
Geschenke und Wandbilder. Nur der blutige Hase wird während der Schlusssequenz
gegen die saubere Variante getauscht. Warmes Licht, die vorhandene Partyanlage,
Ballons und Konfetti verändern die Stimmung, ohne den Raum zu ersetzen.

Clown und Gäste haben zusammenhängende gefaltete Kleidung, modellierte Gesichter,
Augenlider, Hände mit Fingern, Schuhe, Ärmel und Säume. Der Clown trägt blonde
Locken, eine Halskrause und eine Weste. Die Figuren tanzen unterschiedlich;
zweigliedrige Beine halten das Standbein am Boden und die Knöchel gleichen die
Bewegung aus. Der DJ greift zum Pult. Das Pferd hat einen zusammenhängenden,
über 18 Gelenke weich verformten Hals, vier Beine, Schweif und einen detaillierten,
freundlichen Kopf. Der Stoffhase bekommt glänzende Knopfaugen und eine Schleife.

Statische Details werden pro Gelenk und Material zusammengeführt; zusätzliche
Texturen oder Modelldownloads sind dafür nicht nötig. Kamera und Tanzplätze
berücksichtigen die Originalmöbel. 07122000, Musikwechsel und die anderen Enden
behalten ihren Ablauf. Prüfung: `--self-test --celebration-only`,
`--render-qa --celebration-qa` und optional `--celebration-detail-qa`.

Die Browser-Feier verzichtet auf die Schatten der vorhandenen Lampen und stellt
diese danach wieder her. Die Haltezeit zum Überspringen berücksichtigt die echte
verstrichene Zeit, damit langsame Renderframes die Taste nicht ausbremsen.

## Feier nach Ende 1 (3.8.13)

Nach den Credits des regulären 13-Rundgänge-Endes folgt eine 48-sekündige
Kamerafahrt durch eine freundliche Variante des Partyraums. Ein sauberer großer
Stoffhase trinkt Cola, Clown und drei Besucher-Varianten tanzen, das lange Pferd
bewegt Kopf und Hals, ein Besucher steht am DJ-Pult und fünf kleine Stoffhasen
ziehen als Polonaise durch den Raum. Pastellfarben, Ballons und Konfetti ersetzen
für diese Sequenz die düstere Ausstattung. Mittig steht „Ende 1/3“.

„Fern and Feather“ wird beim Szenenbeginn gestoppt; nur „Rolling Acid“ läuft,
beginnend kurz vor seinem ersten Bass-Einsatz. Die Spieluhr bleibt stumm. Die
Musik der Feier hängt an der Gesamtlautstärke und wird vom Standort der inaktiven
Spielfigur nicht gedämpft. Die vorhandene Stroboskop-Einstellung gilt weiterhin.
Das bisherige Halten der Leertaste zum Credits-Überspringen überspringt die Feier
erst nach Loslassen und erneutem Halten. Die beiden anderen Enden behalten ihren
bisherigen Abschluss; die nummerierten Titel berücksichtigen jetzt drei Enden.

Der Terminalcode **07122000** startet die Vorschau einschließlich der Credits
ohne Zeitungsanforderung. Fortsetzen lädt danach den gespeicherten Rundgang mit
seiner tatsächlichen Anomalie. **0712** und **07120712** bleiben erhalten.
Die Feier verändert keine gemeinsamen Materialien oder Figuren des Hauptspiels.
Die saubere, bewegliche Hasenvariante stammt aus dem vorhandenen kleinen Stoffhasen;
`tools/model-after-play-party-cast.py` erzeugt das Modell mit getrennten Gelenken.

Prüfung: `--self-test --celebration-only`, `--endings-only`, `--startup-only`;
native Kameraproben: `--render-qa --celebration-qa`; Browser-Test „v3.8.13“.

## Partyschalter im Kostümraum (3.8.12)

Der einzige Partyschalter sitzt jetzt an der Ostwand neben der Kreidetafel im
Raum mit den hängenden Teddy-Kostümen. Der Technikraum enthält keinen zweiten
Schalter mehr. Einschalten startet die vorhandene Partyanlage; Ausschalten
stoppt Musik und Licht und beginnt einen 15-minütigen Systemneustart. Während
dieser Zeit zeigen Schalter und Interaktionshinweis die verbleibende Zeit;
wiederholtes Drücken schaltet nichts ein und verlängert die Wartezeit nicht.

Der absolute Zeitstempel wird im Spielstand aufbewahrt und bleibt bei einem
Rundenwechsel, einer neuen Schicht und beim Fortsetzen erhalten. Auch außerhalb
des Spiels vergeht die Neustartzeit. Alte Spielstände ohne diesen Wert starten
ohne Sperre. Deutsch und Englisch sind enthalten.

Prüfung: `--self-test --party-control-only` sowie Browser-Test „v3.8.12“.
Das bestehende Hasen-Icon ist in allen sechs Windows-Größen in der Anwendung
enthalten; die ZIP-Ansicht des Explorers kann ein allgemeines EXE-Symbol zeigen.
Zum Starten zuerst das gesamte Archiv entpacken.

## Rolling Acid (3.8.11)

Die Partyanlage spielt jetzt Kyokos „Rolling Acid“ (4:32) statt „Mirage“.
Die originale MP3 bleibt einschließlich Suno-Metadaten unverändert; die
Web-Fassung verwendet eine Ogg-Konvertierung. `tools/prepare-after-play-party-v385.py`
erzeugt Bass-/Lautstärkeverlauf, lokal erkannte Kick-Einsätze und fünf anhand
der Aufnahme geprüfte Lichtabschnitte. Ruhige Passagen, Aufbau, Bass-Einsätze
und Ausklang steuern Intensität, Bewegung und kurze, abschaltbare Lichtblitze.
Die Lichtkarte gilt nur für die dort geprüfte SHA-256 der Aufnahme.

Suno-Free-Titel: ausschließlich persönliche, nichtkommerzielle Nutzung nach
den Suno-Bedingungen; keine kommerzielle Lizenz nachgewiesen. Vor einem Upload
auf itch.io muss das Projekt unter **Pricing → No payments** stehen, ohne
optionale Zahlungen oder Spenden. Credits, Abspann und Lizenzhinweise nennen
die neue Musik. Diese Änderung veröffentlicht sich nicht automatisch auf itch.io.

Prüfung: `--self-test --party-music-only`, `--party-stereo-only` und
`--update-v385-only`; Browser-Test „Rolling Acid“ prüft die fünf Abschnitte,
späte Abspielpositionen, Schleife, Pause, Fortsetzen und gespeicherten Partymodus.
Native Vorschau: `--render-qa --rolling-acid-qa`.

## Sprache, Untertitel und Medien (3.8.0)

Unter Einstellungen → Sprache lassen sich Deutsch und Englisch wählen. Menüs,
Inventar, Zeitungen, Notizen und Abspann folgen dieser Einstellung. Telefonat,
Kinowerbefilm und Archivaufnahme besitzen zeitgesteuerte Untertitel. Beim Ansehen
der Schilder erscheint ihre englische Lesefassung; beide Untertitelarten sind
getrennt abschaltbar. Die originale Beschriftung in der Spielwelt bleibt erhalten.

Die erhöhten Röhren haben freie Mündungen, der Aussichtskasten nutzt die vorhandenen
Stützen und eingearbeitete Schrift im Holzmaterial. Reparaturringe sitzen nur auf
Stützpfosten. Querleisten an den Öffnungen liegen nicht mehr im Weg; die Spieluhr
steht vollständig auf der Kommode. Der neue Trailer zeigt 75 Sekunden native
Spielszenen ohne Jumpscares oder Hinweise auf die geheimen Enden. Zwölf neue
Full-HD-Screenshots liegen zusammen mit dem Trailer unter `build/itch-media-v3.8.0/`.

Die Webseite enthält keine lange Versionschronik mehr. Die Spracherkennung lief
ausschließlich lokal; die bearbeiteten Untertitel stehen unter `locales/`.

## Neue Musik (3.7.1)

Die von Kyoko bereitgestellten MP3-Dateien werden unverändert eingebunden:
„Fern and Feather“ ersetzt die Abspannmusik bei allen drei Enden.
„Music Box Chase“ startet bei der Pferde-Anomalie, wird bei Kontakt und beim
Clown leiser und blendet nach dem vollständigen Rückzug des Pferdes aus.
Pause und Fortsetzen bewahren die Abspielposition; alte Spielstände ohne
Musikposition bleiben kompatibel. Die Verfolgungsschleife läuft nur während
der entsprechenden Anomalie. Die Spieluhr im Partyraum bleibt erhalten.
Ungenutzte Dateien des alten Krokodilmodells v3 werden nicht mehr exportiert.
123 native Prüfungen und der Web-Test für Musik, Pause, Neuladen und alle drei
Abspänne bestanden. Prüfung: `--self-test --music-only` und
`--self-test --hunt-only`.

## Kletteranlage und Partyraum-Rundweg (3.7.0)

Ein begehbarer Aussichtskasten mit handschriftlich eingeritzten Namen, altem
Aussichtsgerät und zurückgelassenem Kinderschuh erweitert den oberen Westturm.
Eine durchgehende erhöhte Kunststoffröhre führt durch die westliche Partyraumwand,
in drei Kurven über die Feier und durch die südliche Wand zurück zum Ostturm.
Beide Wandlöcher besitzen echte runde Laibungen und passende Kollisionen.
Verkratzte transparente Abschnitte lassen den Blick in den Partyraum frei.
Vergilbte Flansche, Schrauben, Befestigungen, Reparaturbänder und verschlissenes
Holz gehören zur normalen Umgebung. Die bestehende untere Krabbelröhre, ihre
Zeitung und die nur von innen sichtbare Fenstergestalt bleiben erhalten.

Der interne Aufstieg, die obere Ostrampe und ihre Landung besitzen durchgehende
Laufflächen. Die störende Rutscheneinstiegskante und darüberliegende Polster
sind bereinigt. Neue Spielstände in der oberen Röhre werden geduckt geladen.
Der Zugang führt vom Ostturm über die Holzbrücke und die neue innere Rampe.
131 native Prüfungen für Ausbau, Platzierung, Verfolgung und Spielstart sowie
ein vollständiger Web-Durchlauf in beide Richtungen mit echtem Neuladen bestanden.
Native Prüfung: `--self-test --climbing-only`; Bildkontrolle:
`--render-qa --v370-qa`. Ersteller-Codes `0712` und `07120712` bleiben erhalten.

## Nicht tödlicher Pferde-Jumpscare (3.6.1)

Erreicht das verfolgende Pferd den Spieler bei freier Sicht, folgt ein eigener
Pferde-Jumpscare mit dem vorhandenen blutigen 3D-Kopf und einem anderen Kreischen
als beim Küchenclown. Der Kopf zieht sich anschließend 2,8 Meter auf seinem
aufgezeichneten Weg zurück und kommt auf genau diesem Weg wieder vor. Danach
setzt er dieselbe Verfolgung fort. Die Schicht, Runden und Fundstücke bleiben
erhalten; die rote Tür bleibt bis zur Lösung beim Clown verriegelt. Sechs Sekunden
Sperrzeit verhindern unmittelbar aufeinanderfolgende Kontaktangriffe. Pause und
Fortsetzen bewahren auch Jumpscare, Ton, kurzen Rückzug und Rückweg.

`horse_clown_hunt` wird regulär aus den 65 Anomalien gezogen. Der Ersteller-Code
ist dafür nicht erforderlich. Die Rundenprüfung zählt ausdrücklich natürliche
Pferde-Ziehungen über 2.048 Schichten; die Zeitungsrunden bleiben geschützt.
`--self-test --catch-only` prüft natürlichen Start, Einholen, Sichtblockaden,
Nicht-Tödlichkeit, Wiederaufnahme, Sperrzeit und Speichern/Fortsetzen. Native
Spielaufnahmen entstehen mit `--render-qa --v361-qa`.

128 gezielte native Checks bestehen: Kontakt 20, vollständiges Rätsel 51,
Rundenverteilung 19, Pferdegeometrie 14 und Start/Abspann 24. Im Zufallstest
erscheint die Pferde-Verfolgung 186-mal ohne Ersteller-Code. Die Windows- und
Web-Pakete bestehen Dateiliste, CRC, Prüfsummen, Lizenzen und den Ausschluss
privater Werkzeuge. Die exportierte Windows-Fassung startet fehlerfrei.

## Pferd-und-Clown-Begegnung (3.6.0)

Der normale Pferdekopf bleibt einschließlich Kiefer und Hals vollständig still.
`horse_clown_hunt` erweitert den Katalog auf 65 Anomalien: Der Kopf folgt dem
Spieler durch die begehbaren Räume, sein Hals wächst vom Kinoschacht aus entlang
der tatsächlich zurückgelegten Strecke. Ein schrittweise erstelltes Bodennetz
führt ihn zunächst zum Spieler; danach übernimmt dessen realer Laufweg auch auf
Podesten und in niedrigen Bereichen. Vor niedrigen Türstürzen senkt er den Kopf.
Zusätzliche Halsabschnitte teilen sich ihre Geometrie und besitzen eigene Grenzen
für die Sichtbarkeitsprüfung.

Rot ist währenddessen physisch verriegelt und trägt einen handschriftlichen
Zettel: „Pferde mögen keine Clowns“. Erst wenn das Pferd in die Küche gelockt
wird, springt der Küchenclown mit einem eigenen Kreischen auf es zu. Der Kopf
fährt alle aufgezeichneten Positionen und Drehungen rückwärts bis zum Schacht
zurück. Erst dann verschwindet der Zettel und die rote Tür wird freigegeben.
Der Clown kehrt auf seinen Platz zurück. Seine neuen wilden blonden Haarsträhnen
sind am vorhandenen gescannten Kopf befestigt; Gesicht, Augen und Zähne bleiben
unverändert. Die Haare besitzen keine Kollisionen.

Pause, Inventar und Zahlenschloss halten Begegnung und Ton an. Speichern und
Fortsetzen bewahren Kopf, Halsweg, Laufspur, Clown-Sprung und Rückzugsfortschritt.
Der Begegnungszustand wird vor den Entscheidungstüren geladen: Auch ein bereits
betretener roter Flur bleibt nach gelöstem Rätsel beim Fortsetzen geöffnet.
Die bisherige Verteilung bleibt bei sechs Anomalien und sieben normalen Runden
pro frischer 13er-Serie. Zeitungsrunden 3/5/8/11 bleiben im normalen Spiel garantiert anomaliefrei.
Nur der ausdrücklich eingegebene Ersteller-Code `07120712` am Archivschloss
ersetzt die aktuelle Runde durch diese Begegnung, ohne Rundenstand, Zufallsdeck
oder Fundstücke zu verbrauchen. Die Ausnahme bleibt beim Laden erhalten.
`0712` öffnet weiterhin unabhängig davon das Archiv.

Gezielte Prüfungen: `--self-test --hunt-only`, `--horse-only`, `--balance-only`,
`--release-only`, `--startup-only` und `--circulation-only`. Der private Edge-Test
betätigt das achtstellige Schloss, läuft mit Tastatur in den Partyraum und zurück
zur Küche und prüft Pause, Fortsetzen, Rückzug und Freigabe. Native Aufnahmen
entstehen über `--render-qa --v360-qa`. Diese Werkzeuge sind in Spielerpaketen
ausgeschlossen. itch.io wird ausschließlich über den vorhandenen manuellen
Upload-Befehl aktualisiert.

173 gezielte native Checks bestehen: Begegnung 51, Pferdegeometrie 14,
Rundenverteilung 18, Archiv/Release 36, Start/Abspann 24 und Laufwege 30.
Drei Edge-Prüfungen bestehen für Podest/Auto, den reglosen Vergleich und den
vollständigen Rätselablauf mit Neuladen während der Verfolgung. Neun native
Aufnahmen zeigen Haare, Hinweis, Verfolgung, Clown-Angriff und Rückzug.
Windows- und Web-Paket bestehen Dateiliste, CRC, Prüfsummen, Lizenzen und die
Abgrenzung der Erstellerwerkzeuge; die exportierte Windows-Fassung startet ohne
fehlende Ressourcen. Der Web-PCK bleibt mit 198,78 MiB unter dem Dateilimit.

## Begehbare Podestkante und versetztes Spielauto (3.5.7)

Der flache Holzaufgang führt jetzt über die komplette sieben Meter breite
Vorderkante des Geburtstagspodests. Bisher lag die Rampe ausschließlich rechts
vor dem Kostümraum; vor dem Thron blieb eine blockierende 20-cm-Stufe. Sichtbare
Schräge und einfache Kollision stimmen überein. Holzschritte bleiben erhalten.

Das rote Spielauto steht neben der zum Partyraum gerichteten Seite des
Klettergerüsts. Beide Auto-Anomalien verwenden denselben neuen Ursprung.
Ihre Beschreibungen und Bereichszuordnung folgen dem neuen Standort. Der
Partydurchgang bleibt auch beim vergrößerten Auto frei.

Die gezielte Bewegungsprüfung läuft mit stehender Spielerkapsel ohne Sprung an
sechs Stellen über die Podestkante hinauf und hinunter, vom Saal aufs Podest
und durch die Kostümraumtür in beide Richtungen. Zusätzlich werden der neue
Auto-Standort, beide Auto-Anomalien und der Partydurchgang geprüft. Native
Spielaufnahmen zeigen den flachen Aufgang und das Auto neben der Kletteranlage.

54 gezielte native Checks bestehen: Bewegung/Auto 30 und Start/Abspann 24.
Auch der Edge-Test begeht die Podestkante ohne Sprung in beide Richtungen und
den freien Partydurchgang. Windows- und Web-Paket bestehen Datei-, CRC-, Lizenz-,
Prüfsummen- und Datenschutzprüfung; die exportierte Windows-Fassung startet
ohne fehlende Ressourcen. Der itch.io-Aufruf bleibt ein lokaler Probelauf.

## Pferdemaske und durchgehende Flurdecke (3.5.6)

Das Küchendienst-Bild hinter dem Kühlschrank und das Personalgang-Schild an der
Stirnwand sind entfernt. Ein durchgehender, gleich hoher Deckenraster reicht vom
Holzportal bis zur hinteren Flurwand; der vorherige schwarze Abschnitt entfällt.

Das alte Pferdeskelett ist durch eine original modellierte, körperlose Gestalt
**ohne Rumpf oder Gliedmaßen** ersetzt: sichtbar sind ausschließlich eine lange,
zusammenhängende Halsform und eine beschädigte Pferdemaske. Die Maske hat echte
Augen-/Nasenhöhlen, aufgerissene Ränder, Zahnfleisch, unregelmäßige Pferdezähne,
einen beweglichen Unterkiefer und eine verklumpte Mähne. Die Haut verwendet
gemalte Vertexfarben und Porennormalen; Blutflächen reagieren rauer oder feuchter
auf Licht. Das Modell besteht aus acht zusammengefassten Oberflächen und rund
24.000 Dreiecken. Der Hals und seine einzelnen Mähnensträhnen verwenden zwei
zusätzliche, verformte Meshes mit 32 gemeinsamen Stützpunkten statt vieler
Einzelobjekte oder neu aufgebauter Geometrie pro Frame.

Der Hals bleibt im dunklen Lüftungsschacht verankert, windet sich entlang der
Kinodecke und lässt den Kopf kurz durch die Kinotür in den Flur spähen. Pause
stoppt auch Kiefer und Hals. Beim Schachtangriff bewegt sich nur der sichtbare
Kopf mit seinem Halsende; der Ursprung wird nicht aus dem Schacht gezogen.
Diese Bewegung gehört weiterhin zur normalen Atmosphäre, auch in Zeitungsrunden.

Die gezielte native Prüfung untersucht 41 Positionen entlang der Bahn mit den
tatsächlichen Kopf-/Kiefervertices sowie allen Halsstützpunkten gegen Decke,
Schachtöffnung und Kinodurchgang. Zusätzlich werden Pausenverhalten, Angriff,
entfernte Bilder und der vollständige Deckenverlauf geprüft. Der Browser-Test
wartet den natürlichen Bewegungszyklus ab, pausiert beim Blick in den Flur und
geht anschließend durch den Kinodurchgang. Alte, unbenutzte Pferdemodelle werden
nicht mehr in die Spielerpakete exportiert.

60 gezielte native Checks bestehen: Pferdebahn/Decke 14, Eingang/geheimes Ende
22 und Start/Abspann 24. Der isolierte Edge-Test besteht mit natürlicher
Bewegung, Pause und begehbarem Kinodurchgang; es treten keine Browser- oder
Shaderfehler auf. Beide Spielerpakete bestehen Dateilisten-, CRC-, Lizenz-,
Prüfsummen- und Datenschutzprüfung; die exportierte Windows-EXE startet ohne
fehlende Ressourcen. Das Web-PCK umfasst 197,75 MiB. Der itch.io-Aufruf wird
weiterhin nur lokal vorbereitet; ein Upload erfolgt erst mit `-Upload`.

## Alter Holzrahmen und Snackbar im Partyraum (3.5.5)

Der Zugang zum Küche/Kino-Flur erhält einen vollständigen alten Holzrahmen:
tiefe Futterbretter, beidseitige profilierte Bekleidungen, Sockel, Eckstücke,
Nagelköpfe und eine teilweise fehlende Zierleiste. Der eigene Holzshader bildet
längs laufende Maserung, abblätternde Beschichtung, feine Spalten und dunkle
Feuchtigkeit am Fuß ab. Drei einfache Kernkollisionen lassen den Flur frei.
Das markierte Technischer-Dienst-Schild neben dem Wartungsraum ist entfernt;
die separate Tafel innerhalb der Werkstatt bleibt erhalten.

Die komplette Snackbar steht an der markierten Wand im Partyraum. Das große
Wandbild hängt 1,10 m höher, sodass beide Slush-Maschinen darunter frei stehen.
Die Speisekarte hängt ohne Verkleinerung an der angrenzenden Wand. Ein kleiner,
wandbefestigter Servicestrahler beleuchtet die Arbeitsfläche. Becher, Geschirr,
alte Pommes und die kleine Wasserstelle folgen der Snackbar an den neuen Ort.
Beide Slush-Geräte haben jetzt eindeutige Namen und eine gemeinsame Kennzeichnung;
damit erhält auch das zweite Gerät die vorgesehenen Lüftungsschlitze und Ablagen.

Der Snackbar-Besucher zählt zum Partyraum. Sein Anker und der Besucher unter dem
Clownfresko wurden von den neuen Möbeln freigehalten; Sammlung, Rundenauswahl und
Enden bleiben im bestehenden Ablauf. Die Kollisionsgrenzen für gespeicherte
Spielstände folgen der versetzten Snackbar.

66 native Checks bestehen: Szenenumbau 20, Eingang/geheimes Ende 22 und
Start/Credits 24. Sie durchlaufen den Holzrahmen in beide Richtungen, den Zugang
zum Partyraum und den Weg neben den Tischen, prüfen die reale Thekenkollision,
Speisekarte, beide Maschinen sowie Kollisionen und Sichtauslöser der zwei
versetzten Anomalien. Sechs native Aufnahmen bei 1920 × 1080 zeigen Rahmen,
Snackbar, Speisekarte, entfernte Tafel und die freigewordene Stelle im Hauptsaal.
Der Platzierungsbericht meldet keine Tür-, Bild- oder Möbelüberschneidungen.
Der Edge/Playwright-Test bestätigt den Durchgang in beide Richtungen, die neue
Snackbarposition samt beiden Geräten, den freien Weg neben den Tischen und die
Thekenkollision. Beide versetzten Anomalien werden mit ihren echten Sichtauslösern
aktiviert; keine Konsolen- oder Shaderfehler. Windows- und Web-Pakete bestehen
Dateilisten-, Hash-, Lizenz- und Startprüfung. Der itch.io-Upload wurde lokal
geprüft; es wurde nichts zu itch.io hochgeladen.
Private Prüfungen: --self-test --scenery-only und --render-qa --v355-qa.

## Empfang am Haupteingang (3.5.4)

Der Empfangstresen steht um 90 Grad gedreht neben dem Haupteingang, mit seiner
Kundenseite zum ankommenden Besucher. PC, Telefon, Papier, Armbandspender und
Lampe folgen seinem lokalen Koordinatensystem; auch das praktische Lampenlicht
und das Frontbild bleiben am Möbel. Der Bildschirm zeigt zum Arbeitsplatz.
Dahinter steht ein eigener gepolsterter Bürostuhl mit Armlehnen, Gasfeder,
Höhenverstellung und fünf Rollen. Zwei einfache Kollisionskörper ersetzen jede
Kollision der kleinen Rollen- und Gestelldetails.

Pinnwand, Öffnungszeiten-Plakat und Uhr wurden entsprechend der markierten
Anordnung versetzt: Pinnwand hinter dem Arbeitsplatz, Uhr darüber, Plakat weiter
zum Fenster. Der Abfalleimer steht an der Wand außerhalb des Eingangswegs.
Die Empfangs-Anomalien hinter dem Tresen und die Besucherwarteschlange haben
passende neue Anker; der Monitor mit sieben Kameraperspektiven bleibt bedienbar.
Ein alter Spielstand darf weder im neuen Tresen noch im Bürostuhl fortgesetzt
werden.

66 native Checks bestehen: Empfang 20, Eingang/geheimes Ende 22,
Start/Credits 24. Sie durchlaufen den tatsächlichen Weg durch den Eingang,
um die Thekenkante und hinter den Arbeitsplatz, prüfen Monitorbedienung,
Wandmontage, Spielstandpositionen und die Kollisionen/Sichtauslöser der drei
versetzten Anomalien. Vier native Aufnahmen bei 1920 × 1080 zeigen beide
Tresenseiten, den Stuhl und die Wandanordnung. Der Platzierungsbericht findet
keine blockierten Türen, überlappenden Bilder oder eingebetteten Möbel.
Der Edge/Playwright-Test läuft durch den Haupteingang und um das Tresenende,
öffnet den Monitor vom Arbeitsplatz, wechselt alle sieben Kameras und prüft
weiterhin Fotowand und physische Bälle samt Pause. Keine Konsolenfehler.
Windows- und Web-Pakete bestehen Dateilisten-, Hash-, Lizenz- und Startprüfung;
der itch.io-Upload wurde nur lokal geprüft.
Private Prüfungen: --self-test --reception-only und --render-qa --v354-qa.

## Verbarrikadiertes Fenster und hörbarer Donner (3.5.3)

Sechs einzeln modellierte, unregelmäßige Holzbretter sind außen vor dem Glas
an zwei senkrechten Leisten vernagelt. Dazwischen bleiben echte Sichtschlitze;
einer liegt auf Augenhöhe des stehenden Spielers. Die geschlossene Scheibe
behält ihre Kollision und Schalldämpfung. Innen hängen zwei zurückgebundene,
gefaltete Stoffvorhänge an einer Stange mit Wandhaltern und Aufhängeringen.
Die neuen Teile liegen außerhalb der Laufwege.

Der Donner war durch eine zweite starke Pegelabsenkung kaum wahrnehmbar.
Sein Pegel ist jetzt im Hauptraum um 12,55 dB angehoben. Zusätzliche mittlere
Frequenzen machen das ferne Grollen auch auf kleineren Lautsprechern hörbarer.
Der Dachregen bleibt unverändert leise. Die erste Rolle folgt nach 8–16 Sekunden
aktiver Spielzeit, weitere nach 40–70 Sekunden; Pause und Sprachaufnahmen werden
weiter respektiert. Der tatsächliche gefilterte Wetterbus erreicht während
des Grollens −33,46 dBFS RMS und −16,64 dBFS Spitze, gegenüber −42,19 dBFS RMS
bei Regen allein, jeweils vor den Spieler-Lautstärkereglern.

165 gezielte native Checks bestehen: Fenster/Platzierung/Akustik 127,
Wetter 14 und Start/Credits 24. Drei native Aufnahmen bei 1920 × 1080 zeigen
Innenansicht, Sehschlitz und Befestigung außen. Der Platzierungsbericht meldet
keine blockierten Türen, Bildüberschneidungen oder Möbeleinbettungen.
Der Edge/Playwright-Test bestätigt die Web-Meshes, die echte Fensterkollision,
Pause, Raumdämpfung und eine regulär geplante Donnerrolle ohne Konsolenfehler.
Windows- und Web-Pakete bestehen Dateilisten-, Hash-, Lizenz- und Startprüfung.
Der itch.io-Upload wurde lokal geprüft; es wurde nichts zu itch.io hochgeladen.
Private Aufnahme: --render-qa --v353-qa.

## Leiser Regen und entferntes Gewitter (3.5.2)

Eine dezente Dachregen-Schleife ergänzt die bestehende Regenquelle am Fenster.
Sie verwendet die vorhandene CC0-Aufnahme von Joseph SARDIN, neu geschnitten,
weich verdichtet und überblendet. Drei eigene, prozedural erzeugte Donnerrollen
setzen langsam ein. Der erste Donner folgt nach 24–42 Sekunden Spielzeit,
weitere Rollen nach zufälligen 65–110 Sekunden; zwei gleiche Varianten folgen
nicht direkt aufeinander. Die Zufallsquelle ist unabhängig von den Anomalien.

Der Wettermischer bleibt über Raumaufbauten hinweg erhalten. Raumabhängige
Pegel und Filter dämpfen den Regen in Kino, Archiv, Krabbelröhre und Fahrstuhl.
Pause und Menüs halten auch das Wetter an; der Atmosphären-Regler steuert es
über den Bus NightAmbience. Während Telefonat und Archivaufnahme ruht der Donner.
Die Wetterspur gehört zur normalen Atmosphäre.

178 gezielte native Checks bestehen (Wetter 13, Akustik 111, Start 24, Enden 30).
Die 14-sekündige Aufnahme des tatsächlichen Wetterbusses erreicht vor den
Spieler-Lautstärkereglern −40,77 dBFS RMS und −26,67 dBFS Spitze.
Windows- und Web-Pakete sind neu exportiert und geprüft.
Der Browser-Test bestätigt hörbereite Wiedergabe, eingefrorene Wetterzeit in
Pause, leiseren Regen im Kino und einen regulär geplanten Donner bei unverändert
normaler Runde. Keine Konsolenfehler.
Private Tonerzeugung: tools/prepare-after-play-weather-v352.py.
Private Prüfungen: --self-test --weather-only und --render-qa --weather-audio.

## Schilderdruck und Fahrstuhletagen (3.5.1)

Die metallischen Druckflächen wurden vom allgemeinen Metall-Patina-Durchlauf
ausgenommen. Dessen triplanare UV-Skalierung hatte insbesondere das Schild über
der Wartungstür mehrfach gekachelt. Alle gestalteten Schilder behalten jetzt
ihre eigenen UVs ohne Texturwiederholung; auch kleine Möbelschilder werden im
Platzierungstest erfasst. Rahmen erhalten weiterhin ihre Materialbehandlung.

Front- und Seitenanzeige des Startfahrstuhls sowie beide Flur-Fahrstühle zeigen
die aktuelle Rundennummer von 01 bis 13. Die Anzeige folgt dem gespeicherten
Fortschritt und beginnt nach Tod oder einer neuen Schicht wieder bei 01.
Auch der Ankunftstext nennt die aktuelle Etage.

273 gezielte native Checks bestehen: Schilder/Etagen 184, Start/Credits 24,
reale Flure und Tod 35, Enden 30. Neun native Aufnahmen bei 1920 × 1080 zeigen
unter anderem das korrigierte Wartungsschild und Etagen 01, 05 und 13.
Der Platzierungsbericht meldet keine Bildüberschneidungen oder blockierten Türen.
Windows- und Web-Pakete sind neu exportiert und bestehen die Paketprüfung.
Der Edge/Playwright-Test durchläuft Runde 1 bis 5, lädt einen in Runde 5
gespeicherten Stand und löst anschließend einen Tod aus. Alle vier sichtbaren
Etagenanzeigen stimmen mit dem Rundgang überein und springen danach auf 01;
es treten keine Konsolenfehler auf.

## Start, Credits, Stuhlkollisionen und Beschilderung (3.5.0)

Der erste Menüstart nutzt die bereits geladene Referenzwelt. Weitere Starts
bauen dieselben geordneten Konstruktionsschritte über mehrere Bilder auf, mit
sichtbarem Fortschritt. Während der Credits wird die leere Schlussansicht
vorbereitet; Überspringen schaltet auf die fertige Ansicht, statt die Welt im
Tastendruck neu aufzubauen. Geometrie ohne veränderliche Materialien wird bis
zu einer festen Cachegrenze über weitere Runden wiederverwendet.

Die importierten Partyraum-Stühle verwenden einen einfachen abgerundeten
Sitz-/Fußbereich und eine passende Rückenlehne statt eines detaillierten
Dreieckskollisionsnetzes. Die dargestellten Modelle behalten ihre Details.
Elf Geschenke besitzen Papiermuster, gefaltete Enden, Klebestellen, umlaufende
Bänder und weiche Schleifen. Die untere gestapelte Schachtel hat keine Schleife,
die durch die obere Schachtel ragen würde; die Bodenpakete sind auseinandergerückt.

40 eigene Druckmotive unterscheiden gealterte Öffnungszeiten-Plakate,
lackierte Wegweiser, Kinotafeln und technische Warnschilder. Sie verwenden die
vorhandenen OFL-Schriften und einen gemeinsamen Atlas; frühere braune
Druckflächen werden ersetzt. Gebogene Plakatkanten, Metallränder und
Befestigungen passen zur jeweiligen Ausführung. Die Fototafel ist an die
Ostwand im Personalgang zum Kino versetzt. Ein doppelseitiger Wegweiser hängt
an sichtbaren Halterungen von der Decke. Benachbarte Aushänge wurden versetzt.

Veraltete, bereits laufende Vorbereitungen werden bei einem neueren Weltaufbau
abgebrochen. Ein eigener Regressionstest wechselt während eines begonnenen
Credit-Aufbaus in eine neue Schicht und prüft, dass deren Szene erhalten bleibt.

Die vollständige native Spielprüfung besteht mit 2.379 Checks und null Fehlern.
Gezielte Prüfungen: 24 Start-/Credit-Checks und 108 Schilder-/Platzierungschecks
ohne Fehler. Im nativen Vulkan-Test bei 1920 × 1080 auf einer RTX 4080 betrug
die 95. Perzentile der Bildzeit ohne Stuhlkontakt 11,09 ms und am Stuhl
10,67 ms; die Physik blieb bei 2,97 bzw. 2,35 ms. Das sind Messwerte dieser
Testmaschine, keine Zusicherung für andere Hardware. Der erste Play-Aufruf
benötigte im Headless-Test rund 3 ms, der vorbereitete Credit-Wechsel 0,03 ms;
Anwendungsstart und Shader-Kompilierung sind darin nicht enthalten.

Edge/Playwright prüft den tatsächlichen ersten Menüstart, beide Skip-Vorgänge,
Rückkehr zum Hauptmenü, einen weiteren Start mit Fortschrittsanzeige sowie
beide Flure, Tod, dreizehn Rundgänge und das fortgesetzte Ende 1. Der vorbereitete
Skip erreichte im Software-WebGL-Test dieselbe Bildzeit-Perzentile wie davor
(20,1 ms). Kinolektüre, verschobene Fotowand, CCTV und physische Bälle wurden
ebenfalls geprüft. Mangels Browser-Plugin wird der vorhandene Playwright-Runner
verwendet. Windows- und Web-Archive bestehen Inhalts-, Lizenz-, CRC- und
Prüfsummenprüfungen; der exportierte Windows-Player startet ohne Ressourcenfehler.
Die fertige Website-Fassung wurde zusätzlich mit echten Maus-/Tastatureingaben
und als mobiler Download-Launcher ohne Konsolenfehler geprüft. Zehn aktuelle
native Aufnahmen und ein Platzierungsbericht zeigen keine blockierten Türen,
Bildüberschneidungen oder Möbel in Wänden. Öffentliche Pakete enthalten keine
neuen QA-Skripte oder Erstellerwerkzeuge. Der itch.io-Aufruf bleibt ein Dry-Run.

Private Werkzeuge: tools/prepare-after-play-signs-v350.py,
--self-test --startup-only, --signage-only und --render-qa --v350-qa.

## Materialien, Kinofassade und Lichtinseln (3.4.0)

Drei eigens geschriebene Bodenoberflächen unterscheiden abgetretenen
Kino-Musterteppich mit Randborte, lokal fettige Küchenfliesen und eine eingepasste
Gummifläche am Klettergerüst. Alle verwenden vorhandene Texturquellen und neue
prozedurale Abnutzung. Dünne Schwellen und Randprofile sind rein visuelle
Oberflächen ohne zusätzliche Stolperkollisionen. Die Schrittzuordnung folgt
auch der neuen Gummifläche; die physischen Grundböden behalten ihre Höhe.

Der Kinoeingang erhält zwei zurückgezogene Samtvorhänge und eine befestigte
Blende. Das bestehende Plakat wird zum beleuchteten, zurückgesetzten Programm-
kasten umgebaut; darunter steht eine schmale Kartenkontrolle mit Eintrittskarten
und Entwerter. Ein gemeinsamer Bühnenrahmen fasst Leinwand und genähte Vorhänge
ein. Doppelte Vorhanggeometrie entfällt, die Lautsprecher sind auf die Zuschauer
ausgerichtet und mit dem Rahmen verbunden. Sitzgänge, Projektorbedienung und
Zeitungsfund bleiben frei.

Das vorhandene Küchenmodell wird mit den gleichen Außenmaßen neu gebaut.
Seine alten Schrankgriffe werden tatsächlich entfernt, die Türfronten und
Arbeitsflächen erhalten getrennte Materialien. Fünf unterschiedliche Ersatz-
griffe, beschädigte Unterkanten, örtliche Feuchte, poliertes Metall und Fett an
der Haube ergänzen es. Der alte Küchenexport bleibt eine private Quelldatei
und wird nicht zusätzlich in die Spielerpakete gepackt.

Eine warme, gezielte Geburtstagsbeleuchtung, kaltes Projektorlicht und schwaches
Grün im Haupteingang ersetzen breite Lichtfüllung. Die neuen Leuchten beachten
Qualitätsstufen, rote Beleuchtung und die Dunkel-Anomalie des Partyraums.
Eingefasste Schaukästen und wandgebundene Stützen schaffen räumliche Tiefe.
Frühere zufällig verstreute Kinoreste werden durch kleine Ansammlungen unter
Sitzen und neben dem Abfall ersetzt. Diese Ausstattung ist normaler Raumzustand.

Private Werkzeuge: tools/model-after-play-kitchen-v340.py,
--self-test --craft-only und --render-qa --v340-qa.

Validiert mit 83 gezielten nativen Prüfungen, vier betroffenen Browserabläufen
(Böden und Übergänge, Kinozeitung samt Fortsetzen, Küchenbegegnung, Sitzgänge)
und dem normalen Web-Spielerstart mit echten Maus-/Tastatureingaben. Nach der
Korrektur der Kartenkontrolle wurden ihr Laufweg und der echte Start-Kollisions-
körper des Besuchers erneut geprüft. Desktop und mobile Download-Seite wurden
visuell kontrolliert; Browser plugin not available, daher Edge/Playwright.
Windows- und Webpakete bestehen Datei-, Hash-, Lizenz- und Datenschutzgrenzen;
die exportierte Windows-EXE startet ohne Ressourcen- oder Skriptfehler. Zehn
aktuelle Windows-Ansichten in 1920×1080 liegen unter build/v340-views.
Die vollständige native Suite besteht 2.179 Prüfungen ohne Fehler, einschließlich
aller Begegnungs-Startkollisionen, Sichtlinien, Rundenwechsel und Endabläufe.

## Haupteingang, Garderobe und Verbindungsgang (3.3.0)

Der ehemalige Lieferflur ist jetzt der alte Haupteingang. Ein offener Bogen
verbindet ihn mit dem Hauptsaal; die echte Glastür liegt am anderen Ende.
Garderobe und Kinderwagen wurden hierher versetzt, mit Sitzbank, Schuhablage,
nummerierten Haken, Schirmständer und Fußmatte. Die Tür lässt sich mit E öffnen.
Erst wer durch sie auf den verbundenen Parkplatz tritt, erreicht das zusätzliche
„Geheime Ende“: Schwarzblende, eigens synthetisierte Autofahrt und der gewünschte
Kündigungssatz. Anschließend laufen die Credits mit Spieluhr; Fortsetzen stellt
dieses Ende wieder her. ENDE 1/2 und ENDE 2/2 bleiben erhalten. 0712 bleibt gültig.

Der Verbindungsgang zu Küche und Kino erhält durchgehende Vertäfelung,
Sockelleisten, befestigte Deckenleuchten, Heizkörper mit Leitungen, Wegweiser,
einen Aushangkasten und eine Lüftungsrevision. Die Laufmitte und beide
Raumöffnungen bleiben frei. Plastische Putzoberflächen ergänzen den bestehenden
Licht- und Materialausbau. Browser und Windows behalten ihre Qualitätsstufen.

Die beiden Vorratsregale stehen an der freien Nordwand. Sie durchschneiden
keine Slush-Maschinen mehr. An der Kinosteuerung ersetzt ein flaches Metallschild
den überlagerten Holzrahmen; das dort unpassend montierte Akustikpaneel entfällt.
Der Möbeltest prüft nun auch die Volumina dieser tatsächlich getrennten Objekte
gegeneinander; ein absichtlich nachgestellter Überlappungsfehler muss anschlagen.

Private Werkzeuge: tools/prepare-after-play-v330-audio.py,
--self-test --arrival-only, --render-qa --v330-qa.

Validierung 3.3.0: Der vollständige native Spieltest besteht 2.096 Prüfungen
ohne Fehler, einschließlich aller Anomalien, beider nummerierter Enden und des
zusätzlichen geheimen Ausgangs. Der Balancetest simuliert 2.048 Schichten.
22 gezielte native Prüfungen für Eingang, Glastür,
Speicherpositionen und das dritte Ende bestehen. Die 111 Grafik-/Akustikprüfungen
und 55 bisherigen Bühnen-/Eingangsprüfungen bestehen ebenfalls. Vier echte
Browser-Abläufe prüfen den geheimen Ausgang mit Credits/Fortsetzen, den gesamten
Verbindungsgang samt beiden Raumöffnungen, die angepasste Eingangs-Anomalie und
die Migration einer alten Speicherposition aus der Garderobenbank. Alle bestehen
ohne Konsolenfehler. Die öffentliche Web-Fassung wird zusätzlich mit echten
Maus-/Tastatureingaben und auf einer mobilen Startseite geprüft (Edge/Playwright;
Browser-Plugin nicht verfügbar). Elf native 1920×1080-Aufnahmen bestätigen die
Platzierungen; die Geometrieprüfung meldet keine versperrten Wege, überlagerten
Wandbilder oder erkannten Möbelüberschneidungen. Windows- und Web-Paket bestehen
Dateiliste, CRC, Prüfsummen, Lizenzen und die Privatheitsgrenze. Die exportierte
Windows-EXE startet ohne fehlende Ressourcen oder Skriptfehler. Beide itch-Kanäle
bestehen den lokalen Probelauf; ein itch-Upload wurde nicht ausgeführt.

## Räumlicher Klang und Oberflächen (3.2.0)

Das Westfenster besitzt eine echte Öffnung in der Architektur, drei geschlossene
Scheiben mit Dichtungen und Griffen, Schmutz- und Regenfilme und einen vollständig
modellierten leeren Parkplatz. Markierungen, Ablaufrinne, Poller, Laternen,
HAPPYLAND-Reklame und Regen befinden sich außerhalb des Gebäudes. Die beiden
vormals davor stehenden Regale stehen jetzt neben den Preisautomaten; Fortsetzen
prüft ihre neuen Kollisionsvolumen. Der Parkplatz liegt zwischen den bestehenden
Gebäudeflügeln und überlagert weder Wartungsraum noch Lieferflur.

Abgerundete prozedurale Geometrie erhält jetzt echte Tangenten für Normal Maps.
515 vorhandene Oberflächen werden in ihren vorhandenen Materialidentitäten
verfeinert; Anomaliefarben und die korrigierte Gesichtsgeometrie bleiben erhalten.
Bodenmaterialien unterscheiden zwischen trockener Abnutzung, Feuchte und Teppich.
Konvexe CRTs mit Glas, echte Polsternähte, befestigte Akustikdecken, Sprinkler,
ein geschützter Küchenlüfter, Leuchten unter der Haube und weitere Einbaudetails
ergänzen das gesamte Haus. Windows erhält zusätzliche Raumreflexionen, abgestimmte
Kontaktverschattung, Lichtfarben und einen optischen Taschenlampenlichtkegel.
Qualitätsstufen und die vereinfachte Browserbeleuchtung bleiben verfügbar.

35 räumliche Quellen erhalten getrennte Tiefpass- und Pegelsteuerung. Echte
Wand- und Türgeometrie verdeckt Klang; freie Wege durch die Raumöffnungen lassen
ihn um Ecken dringen. Hall und Schrittresonanz folgen dem Raum, mit einem kurzen
zusätzlichen Echo in den Kunststoffröhren. Die Menü-Raumkulisse läuft nicht mehr
als globale Geräuschschicht über dem Spiel. Neue Maschinenaufnahmen für drei
Automaten, Kühlschrank, Projektor, Lüftung, Transformator und Röhren bestehen aus
eigenständig erzeugten periodischen Signalen. Regen liegt leise hinter dem Glas;
vorhandene normale Schritte und Kinderstimmen bleiben normale Atmosphäre.

Private Werkzeuge: tools/prepare-after-play-v320-audio.py,
--self-test --upgrade-only, --render-qa --v320-qa und --render-qa --v320-audio.
Die Audio-Nachprüfung zeichnet den echten gefilterten Submix vor dem stummen
Master auf. Bei derselben Quelle hinter der Liefertür wurden geschlossen
−47,14 dBFS und geöffnet −30,19 dBFS gemessen; der relative Anteil über 2 kHz
steigt beim Öffnen um mehr als den Faktor 80. Die Tests benötigen keine
Ausgabe von Testtönen über die Lautsprecher.

Validierung 3.2.0: Der vollständige native Spieltest besteht 2.081 Prüfungen
ohne Fehler, einschließlich aller Anomalien, Rundenbalance, beider Enden und
der 111 neuen Grafik-/Akustikprüfungen. Zehn echte Windows-Spielaufnahmen
zeigen die finale Szene ohne Skript- oder Shaderfehler. Die Spielerpakete
bestehen Dateiliste, CRC, Prüfsummen, Lizenz- und Privatheitsgrenze; die
gepackte Windows-EXE startet ohne fehlende Ressourcen. Beide itch-Kanäle
bestehen den lokalen Probelauf ohne Upload. Die neue Browser-Prüfung für
Fensterkollision, Raumfilter, Röhrenhall und Pause besteht ebenfalls.
Neun weitere echte Browser-Abläufe bestehen einschließlich beider Enden,
0712-Zugang, Zeitungsinventar, Speichern, Physik der Kino-Gänge, Röhrentraversierung,
Küchenclown und Automaten. Die Langtests erlauben die gemessene erste
Materialkompilierung und mehrere vollständige Seitenneuladungen; ihre
Bewegungs-, Kollisions-, Audio- und Speicherprüfungen bleiben vollständig.

## Sitz der Clownaugen und Zähne (3.1.1)

Die Augen liegen wieder in den gescannten Lidern statt oberhalb davon.
Augäpfel, Iris und Pupillen besitzen eine gemeinsame, zurückgesetzte Oberfläche.
Die kleineren Zahnkronen folgen einem Zahnbogen hinter den Lippen; die untere
Reihe wird größtenteils von der Unterlippe verdeckt. Individuelle Formen und
gealterte Schmelzfarben ersetzen die zwei gleichmäßigen, vorstehenden Reihen.

UV-Nähte des Scans werden vor dem Modellieren verschweißt. Augen- und Mundpartien
werden direkt im dichten Netz geöffnet und ihre Ränder geglättet. Drei geometrische
Strahlprüfungen stellen beim Erstellen sicher, dass die Öffnungen wirklich frei
sind. Front-, Seiten- und Spielansichten dienen der visuellen Prüfung.
Windows und Web verwenden dasselbe korrigierte Modell und die bisherigen Texturen.

Validierung 3.1.1: 120 gezielte native Prüfungen ohne Fehler. Der reale
Browser-Ablauf für Küche, Kino, Fortsetzen, Pause und den einmaligen Clownangriff
besteht. Die drei nativen Spielansichten zeigen das finale Modell. Windows- und
Webpaket bestehen Datei-, Lizenz- und Prüfsummenprüfung; die gepackte Windows-EXE
startet ohne Skriptfehler oder fehlende Ressourcen. Beide itch-Kanäle bestehen
den lokalen Probelauf ohne Upload.

## Clown, Kino und Spiellounge (3.1.0)

Der Kopf des Küchenclowns wird aus dem attribuierten Gesichts-Scan neu aufgebaut.
Die bisherige grobe Vertex-Bemalung wurde durch eine fotografisch wirkende Haut-
und Schminktextur ersetzt. Die UV-Ausrichtung ist korrigiert; echte Öffnungen,
zurückgesetzte dunkle Augen, einzelne kleinere Zähne und spärliche Haarsträhnen
gehören zum Modell. Verschiedene Blutreste wirken über Farbe, Glanz und Rauheit.
Die Schürze zeigt gealtertes Leinen statt des großen roten Karomusters.
Das gemeinsame Modell und seine Texturen werden auch im Browser verwendet.

Im Kino sitzen 48 Getränkehalter an den Armlehnen, mit zurückgelassenen Bechern,
Sitznummern und Taschen auf den Rückenlehnen. Hinzu kommen eine gerahmte Erinnerung
an die letzte Vorstellung, Lautsprechergitter, gefasste niedrige Leuchten,
Filmdosen, Projektoroptik und Bedienelemente, ein Abfalleimer sowie örtliche
Ansammlungen von Eintrittskarten, Verpackungen und Popcorn. Laufkorridor und
Zeitung werden durch diese Teile nicht belegt.

Die Automaten stehen in einem zusammenhängenden Bereich außerhalb der
Krabbelröhre, mit Jetonwechsler, Bodenbelag, befestigtem Baldachin und alter
Beschriftung. Der Saal erhält Deckenlüftung mit Aufhängungen, eine alte Messlatte,
vergessene Taschen und kleine Bodenreste. Die frühere Reihe einfacher Pfosten
entfällt. Der Baustrahler besitzt jetzt einen Standfuß, Gehäuse und Schutzgitter.
Der Feuerlöscher erhält Halterung, Ventil, Griffe, Druckanzeige, Schlauch und Etikett.

Das Krokodil wird auf 72 Prozent verkleinert und auf z=11,6 versetzt. Die tatsächliche
sichtbare Ausdehnung liegt nun bei x=8,764–16,972 und z=9,303–13,897. Das Gerüst endet
vor diesem Bereich; der Weg zum Fotoautomaten bleibt frei. Schlauch, Gebläse und
Geräuschquelle folgen demselben Attraktionsknoten und dem tatsächlich modellierten
Einlass. Die Sprungfläche bleibt funktionsfähig. Alte Speicherpositionen werden
auch gegen den neuen Jetonwechsler geprüft.

120 gezielte Prüfungen kontrollieren Ausstattung, Geometriegrenzen, sichtbare
Kollisionen, Gesichtsmaterialien und Durchgänge. Die normale Atmosphäre bleibt
in jeder Runde identisch und ändert die Anomalieentscheidung nicht.
Die Textur wurde mit dem eingebauten image_gen-Werkzeug erstellt:
assets/detail-v310/clown-skin-albedo.png. Der genaue verwendete Prompt und die
Quelle der Normal Map stehen privat in assets/detail-v310/provenance.json.
Die bestehende Lee-Perry-Smith-Attribution bleibt im Spielerpaket erhalten.

Validierung 3.1.0: Der vollständige Durchlauf mit 1.962 Prüfungen fand eine
Messlatte im Schwenkbereich der geöffneten Liefertür. Nach dem Versetzen bestehen
237 gezielte native Prüfungen ohne Fehler, einschließlich geöffneter Türen,
Kollisionen, Kinogeräten und beider Enden. Sieben Browser-Abläufe bestanden vor
dieser letzten Wandkorrektur; danach wurden Bühnenzugang, Automatenbereich und
der falsche Ausgang erneut erfolgreich geprüft. Eine zu kurze Wartefrist im
Browser-Test wurde an die bereits verwendete Fahrstuhlfrist angepasst.
Echte Forward+-Spielaufnahmen wurden visuell geprüft. Die Windows- und
Browserpakete bestehen Datei-, Prüfsummen- und Lizenzkontrollen; die gepackte
Windows-EXE startet ohne fehlende Ressourcen oder Skriptfehler.

## Klang, Materialien und räumlicher Ausbau (3.0.0)

Die Schreckeffekte stammen jetzt aus zehn eigenständigen Kreaturenaufnahmen
von Ogrebane (CC0), ergänzt durch die bereits lizenzierten Feldaufnahmen.
Daraus entstanden drei unterschiedliche Schnitte pro Klangfamilie und zehn
kurze Vorzeichen. Die 30 Attacken sind keine Kopien desselben Koch-Schreis.
ScareBank verhindert direkte Wiederholung einer Variante; die Auswahl besitzt
einen eigenen Zufallsgenerator und beeinflusst weder Anomalien noch Spielstände.
Besucher, Hase, Krokodil, Clown, Kostüm und der falsche Ausgang verwenden diese
Bibliothek. Der eigene Koch-Schrei des Archivfinales bleibt erhalten.

Vorzeichen liegen räumlich an der Erscheinung und pausieren mit dem Spiel.
Der Küchenclown unterbricht sein Rühren bei Annäherung und bewegt vor dem
Angriff den Kopf. Andere Besucher reagieren mit einer begrenzten Kopfdrehung.
Drei artikulierte Besucherformen (zerfetzt, verhüllt, verzerrt) ersetzen die
einheitliche Gestalt an den verschiedenen Begegnungsarten. Die Figuren behalten
dunkle Augenhöhlen; Stoff wird nicht mehr mit einer Putztextur überzogen.

Windows verwendet überarbeitete Clown-, Hasen- und Schachtmodelle. Der große
Stoffhase bleibt das genähte Spielzeug im Partyraum, mit millimeterkurzem,
gerichtetem Flor statt langer Nadeln. Der Clown erhält gewebte Kleidung und
Blut im tatsächlichen Stoffmaterial. Der Topfinhalt besitzt eine durchgehende
unregelmäßige Oberfläche statt flacher kreisförmiger Schimmelplättchen.

Die Küche erhält fotografische 2K-Fliesen, Lack mit unregelmäßiger Verschmutzung,
echte Metalloberflächen, eine feste Vorbereitungsstation, Halterungen,
Abzugsfilter, Gefäße und einen gescannten Vorratsschrank von Poly Haven.
Gebäudesockel, befestigte Deckenbalken, Leuchtenaufhängungen, Bühnenvorhänge und
gefasste Kinoabsorber geben auch den übrigen Bereichen mehr räumliche Details.
Das Krokodil steht 1,3 m weiter vom Fotoautomaten entfernt.

In Forward+ ersetzt aufeinander abgestimmter volumetrischer Nebel die bisherige
doppelte Überlagerung dichter linearer und volumetrischer Schichten. Der Nebel
bleibt immer vorhanden; nahe Oberflächen werden nicht zusätzlich ausgewaschen.
Die rote Nebelanomalie färbt beide Nebelarten sichtbar. Web behält einfachere
Materialien, vorhandene Hero-Geometrie und dichten linearen Nebel; die neuen
Sounds und Besucherformen bleiben auch dort enthalten.

Neue Einbauten besitzen passende feste Körper. Fortsetzen prüft deren Volumen,
damit ältere Speicherpositionen nicht mitten in einer neuen Arbeitsplatte liegen.
Die handschriftliche Hilfe, 6:7-Rundenverteilung, vier geschützten Zeitungsrunden,
0712-Zugang und beide nummerierten Abschlüsse bleiben erhalten.

Private Werkzeuge: tools/prepare-after-play-v300.py,
tools/model-after-play-v300.py, --self-test --revamp-only und
--render-qa --v300-qa --capture-dir=<Ordner>.
Quellen, Originalhashes und Klangmessungen: assets/revamp-v300/provenance.json.

Validierung 3.0.0: 1.799 native Prüfungen ohne Fehler und ohne Skriptfehler;
sechs reale Browser-Abläufe bestanden (Klangwechsel, Küchenstation, Kino-Zeitung,
13 Rundgänge samt Tod und Ende 1, Clown, Archiv-Ende und Menüs). Die native
Forward+-Fassung wurde mit echten Spielaufnahmen visuell geprüft. Beide
Spielerpakete bestehen Datei-, Prüfsummen- und Lizenzprüfung; beide itch-Kanäle
bestehen den lokalen Butler-Probelauf. Die gepackte Windows-EXE wird zusätzlich
versteckt gestartet und auf fehlende Ressourcen geprüft. Godots Import teilt eine
unveränderte Felltextur mit dem bisherigen Hasenordner; diese benötigten Texturen
bleiben deshalb im Windows-Paket, die alte Hasengeometrie wird ausgeschlossen.
Kein itch.io-Upload wurde gestartet.

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
`build/after-play-windows-v3.1.0.zip`. `-WithQA` erzeugt zusätzlich eine separate
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
