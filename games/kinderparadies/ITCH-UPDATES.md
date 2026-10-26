# After Play: Uploads und Updates über die itch-App

Profil: **KyokoHauntedGames**. Als Spieladresse ist vorläufig
`kyokohauntedgames/after-play` eingestellt. Der Projektname muss mit der auf
itch.io angelegten Seite übereinstimmen; er lässt sich mit `-Project` ändern.
Diese Anleitung und die Werkzeuge bleiben im Entwicklerprojekt, nicht im
Spieler-Download. Es wurde noch nichts zu itch.io hochgeladen.

## Einmalige Einrichtung

1. Auf itch.io eine Spielseite anlegen. Für Windows plus Browser den Typ
   **HTML Game** verwenden; die Sichtbarkeit zunächst auf Draft lassen.
2. Im Projektordner PowerShell öffnen und Butler vorbereiten:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tools/setup-after-play-butler.ps1
   ```

   Das offizielle Windows-Butler 15.32.0 wird lokal mit festem SHA-256 geprüft.
   Es werden weder PATH noch die systemweite Ausführungsrichtlinie geändert.
3. Einmal anmelden. Die Anmeldung öffnet den Browser und speichert die
   Zugangsdaten über Butler außerhalb des Projekts:

   ```powershell
   & ./tools/art-source/butler/butler.exe login
   ```

## Vorbereitung ohne Upload

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/publish-after-play-itch.ps1
```

Das prüft die Prüfsummen und jeden Dateiinhalt beider fertiger Spielerpakete
gegen die Release-ZIPs und führt für beide Butler `--dry-run` aus. Es braucht
keine Anmeldung und veröffentlicht nichts. Der lokale Plan liegt anschließend
unter `build/itch-upload-plan.json`.

## Erster Upload und spätere Updates

Erst nach bestätigter Spieladresse tatsächlich hochladen:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/publish-after-play-itch.ps1 -Project kyokohauntedgames/after-play -Upload
```

Das lädt ausschließlich `build/player-package` nach **windows** und
`build/browser-package` nach **web**. Die Version stammt aus `build/release.json`.
Optional `-Platform Windows` oder `-Platform Web` verwenden, um nur eine Fassung
zu aktualisieren. Nicht den gesamten Build-, Projekt- oder Downloadordner wählen.

Beim ersten Upload auf der itch.io-Bearbeitungsseite **windows** als Windows
markieren und **web** als im Browser spielbar. Für Web Click to Play, Vollbild
und 16:9 (z. B. 1280 × 720) verwenden, Mobile-Unterstützung deaktivieren. Danach
die Seite speichern. Die Windows-Fassung lässt sich über die itch-App installieren.
Vor dem öffentlichen Start auf einem zweiten Windows-PC installieren und starten.

Für spätere Updates neue Exporte erstellen, paketieren und denselben Befehl
nutzen. **Die Kanäle windows und web behalten ihre Namen, ohne Versionsnummer.**
Butler überträgt Änderungen; die itch-App aktualisiert ihre Installation.
Die App muss dafür geöffnet und online sein. Ein manuell heruntergeladenes ZIP
hat keine automatische Updatefunktion. Updates nicht während einer laufenden
Spielsitzung testen; vorher das Spiel beenden.

Spielstände und Einstellungen bleiben in Godots bisherigem Benutzerdatenordner,
außerhalb der Installation. Dieser Ordnername bleibt für bestehende Spielstände
bewusst stabil. Kein eigener Launcher und keine Update-Hilfsdateien im Spielerpaket.

Der gewünschte Erstellerzugang **0712** bleibt in dieser Fassung aktiv,
einschließlich Fortsetzen des Endraums. Er wird nicht in Spieleranleitung,
Trailer oder Upload-Beschreibung verraten. Der reguläre Zeitungsweg bleibt bestehen.

Quellen: [Butler installieren](https://itch.io/docs/butler/installing.html),
[Builds hochladen](https://itch.io/docs/butler/pushing.html),
[Updates in der itch-App](https://itch.io/docs/itch/integrating/updates.html).
