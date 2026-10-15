# NULLSIGNAL

Originales kooperatives 3D-Spiel für genau zwei Personen. Der Streamer startet
unter `/#games/nullsignal` eine Lobby. Der Gast öffnet den Einladungslink,
gibt einen Namen ein und bekommt ausschließlich das Handbuch, ohne Aviary-Konto.
Für die Kommunikation wird der vorhandene Sprachchat verwendet; das Spiel
fordert kein Mikrofon an und überträgt keine Sprachaufnahmen.

## Spielen

1. Als Streamer anmelden, Mission auswählen und Lobby erstellen.
2. Einladungslink kopieren und an den Spielpartner senden.
3. Der Gast blendet den Stream aus, öffnet das Handbuch und meldet sich bereit.
4. Der Streamer startet. Module zum Fokussieren anklicken; Ziehen dreht das Gerät.
   Die zusätzliche Modulbedienung unterstützt Tastatur, Touch und Farbnamen.
5. Drei Fehler oder abgelaufene Zeit beenden die Mission. Jeder Fehler kostet
   außerdem acht Sekunden. Eine neue Runde erzeugt neue Daten und Handbuchregeln.

Erstkontakt: 3 Module, 3 Minuten. Störfall: 6 Module, 5 Minuten. Blackout:
8 Module auf Vorder- und Rückseite, 6 Minuten. Alle acht Modularten haben eigene
Regeln und Interaktionen: Kabel, Glyphen, Frequenzen, dreistufige Tastenfolge,
Relais, gespiegelte Regler, drehbare Rohrverbindungen und ein Rechenschloss.
Das Glyphenfeld im Expertenhandbuch zeigt ausschließlich die Symbole ohne
sichtbare Namen; die Spalten A–D bleiben zur Orientierung erhalten.

Beim Frequenzkern lässt sich die Folge ausschließlich an der blinkenden LED
beobachten: fünf kurze/lange Lichtimpulse, danach eine lange Pause. Weder die
Bombe noch die zusätzliche Modulbedienung zeigen den fertigen Punkt-Strich-Code.
Nur das Expertenhandbuch enthält die Tabelle zum Zuordnen der beschriebenen Folge.

Erfolgreiche Missionen vergeben bis zu 6 / 12 / 18 Chickens an das Host-Konto,
ab 15 Sekunden tatsächlicher aktiver Spielzeit. Das vorhandene Tageslimit von
120 gilt gemeinsam mit den anderen Spielen. Teamrekorde werden pro Mission
gespeichert und über die vorhandene Highscore-Browserquelle angekündigt.

## Sitzungen und Autorität

- FastAPI prüft alle Aktionen und den Server-Zeitpunkt. Es gibt keinen frei
  beschreibbaren Score- oder Belohnungs-Endpunkt für dieses Spiel.
- SQLite im bestehenden persistenten Backend-Volume; nur zusätzliche
  `nullsignal_*`-Tabellen. Auszahlungen und Rekordmeldungen passieren atomar
  mit den vorhandenen Wallets, Runs und dem Alert-Ausgang.
- Host-Routen verlangen das bestehende JWT und den korrekten Raum-Eigentümer;
  bestehende Sperren und Session-Widerrufe gelten weiterhin.
- Eine unerratbare Einladung belegt genau einen Expertenplatz. Der Browser
  speichert vor dem Beitritt einen zufälligen Zugangsschlüssel in sessionStorage.
  Wiederholungen nach einer verlorenen Antwort belegen keinen weiteren Platz.
  Der Schlüssel wird nur als Header gesendet; die Einladung steht im URL-Hash.
- Host-Projektion enthält sichtbare Bombendaten, aber weder Antworten noch
  Handbuchregeln. Experten-Projektion enthält Regeln, aber keine Bombenanordnung,
  Seriennummer, Host-Wallet oder Einladung. Beide Antworten sind `no-store`.
- Lobby-Erstellung und Aktionen sind gegen doppelte Anfragen abgesichert. Alte
  Aktionen passen nach einer neuen Runde nicht mehr zur Runden-ID.
- Zwei HTTP-Abfragen im 750-ms-Takt halten die Rollen synchron. Fehlende
  Verbindung pausiert nach 15 Sekunden exakt am Ablauf dieser Frist; Pausen
  erzeugen keine zusätzliche Spielzeit. Nur der Host kann fortsetzen, wenn der
  Experte wieder verbunden und bereit ist.
- Eine Einladung gilt zwei Stunden. Der Host kann Gast und Link ersetzen,
  die Lobby schließen oder eine neue Runde mit demselben Partner vorbereiten.

## Grafik, Assets und Audio

Three.js mit echter Geometrie, gebogenen Kabeln, Raycasting, Objektrotation und Zoomkamera,
physikalischen Materialien, eigener Werkbank, Schatten, Materialtextur,
kontrolliertem Bloom und korrektem Output-Pass. Der Gast lädt die 3D-Bibliothek
nicht. Die Szene begrenzt die Pixeldichte; statische Schatten werden erst bei
einer Geometrieänderung neu berechnet. Reduced Motion entfernt Kameraschütteln,
Partikel und animierte Kamerafahrten.

Ziehen dreht ausschließlich das Gehäuse, auch in der Lobby. Die Kamera behält
ihre Blickrichtung, Werkstatt und Tisch bleiben beim Drehen fest. Mausrad und
Zwei-Finger-Geste zoomen; Vorder-/Rückseite drehen das Gerät entsprechend.
Modulfokus richtet die passende Gehäuseseite aus und vergrößert sie, ohne den
Tisch zu kippen. Ziehen verlässt den Modulfokus. Eine Höhenkorrektur verhindert,
dass das geneigte Gehäuse durch die Tischplatte ragt. Schatten werden bei diesen
Bewegungen aktualisiert, nach Stillstand wieder nur bei Zustandsänderungen.

Werkstatt und Metalltextur sind eigene Image-Gen-Assets in
`frontend/public/assets/nullsignal/`. Prompts und Gestaltungsspezifikation liegen
unter `frontend/design/nullsignal-*`. Rätseltexte und Vektorglyphen wurden eigens
geschrieben. Die Effekte verwenden vorhandene unveränderte Kenney-CC0-Aufnahmen;
Lizenzen stehen in `frontend/public/audio/`. Eigene Musik ist optional, siehe unten.

## Countdown und eigene Musik

### Zeitdruck und Beruhigungspillen

Mit sinkender Restzeit wird der rote Bildschirmrand stärker und pulsiert schneller.
Die Bombenansicht wird in den letzten zwei Minuten zunehmend leicht unscharf;
Timer, Handbuch und Bedienknöpfe bleiben scharf. Der Rand blockiert keine Klicks.
Bei Pause, Ergebnis oder Verlassen verschwinden die Effekte. Bei aktivierter
Systemeinstellung „Bewegung reduzieren“ bleibt die Warnung statisch.

Der Entschärfer hat zwei Beruhigungspillen pro Runde. `C` oder der gleichnamige
Button entfernt die Unschärfe für 30 Sekunden aktiver Spielzeit. Der rote Rand
warnt weiter. Während der Wirkung lässt sich keine weitere Pille verbrauchen.
Pausen halten die Wirkzeit an, danach kehrt die Unschärfe weich zurück.
Neuladen füllt den Vorrat nicht auf; erst eine neue Runde gibt wieder zwei Pillen.
Tastendrücke in Eingabefeldern, mit Strg/Alt/Meta oder gehaltene Wiederholungen
verbrauchen nichts. Der Gast sieht weiter ausschließlich das scharfe Handbuch.

Der bestehende SQLite-Raumzustand speichert Verbrauch und Wirkzeit. Die neue
Host-Route `/api/nullsignal/rooms/{id}/calm` prüft Eigentümer, Runden-ID,
Spielstatus und eine idempotente Anfrage-ID. Bestehende Räume erhalten die
Standardwerte ohne Datenbankmigration; Kontostände und Rätsel bleiben erhalten.

### Piepton und Musikdateien

Der Countdown piept ab Missionsbeginn einmal pro Sekunde. Ab 60 Sekunden gilt
ein halber Sekundenabstand; ab 30 Sekunden sinkt der Abstand von 0,32 Sekunden
kontinuierlich bis 0,08 Sekunden. Jeder Fehler multipliziert den Abstand zusätzlich
mit 0,7, unabhängig von der Restzeit. Der Mindestabstand beträgt 0,05 Sekunden.
Pausieren, Entschärfen, Stummschalten und Verlassen stoppen den Countdown-Ton;
bei null beendet der Server die Runde und löst den vorhandenen Explosionssound
und den 3D-Effekt aus. Es werden keine verpassten Pieptöne nachgeholt.
Der eigene kurze WAV-Piepton lässt sich mit
`node frontend/scripts/generate-nullsignal-beep.mjs` reproduzieren.

In `frontend/public/music/nullsignal/` genau diese optionalen Dateien ablegen:

- `menu.mp3`: Nullsignal-Hauptmenü und Lobby.
- `ingame.mp3`: laufende Mission.

Beide Titel laufen in Schleife. Beim Start wechselt die Musik automatisch;
bei Pause und Ergebnis stoppt sie. Es spielt immer nur ein Titel. Der Gast
erhält keine Musik. Im Audio-Menü sind Effekte/Countdown und Musik getrennt
regelbar; die Einstellungen bleiben im Browser gespeichert. Der Lautsprecher
schaltet alles stumm. Beim ersten Besuch braucht der Browser einen Klick oder
Tastendruck, bevor er Ton abspielen darf; dafür gibt es „Ton einschalten“.
Fehlende MP3s bleiben still und beeinträchtigen die Spielsounds nicht.

Auf Hetzner ist der Ordner
`/opt/twitch-interaktion/frontend/public/music/nullsignal/` direkt in Nginx
eingebunden. Dort genügt das Ablegen oder Ersetzen der MP3s; kein Build und kein
Neustart sind erforderlich. Anschließend die Spielseite neu laden. Nginx liefert
fehlende optionale Titel als 204 ohne SPA-Fallback und vorhandene Dateien mit
MP3-MIME-Type, Range-Unterstützung und Revalidierung statt Langzeitcache aus.
Die Songs sind in Git ignoriert und bleiben bei Deployments erhalten.

Vom Windows-PC am einfachsten: Dateien in den sichtbaren Projektordner
`NULLSIGNAL MUSIK/` legen und dort `MUSIK HOCHLADEN.cmd` doppelklicken.
Alternativ Dateien in den bisherigen lokalen Ordner legen und
`deploy/upload-nullsignal-music.cmd` doppelklicken (oder das gleichnamige `.ps1`
ausführen). Der vorhandene Hetzner-SSH-Schlüssel wird verwendet. Jeder vorhandene
Song wird erst vollständig hochgeladen und danach atomar freigegeben, sodass ein
abgebrochener Upload keinen bestehenden Song ersetzt. Die Songs werden weder
in Git eingecheckt noch für Tests in die Live-Seite kopiert.

## Notstrom und Stress

Während einer Runde fällt die Werkstattbeleuchtung erstmals nach 40–50 aktiven
Sekunden für zwölf Sekunden aus, danach mit 75 Sekunden Abstand. Die
Taschenlampe geht standardmäßig mit in die Runde; Maus oder Finger richten den
echten 3D-Lichtkegel aus. **F** oder der Schalter oben links schaltet sie um.
Die LEDs und der Countdown bleiben sichtbar. Das Handbuch bleibt unbeeinflusst.

Ohne Beruhigung entstehen bei weniger als zwei Minuten Restzeit und mehr als
50 aktiven Sekunden ohne Pillenwirkung allmählich Bildstörungen. Bei höchstens
50 Sekunden Restzeit und mindestens 85
aktiven Sekunden ohne Beruhigung erscheint einmal pro Runde eine eigene
verzerrte Gestalt für 1,2 Sekunden mit einem kurzen Sample-Stinger. Rätselwerte,
Fehlerzahl und Antworten werden dadurch nicht verändert.

**C** nimmt weiterhin eine der zwei Pillen: 30 aktive Sekunden klare Sicht,
keine Halluzinationen und anschließend ein neu beginnender Stressaufbau.
Pausen frieren alle Zeitpläne ein; der Server speichert den einmaligen Schreck
auch über Neuladen hinweg. Die Expertenprojektion enthält keine Stressdaten.
Unter den Einstellungen können Halluzinationen und Jumpscare gemeinsam
ausgeschaltet werden; die Wahl bleibt lokal gespeichert. Bei reduzierter
Bewegung entfallen Zoom, Figuren-Close-up und dekorative Animationen.
Ausfall, Erscheinung und Schreck verwenden endliche vorhandene CC0-Samples;
Musik und Countdown folgen weiterhin ihren bisherigen Einstellungen.

### Die Gestalt in der Werkstatt

Mit **R** oder **Raum ansehen** wechselt der Entschärfer in eine weitere
Werkstattansicht. Erneutes Drücken führt zur Bombe zurück; auch ein Modul-Klick
fokussiert wieder das Rätsel. Auf Touch-Geräten führt ein Finger in der
Raumansicht die Taschenlampe. **F** bzw. der Lampenschalter funktioniert jetzt
auch bei eingeschalteter Werkstattbeleuchtung.

Die erste Raumerscheinung kann nach 58–68 aktiven Sekunden auftreten, wenn
mindestens 35 Sekunden ohne Beruhigung vergangen sind. Alle 32 Sekunden gibt
es ein zwölf Sekunden langes Sichtungsfenster, mit ruhigen Pausen dazwischen.
Die Gestalt steht zunächst weiter hinten links, bei der nächsten Sichtung
rechts näher und später direkt hinter dem Tisch. Sie ist ein eigener
Ganzkörper-Billboard im 3D-Raum, mit perspektivischer Größe und Verdeckung
durch das echte Gehäuse und den Tisch, kein Bildschirm-Overlay.

Etwa eine halbe Sekunde gezieltes Anleuchten lässt sie auflösen. Nur sichtbare
feste Geometrie blockiert den Lichtweg; unsichtbare Klickflächen und
Auswahlkonturen tun das nicht. Vertriebene Sichtungen bleiben in derselben
Browsersitzung auch nach einem Neuladen weg. Neue Runden haben einen eigenen
Zeitplan. Pillen, Pause und ausgeschaltete Schreckeffekte entfernen die
Raumgestalt ebenfalls. Während des Jumpscares erscheint keine zusätzliche
Raumgestalt. Der Experte bekommt weiter nur sein Handbuch.

## Prüfung

Backend: `python -m unittest discover -s tests` im Backend-Container. Die
Nullsignal-Tests prüfen unter anderem alle acht Module über 100 Seeds anhand
der getrennten sichtbaren Daten und Handbuchregeln, Rollen, gleichzeitigen
Beitritt, Wiederholungen, Auszahlungen, Rekorde, Pausen und Wiederherstellung.

Browser: `NULLSIGNAL_TEST_API=http://127.0.0.1:4187 npx playwright test nullsignal.spec.mjs`
im Frontend, nach `npm run build`. Der Test-Endpunkt muss auf einen isolierten,
nur über Loopback erreichbaren Backend-Container mit Test-Identität zeigen.
Die Suite verweigert externe Test-Endpunkte und wird ohne diese explizite
Konfiguration übersprungen. Sie testet zwei echte Browser mit echten
Backend-Räumen, echte 3D-Klicks auf alle Modultypen, Touch und Wiederverbinden.
Der Test-Auth-Adapter wird ausschließlich außerhalb des Repositories in den
wegwerfbaren Test-Container eingebunden; er ist kein Teil des Produkt-Images.
Die reproduzierbare Vorlage liegt in `backend/tests/nullsignal_qa_server.py`;
der Produkt-Dockerfile kopiert ausschließlich `app/`, niemals `tests/`.

Beispiel für einen eigenen isolierten Test-Container (Linux / Docker):

```sh
docker build -t aviary-backend:nullsignal-qa backend
docker run --rm --name nullsignal-qa -p 127.0.0.1:4187:8000 \
  -e NULLSIGNAL_QA_ONLY=loopback-disposable \
  -e AVIARY_ECONOMY_DB=/tmp/nullsignal-qa.sqlite3 \
  -e PYTHONPATH=/app/tests:/app \
  -v "$PWD/backend/tests:/app/tests:ro" \
  aviary-backend:nullsignal-qa uvicorn nullsignal_qa_server:app --host 0.0.0.0 --port 8000
```

Der Adapter verweigert den Start ohne die explizite Test-Kennung. Keine
Produktions-Volumes, Zugangsdaten oder öffentlichen Ports an diesen Container
binden. Für die lokale Frontend-Suite zeigt `NULLSIGNAL_TEST_API` auf Port 4187;
die bestehende Playwright-Konfiguration startet den Frontend-Preview auf 4186.
