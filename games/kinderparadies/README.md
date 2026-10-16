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
Die erste Runde ist normal und dient als Referenz. Alle vier Kontrollbereiche
besuchen. Keine Anomalie: grüne Tür. Anomalie: rote Tür. 13 richtige Entscheidungen
in Folge gewinnen; ein Fehler setzt die Serie zurück und erklärt die Veränderung.
36 Anomalien, ohne Wiederholung innerhalb des Anomalie-Beutels. Normale und
veränderte Runden werden unabhängig vom gewählten Türtyp gemischt.

Helligkeit, Lautstärke, Empfindlichkeit, Grafikqualität und Kamerabewegung sind
einstellbar. Spielstand wird pro Runde, bei Pause und alle zehn aktiven Sekunden
lokal gespeichert. Web verwendet den lokalen Browser-Speicher, Windows Godots
Benutzerdatenverzeichnis. Kein Online-Ranking oder Chickens-Buchungen.

Ziel: Desktop mit Maus/Tastatur. Windows x86_64 mit OpenGL 3.3, Web-Version mit
WebGL 2.0. Keine Touch- oder Controllersteuerung in dieser Fassung. Qualität
„Leistung“ deaktiviert dynamische Schatten und MSAA. Kein Installationsprogramm,
keine Autostarts und keine Administratorrechte erforderlich.

## Bauen und prüfen

Im Repository `./tools/build-kinderparadies.ps1` ausführen. Das Skript lädt bei
Bedarf die offizielle portable Godot-Version und verifiziert deren SHA512.
`prepare-kinderparadies-templates.py` lädt per HTTP-Range ausschließlich die
Windows- und Web-Templates aus dem offiziellen Archiv; ZIP-CRCs werden geprüft.

Ergebnisse: `build/windows/Nachtwache.exe`, `build/web/`,
`build/nachtwache-windows-v1.1.0.zip`. `-WithQA` erzeugt zusätzlich eine separate
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
`drips.wav`: eigene Wasser-/Rohrgeräusche, reproduzierbar mit
`tools/generate-nachtwache-drips.py`. Keine Hintergrundmusik.
Godot MIT-Lizenz und Drittanbieterhinweise liegen dem Windows-ZIP bei.

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
