NULLSIGNAL — eigene Musik

Hier genau diese zwei Dateien ablegen:

  menu.mp3     Hauptmenü und Lobby
  ingame.mp3   laufende Mission

Beide Songs wiederholen sich automatisch. Ohne Dateien bleibt die Musik still.
Countdown und Effekte funktionieren unabhängig von diesen Dateien.
Der Gast bekommt keine Hintergrundmusik. Bei Pause oder Ergebnis stoppt sie.
Im Spiel lassen sich Musik und Effekte getrennt regeln; der Lautsprecher schaltet alles stumm.
Nach dem Austausch die Spielseite neu laden. Keine Änderung am Code nötig.

Live-Ordner auf Hetzner:
/opt/twitch-interaktion/frontend/public/music/nullsignal/

Dateien direkt dort ablegen: sofort verfügbar, ohne Build oder Neustart.
Für Dateien von diesem Windows-PC: deploy/upload-nullsignal-music.cmd doppelklicken.
Die MP3s bleiben außerhalb von Git und werden bei Deployments nicht überschrieben.
