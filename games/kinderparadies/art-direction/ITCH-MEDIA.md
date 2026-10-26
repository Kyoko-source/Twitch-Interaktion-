# Echte itch.io-Aufnahmen aus Version 2.12.2

Das empfohlene Cover ist `itch-cover/after-play-cover-ingame-v1.png`.
Es stammt aus dem echten Partyraum mit dem tatsächlichen Stoffhasen. Nur der
Spielname und eine transparente dunkle Textunterlage wurden im Renderer ergänzt.
Die zuvor erzeugte Illustration `after-play-cover-v1.png` wird dafür nicht verwendet.

Der native Forward+-Renderer lief auf höchster regulärer Grafikqualität mit den
Standardeinstellungen des Spiels (Helligkeit 1,15). Es wurden keine Modelle,
Materialien, Raumbeleuchtung oder Effekte für die Aufnahmen hinzugefügt.
Für das Cover sind HUD und gehaltene Taschenlampe ausgeblendet; deren Licht ist
das normale Spielerlicht. Die acht Bildschirmaufnahmen behalten das Spiel-HUD.
Die Aufnahmepositionen und Titelschrift sind in `itch_capture.gd` festgehalten.
Geheimes Archiv und beide Enden werden nicht gezeigt.

Erneut aufnehmen: Godot mit `--path games/kinderparadies --resolution 1920x1080`
und Benutzerargumenten `-- --render-qa --itch-media --capture-dir=<absoluter Ordner>`
starten. Dieser private Weg verwendet getrennte Aufnahme-Spielstände und ist
zusammen mit `native_render_qa.gd` aus den öffentlichen Builds ausgeschlossen.

Fertige Dateien im Workspace:

- `game-releases/AfterPlay-Itchio-Bilder-v2.12.2/`: acht PNG-Bildschirmaufnahmen
  mit 1920 × 1080 und das Cover mit/ohne Titel in 1260 × 1000.
- `game-releases/AfterPlay-Itchio-Bilder-v2.12.2.zip`: dieselben zehn Bilder,
  direkt im ZIP-Hauptverzeichnis. Auflösung, Lesbarkeit und ZIP-CRC geprüft.

Die Bilder werden separat auf der itch.io-Spielseite eingetragen und gehören
nicht in den Download des Spiels. Der Windows-Build bleibt Version 2.12.2.
