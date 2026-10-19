# Vorhandene Anomalien — After Play 2.3.0

Stand: 19. Oktober 2026. Katalog aus `scripts/patrol.gd`.

45 Anomalien insgesamt; 20 frühere Varianten wurden ersetzt. Rundgang 1 sowie die Zeitungsrunden 3, 5, 8 und 11 sind garantiert normal. Die übrigen Rundgänge werden zufällig aus normalen Runden und dem Anomalie-Katalog gemischt. Es gibt keine feste Anomalie pro Rundennummer.

## Zeitungen und Runden

Gemeint ist der angezeigte Rundgang innerhalb der 13er-Serie.

| Rundgang | Zeitung | Fundort |
|---|---|---|
| 3 | Die Eröffnung | Party Raum, auf dem Geburtstagstisch |
| 5 | Das Verschwinden | Kino, auf einem vorderen Sitz |
| 8 | Die Vertuschung | Küche, auf dem Herd |
| 11 | Die Schließung | Im Krabbeltunnel; mit C hineinkrabbeln |

Alle vier Zeitungsrunden sind vollständig anomaliefrei, auch nach dem Einsammeln
und beim Laden. Dort ist die grüne Tür richtig. Die Sammlung bleibt innerhalb
der Schicht erhalten; bei Tod oder einer neuen Schicht beginnt sie von vorn.

## Küche (4)

- Der Küchenclown hört auf zu rühren, fährt auf dich zu und beobachtet dich danach. (`clown_lunge`)
- Lange knöcherne Arme greifen aus dem Schimmeltopf. (`pot_arms`)
- Neben dem Küchenclown erscheint ein zweiter Besucher und verfolgt dich durch die Küche. (`kitchen_double`)
- Eine hagere Gestalt lauert vor dem Kühlschrank und beugt sich plötzlich vor. (`fridge_occupant`)

## Bällebad (10)

- Eine Gestalt schaut durch das Dachfenster in die Krabbelröhre. (`tube_watcher`)
- Bälle schweben über dem Bällebad. (`balls_float`)
- Eine verrenkte Gestalt kriecht vom Auslauf der Rutsche auf dich zu. (`slide_crawler`)
- Ein riesiger Ball steckt im Bällebad. (`ball_giant`)
- Das Bällebad ist leer. (`balls_missing`)
- Die Sicherheitsnetze an der Kletteranlage fehlen. (`net_missing`)
- Knöcherne Arme schnellen aus dem Bällebad und bleiben zwischen den Bällen stehen. (`pit_hands`)
- Der normale graugrüne Nebel ist blutrot geworden. (`heavy_mist`)
- Eine kriechende Gestalt bewegt sich hinter den Netzen im Klettergerüst. (`frame_stalker`)
- Das Krokodil bäumt sich mit einem Knall auf und bleibt danach aufgerichtet. (`croc_snap`)

## Party Raum (9)

- Die Stühle hängen an der Decke. (`chair_ceiling`)
- Unter dem großen Clownfresko steht ein Besucher, der dich durch den Party Raum verfolgt. (`party_portrait`)
- Die Beleuchtung im Party Raum ist ausgefallen. (`party_dark`)
- Ein ganzer Schwarm Ballons füllt den Party Raum. (`balloons_many`)
- Die Ballons hängen nach unten und liegen am Boden. (`balloons_floor`)
- Drei stumme Gestalten stehen um den Geburtstagstisch. (`party_guests`)
- Zwischen den Kerzen taucht ein ausgezehrtes Gesicht auf und schnappt nach dir. (`cake_mouth`)
- Die drei Geburtstagsballons folgen dir durch den Raum. (`balloons_follow`)
- Die Ballons blähen sich bei Annäherung mit einem Knall auf. (`party_burst`)

## Wartungsgang (6)

- Aus dem dunklen Wartungsende folgt dir eine langarmige Gestalt. (`service_pursuit`)
- Ein verdrehter Besucher hängt kopfüber im Wartungsgang und fährt auf dich herab. (`service_ceiling`)
- Das große Wandbild ist verschwunden. (`mural_missing`)
- Ein übergroßer Stern hängt im Wartungsgang. (`star_giant`)
- Aus dem Wandbild laufen breite Blutspuren. (`mural_bleeds`)
- Eine Gestalt schießt quer durch den Wartungsgang und bleibt verrenkt stehen. (`corridor_crossing`)

## Kino (3)

- Eine Gestalt steht vor der Kinoleinwand und läuft auf dich zu. (`screen_visitor`)
- Hinter der letzten Kinoreihe steht ein Besucher auf und folgt dir durch den Gang. (`cinema_last_row`)
- Der Pferdeschädel stößt bei Annäherung aus dem Schacht nach unten. (`vent_strike`)

## Empfang (11)

- Eine ausgemergelte Gestalt beugt sich hinter dem Empfang hervor und zuckt auf dich zu. (`reception_peeker`)
- Die Uhr dreht sich viel zu schnell. (`clock_fast`)
- Ein langarmiger Besucher verfolgt dich kurz durch den leeren Empfangsgang. (`reception_charge`)
- Das Spielauto ist riesig geworden. (`car_giant`)
- Drei reglose Besucher warten mit verdrehten Köpfen vor dem Empfang. (`reception_queue`)
- Das rote Spielauto am Empfang fehlt. (`car_missing`)
- Alle Deckenlampen leuchten rot. (`lights_red`)
- Eine frische Blutspur zieht sich durch den Hauptgang. (`blood_trail`)
- Der Stoffhase hängt kopfüber vor der Decke statt auf seiner Bank zu sitzen. (`bunny_ceiling`)
- Der Stoffhase springt dich bei Annäherung an und bleibt danach vor seiner Bank liegen. (`bunny_lunge`)
- Das verlassene Schaukelpferd schaukelt von alleine. (`horse_rocks`)

## Krabbelröhre (2)

- Eine kriechende Gestalt verfolgt dich kurz im Krabbeltunnel. Nur von innen sichtbar. (`tube_chase`)
- Lange Finger schlagen von außen gegen ein Röhrenfenster. Nur von innen sichtbar. (`tube_window_hands`)

## Normaler Vergleich

Dichter graugrüner Nebel, das große Clownfresko mit vier leeren Stühlen, der knöcherne Pferdeschädel im Kinoschacht, der rührende Küchenclown, das NO-SIGNAL-Bild und die Spieluhr gehören zur normalen Umgebung. Auch entfernte Schritte und Röhrenstimmen sind normale Raumgeräusche.

Zusätzliche Besucher und greifende Arme sind Anomalien. Die neuen Begegnungen spielen einen Schreckmoment pro Rundgang; danach bleibt eine sichtbare Gestalt oder Spur zurück. Verfolgungen sind kurz und beenden die Schicht nicht automatisch. Eine falsche Tür bedeutet weiterhin Tod und Neustart.

`tube_watcher`, die Tunnelverfolgung und die Fensterhände sind außerhalb der Röhre unsichtbar. TAB pausiert auch Begegnungen und Geräusche.

Zeitungen, Zettel und Geheimtür sind keine Anomalien. Auch die Schreckmomente bei einer falschen Tür, im Archivfinale und beim absichtlichen Betätigen des Jumpscare-Schalters im Menü gehören nicht zum zufälligen Anomalie-Katalog. Ältere Anomalie-Spielstände werden auf die Ersatzanomalien bzw. in Zeitungsrunden auf einen normalen Rundgang umgesetzt.
