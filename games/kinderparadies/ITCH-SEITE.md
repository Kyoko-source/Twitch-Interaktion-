# After Play — Veröffentlichungsvorbereitung 2.8.0

## Dateien

- Windows: `build/after-play-windows-v2.8.0.zip`. Enthält `AfterPlay.exe`, Intro-Aufnahme, Anleitung und Quellen-/Lizenzhinweise. ZIP vollständig entpacken, danach `AfterPlay.exe` starten. Kein Website-Konto erforderlich; offline spielbar.
- Web: `build/after-play-web-v2.8.0.zip`. `index.html` liegt direkt im ZIP-Hauptverzeichnis. Die Web-Fassung benötigt Maus und Tastatur.
- Der Windows-Build ist die grafisch bevorzugte Fassung. Das Programm ist nicht digital signiert.
- Eine englische Sprachfassung und Tests auf anderen Betriebssystemen sind nicht enthalten.

## Direkt verwendbarer Seitentext

**After Play — Kinderparadies**

**Dreizehn Rundgänge. Keine zweite Sicherheit.**

Nachts gehört das verlassene Happyland dir. Dein Chef hat eine einfache Aufgabe: Kontrolliere das Kinderparadies und entscheide, ob alles noch so ist wie beim ersten Rundgang.

Keine Veränderung? Nimm die grüne Tür. Eine Anomalie? Nimm die rote Tür. Triff dreizehn richtige Entscheidungen in Folge. Eine falsche Tür beendet deine Nachtschicht.

Zwischen Bällebad, Kletteranlage, Krabbelröhren, Party Raum, Werkstatt, Küche und verfallenem Kino warten 61 mögliche Anomalien. Nicht jedes Geräusch ist ein Hinweis. Nicht alles, was dich beobachtet, hat sich verändert.

Alte Zeitungen erzählen Stück für Stück von der Vergangenheit des Happyland. Wer ihre Hinweise versteht, findet einen zusätzlichen Raum und ein verborgenes Ende.

### Merkmale

- Ego-Horror mit frei begehbarer 3D-Umgebung, Springen, Krabbeln und physischen Spielzeugen.
- 61 zufällige Anomalien, kurze Verfolgungen und Schreckmomente.
- Eine verlassene Geburtstagsbühne, ein begehbarer Kostümraum und lesbare Wartungsberichte.
- Persönliche Nachtdienst-Ausrüstung und unterschiedliche Lichtstimmungen pro Raum.
- Zurückhaltendes HUD; handschriftliche Kontrollliste im pausierbaren Inventar.
- Räumliche Geräusche und Schritte passend zu Beton, Teppich, Metall, Holz, Kunststoff und Polstern.
- Windows-Grafik mit indirekter Beleuchtung, Schatten und dichtem Nebel.
- Deutsche Texte und deutsche Sprachaufnahmen.
- Eine bebilderte Rückblende zur letzten Archivaufnahme, mit elf an die Stimme gebundenen Erinnerungen.
- Speichern und Fortsetzen innerhalb der laufenden Nachtschicht.

### Steuerung

WASD / Pfeiltasten: bewegen · Maus: umsehen · Shift: schneller gehen · Leertaste: springen · C: ducken / krabbeln · F: Taschenlampe · G: Gegenstand aufheben / ablegen · Linksklick: werfen · E: interagieren · TAB: Inventar und Fundstücke · ESC: Pause. Leertaste im Intro gedrückt halten: überspringen.

### Inhaltshinweise

Das Spiel enthält intensive Schreckmomente, laute Geräusche, flackerndes Licht, deformierte Gestalten, Blutdarstellungen und eine Geschichte über vermisste Kinder. Der Jumpscare-Schalter im Einstellungsmenü ist ein absichtlicher Schreckmoment und schaltet die Schreckeffekte nicht ab.

### Mitwirkende

Spielidee und Umsetzung: **Kyoko**.

Zusätzliche Ideen: **einsmarello**.

Testspieler: **einsmarello**, **__jerry__**, **gingerbread**, **Mozart**.

Quellen und Lizenzen für verwendete Fremdmaterialien liegen dem Download bei, insbesondere Poly Haven (CC0), Kenney (CC0), der bearbeitete Lee-Perry-Smith-Kopfscan (CC BY), Oswald (OFL) und Godot (MIT).

Die Rückblendenbilder und die neue Bluttextur wurden für das Spiel mit KI-Bildgenerierung erstellt. Sie stellen erfundene Szenen dar. Das Hauptmenü zeigt die tatsächliche räumliche Spielszene mit ihren echten Modellen; Menütexte und Schaltflächen bleiben bedienbare Elemente. Bodoni Moda wird unter der SIL Open Font License mitgeliefert. Die separat regelbare Menümusik „Abandoned Arcade“ wurde vom Ersteller bereitgestellt; die ursprüngliche Musikbox begleitet weiterhin den Abspann.

## Einrichtung auf itch.io

1. Ein neues Spielprojekt unter dem eigenen itch.io-Konto anlegen. Für Windows allein den Projekttyp „Downloadable“ wählen. Für beide Fassungen „HTML Game“ wählen und zusätzlich das Windows-ZIP hochladen.
2. Das Windows-ZIP als Windows-Download markieren. Das Web-ZIP zum Spielen im Browser markieren. Den QA-Export niemals hochladen.
3. Beim Web-Spiel „Click to Play“ und Vollbild verwenden; alternativ ein 16:9-Fenster wie 1280 × 720. Mobile-Unterstützung nicht aktivieren: das Spiel verlangt Maus und Tastatur.
4. Deutsche Sprache und passende Horror-/Ego-/3D-/Anomalie-Tags eintragen. Preis und Sichtbarkeit selbst festlegen.
5. Echte Spielscreenshots aus der finalen Version verwenden. Vor dem öffentlichen Start einen vollständigen Durchgang auf einem weiteren Windows-PC spielen lassen.

Die öffentlichen Pakete benötigen keine besondere Server-API. Der Web-Export verwendet keine Threads und keine Website-Anmeldung. Die itch.io-Veröffentlichung selbst ist mit dieser Vorbereitung noch nicht erfolgt.

Offizielle Upload-Dokumentation: https://itch.io/docs/creators/html5 und https://itch.io/docs/creators/getting-started
