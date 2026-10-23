# After Play 2.5 — Gestaltungs- und Prüfgrundlage

## Hauptmenü

Ursprüngliche Typografie-/Layoutreferenz: `main-menu-concept.png`, 1672 × 941, Imagegen. Die spätere ausdrückliche Nutzerkorrektur hat Vorrang: Das Menü muss die tatsächliche Spielgrafik zeigen. Das idealisierte KI-Empfangsmotiv bleibt ausschließlich Entwurfsreferenz und wird aus allen Exporten ausgeschlossen. Aktive Bildreferenz ist die gerenderte 3D-Spielszene vor dem Maskottchen; keine eingebrannten Schaltflächen.

- Echte 3D-Kamera vor dem Fell-Maskottchen, feste 16:9-Komposition. Ruhige Navigation links mit auslaufender Randabdunklung; Hase und Wandgemälde rechts. Kein Foto als Ersatz für die Spielszene. Geprüfte Kameraposition (13.9, 2.2, 14.7), Blick auf (18.4, 2.4, 13.4), 60°; seitliche Fahrt ±18 cm. Ein erster Kamerastand im Krokodil wurde bei der nativen Sichtprüfung verworfen.
- Farbwerte: Hintergrund #101613, Schrift #e8e1c8, Akzent #b6a16d, deaktivierte Schrift #77786f. Keine runden Kacheln, keine neuen Statusabzeichen.
- Bodoni Moda (OFL) für Titel, Untertitel und Navigation; bestehende lesbare UI-Schrift für lange Hilfetexte. Native Godot-Controls, sichtbarer Tastaturfokus und Hover-Zustand.
- Titel AFTER PLAY oben links; Kinderparadies darunter; danach exakt „Dreizehn Rundgänge. Keine zweite Sicherheit.“.
- Navigation in dieser Reihenfolge: Neue Nachtschicht, Schicht fortsetzen, Einstellungen, Dienstanweisung, Mitwirkende, Spiel beenden (Web: Zur Webseite). Navigation entsprechend dem Konzept ab y=512; primäre Schaltfläche um (250, 540). Automatisierte Bedienung verwendet die tatsächlichen Control-Rechtecke.
- Kleine untere Hinweise WASD · Maus · E und v2.5.0. Fortsetzen hängt am vorhandenen Spielstand, keine fingierte Fortschrittsanzeige.
- Einstellungen verwenden dieselbe Schrift-/Farbfamilie. Vorhandene Kategorien Bild, Audio, Steuerung und Spiel bleiben mit ihren tatsächlichen Funktionen erhalten.
- Sehr dezente Staub-/Lichtbewegung; Kamerabewegungs-Einstellung schaltet sie aus. Keine Bewegung, die Text verschiebt.

## 3D-Abweichung von 2D-Spiel-Asset-Regeln

Die begehbare Welt ist ein vollständiges Godot-3D-Spiel: sichtbares Fell, Blutauflagen, Türen und Kollisionen bleiben echte räumliche Geometrie beziehungsweise Shader. Keine generierten flachen Figuren als Ersatz für interaktive 3D-Modelle. Generierte Szenenbilder werden für die ausdrücklich gewünschte bebilderte Rückblende eingesetzt. Das Menü zeigt die tatsächliche 3D-Welt.

## Rückblende

Die originale Marelle-Aufnahme wird lokal transkribiert. Erst nach Prüfung des Transkripts werden Szenen und Zeitmarken festgelegt. Die tatsächliche Audiowiedergabeposition steuert Bildwechsel, Pause und Wiederaufnahme. Keine eigenständig laufende Bild-Timerfolge; keine erfundenen zusätzlichen Ereignisse.

## Abnahme

Konzept und gerendertes Menü mit `view_image` vergleichen: Komposition, exakte Beschriftung, Typografie, Farben, Abstände, Bildbehandlung. Native 1920 × 1080 sowie Web bei 16:9, 4:3 und 16:10 prüfen. Primäre Navigation, Einstellungen, Spielstart, Fortsetzen, Pause, Archivaufnahme und Finale müssen weiter funktionieren. Browser-Plugin ist in dieser Sitzung nicht verfügbar; daher vorhandenes Playwright/Edge verwenden.

## Sichtprüfung der Umsetzung

Konzept und Menü der tatsächlich exportierten Windows-EXE wurden gemeinsam mit `view_image` geprüft. Die EXE wurde bei 1672 × 940 aufgenommen; die Abweichung um eine Bildzeile vom generierten Konzept erhält das 16:9-Verhältnis des Spiels. Die logische Oberfläche bleibt 1920 × 1080.

| Vergleichspunkt | Prüfung und Korrektur |
|---|---|
| Komposition | Nach Nutzerkorrektur ersetzt die tatsächliche 3D-Welt das idealisierte Empfangsbild. Titel, Palette und Navigation bleiben erhalten. Nur der linke Navigationsrand wird für Lesbarkeit abgedunkelt. Die Kamera wurde außerhalb aller Objekte positioniert und nativ geprüft. |
| Beschriftung | AFTER PLAY, Kinderparadies, Leitsatz und Reihenfolge der sechs Aktionen entsprechen der Referenz. Web verwendet funktional „Zur Webseite“. Der aktivierte Fortsetzen-Zustand folgt dem gespeicherten Spielstand. |
| Typografie | Der zuerst zu breite, zu flache Titel wurde in einen höheren, schmalen Bodoni-Moda-Titel geändert. Dezente Abnutzung wird im nativen Schriftshader dargestellt. |
| Navigation | Die Schaltflächen wurden auf die Referenzpositionen versetzt. Eine durch Schriftmetriken ausgelöste Überlappung um zwei Pixel wurde durch passende Innenabstände beseitigt; tatsächliche Control-Rechtecke werden geprüft. |
| Palette und Fokus | Dunkles Grün-Schwarz, gealtertes Creme und Messing bleiben erhalten. Hover, Tastaturfokus und deaktiviertes Fortsetzen sind echte Zustände. |
| Bilder und Überblendung | Eine im ersten Sichttest erkannte doppelte Texturabtastung verdunkelte und versetzte die Rückblenden. Ein separater Vertex-Farbwert erhält nun das originale Motiv und die tatsächliche Überblendungs-Alpha. |
| Bewegung und Ton | Bildbewegung wird aus der Stimme abgeleitet und durch die Kamerabewegungs-Einstellung abgeschaltet. Die unveränderte Abandoned-Arcade-Aufnahme ist unabhängig vom Raumklang separat regelbar, wiederholt sich und endet vor dem Spielstart. Musikbox.mp3 bleibt dem Party Raum und Abspann zugeordnet. |

Keine zusätzlichen Überschriften, Kennzahlen, Abzeichen oder Kacheln wurden in das Hauptmenü eingeführt. Bedienbare Schrift und Schaltflächen bleiben Godot-Elemente. Die ursprüngliche Bildreferenz liefert Typografie, Hierarchie und Palette. Die ausdrücklich gewünschte Abweichung im Hintergrund zeigt dagegen die reale Spielgrafik. Schriftabnutzung und Fokuszustände sind native Ausführungen.
