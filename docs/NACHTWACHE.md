# NACHTWACHE — Kinderparadies

Spielstart auf der Webseite: `/#games/nachtwache`.
Windows-Download: `/downloads/nachtwache-windows-v1.0.0.zip`.
Direkter Web-Start: `/standalone/kinderparadies/index.html`.

Vollständiges gemeinsames Godot-Projekt in `games/kinderparadies/`, mit nativer
Windows-EXE (kein WebView) und WebGL-Export. Beide Fassungen spielen denselben
vierteiligen Rundgang mit 30 Anomalien. 13 richtige Entscheidungen in Folge
gewinnen; ein Fehler setzt die Serie zurück. Details, Steuerung und Build-Anleitung
stehen in `games/kinderparadies/README.md`.

## Release

1. `powershell -ExecutionPolicy Bypass -File tools/build-kinderparadies.ps1 -WithQA`
2. Native EXE mit `--headless -- --self-test` prüfen. Im Frontend mit einem lokalen
   HTTP-Server für `games/kinderparadies/build/qa` und
   `NACHTWACHE_QA_URL=http://127.0.0.1:4188 npx playwright test nachtwatch.spec.mjs`
   prüfen. Die Suite verweigert externe QA-URLs.
3. Quelländerungen committen und nach `main` pushen.
4. `powershell -ExecutionPolicy Bypass -File deploy/publish-kinderparadies.ps1`

Der Publisher lädt ausschließlich den Release-Webexport und das Windows-ZIP
hoch, verifiziert Archiv- und Dateihashes, behält eine eigene Release-Version und
das vorherige Frontend-Image, setzt zwei Symlinks und baut nur das Frontend neu.
Das Backend und seine Datenbank werden dabei nicht verändert. Bestehende
NULLSIGNAL-Musikdateien werden vor/nach dem Deployment per SHA256 verglichen.

Runtime-Dateien liegen außerhalb von Git in
`/opt/twitch-interaktion/game-releases/kinderparadies/releases/<release>/`.
`web` und `downloads` zeigen auf die aktive Version und sind read-only in den
Frontend-Container eingebunden. Der Container wird nach einem Wechsel neu
erstellt, damit die Bind-Mounts die neue Version auflösen. Fehlerhafte oder
fehlende WASM/PCK/ZIP-Dateien liefern 404, niemals die SPA-HTML-Seite.

Windows-ZIP enthält EXE, Anleitung, Godot MIT-/Drittanbieterhinweise, Oswald OFL
und Kenney CC0. `release.json` nennt die SHA256-Werte. Builds, Engine und
Exporttemplates sind bewusst Git-ignoriert; der vollständige Spielquellcode,
Assets, Import-Einstellungen und Buildskripte werden versioniert.

## Prüfstand

129 native Logik-/Szenenprüfungen bestanden, auch in der exportierten Windows-EXE.
Fünf Browserfälle prüfen echten WASD-Rundgang, beide Entscheidungstüren,
Anomalie/Reset/13er-Ende, Save/Restore, Pause und Einstellungen, native ZIP-Bytes,
Release-Game ohne QA-Hooks sowie den mobilen Launcher ohne horizontalen Überlauf.
Browser-Plugin nicht verfügbar; Playwright/Edge mit WebGL verwendet.

Native grafische Performance auf unterschiedlichen PCs, andere Browser und
Controller/Touch-Spielsteuerung sind nicht geprüft bzw. nicht Bestandteil dieser
Desktop-Fassung. Die tatsächliche 3D-Ansicht wird im Launcher gezeigt; Art-Direction,
Konzeptvergleich und bewusste grafische Abweichungen stehen in `art/DESIGN.md`.
