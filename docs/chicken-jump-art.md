# Chicken Jump – Bilder für die Überarbeitung

Alle Bilder im gleichen Stil wie Huhn und Bison. Einzelbilder und Animationen bitte **vor reinem Grün (#00FF00)**, so wie der Bison-GIF. Das Grün stanze ich aus. Tiere und Fahrzeuge bitte **nach rechts schauend** wie beim Bison, ich spiegle sie, damit sie nach links laufen.

Für jedes Bild brauche ich nur die Datei. Den Rest (Freistellen, Spiegeln, Einbauen) erledige ich.

Stil-Satz, der in jeden Prompt gehört:

> stylized 3D cartoon game asset, soft painterly rendering, warm sunset lighting, chunky readable silhouette, cute mobile game style matching a fluffy cartoon chicken and a cartoon bison, side view

## Hintergrund (3 Ebenen, nahtlos kachelbar)

Breite Bilder, die sich links und rechts nahtlos aneinanderreihen lassen. Je weiter hinten, desto langsamer scrollen sie.

| Datei | Inhalt | Format |
|---|---|---|
| `bg-far.png` | Himmel mit Sonnenuntergang, ferne violette Berge | 3840 × 1080, volles Bild ohne Grün |
| `bg-mid.png` | Hügel mit Feldern, Bäumen, Scheune, Windrad | 3840 × 1080, oberer Bereich (Himmel) grün |
| `bg-near.png` | Hecken, Holzzaun, Blumen direkt hinter dem Weg | 3840 × 1080, alles über den Hecken grün |

**bg-far:**
> seamless horizontally tiling wide game background, 3840x1080, dreamy sunset sky with pink and purple clouds, big soft sun near the horizon, distant purple mountain range, no foreground, no characters, stylized 3D cartoon, soft painterly rendering

**bg-mid:**
> seamless horizontally tiling wide game background layer, 3840x1080, rolling green farm hills with wheat fields, a red barn, a wooden windmill, round trees, warm sunset light, everything above the hills is pure solid green #00FF00 chroma key, no characters, stylized 3D cartoon, soft painterly rendering

**bg-near:**
> seamless horizontally tiling wide game foreground layer, 3840x1080, lush hedges, wildflowers and an old wooden pasture fence along the bottom third, warm sunset light, everything above the hedges is pure solid green #00FF00 chroma key, side view, stylized 3D cartoon, soft painterly rendering

## Hindernisse

| Datei | Hindernis | Spielmechanik |
|---|---|---|
| `hay.png` | Runder Heuballen | drüberspringen |
| `tractor.png` | Kleiner roter Traktor | lang drüberspringen (Doppelsprung) |
| `fox.gif` | Rennender Fuchs, 12–20 Frames | stürmt heran, drüberspringen |
| `branch.png` | Tief hängender Ast mit Blättern | drunter durchducken |
| `mud.png` | Schlammpfütze | bremst ab, wenn man reinläuft |

**hay.png:**
> single round hay bale lying on its side, golden straw texture, two red twine bands, side view, centered, full object visible, plain pure solid green #00FF00 background, no shadow on the background, stylized 3D cartoon game asset, soft painterly rendering, warm sunset lighting

**tractor.png:**
> small cute red farm tractor, big rear wheel with yellow rim, small front wheel, little cab with window, exhaust pipe, side view facing right, centered, full object visible, plain pure solid green #00FF00 background, stylized 3D cartoon game asset, soft painterly rendering, warm sunset lighting

**fox.gif (Animation wie der Bison):**
> looping run cycle animation of an angry cartoon fox galloping, side view facing right, 25 fps, about 0.8 seconds, full body visible in every frame, plain pure solid green #00FF00 background, stylized 3D cartoon, soft painterly rendering, matching a cartoon bison run cycle

**branch.png:**
> low hanging tree branch coming down from the top edge of the image, thick brown bark, dense clusters of green leaves and a few red berries at the lower end, hanging at head height, plain pure solid green #00FF00 background, stylized 3D cartoon game asset, soft painterly rendering, portrait format 1:2.5

**mud.png:**
> wide flat muddy puddle on a dirt path, glossy brown mud with small splashes and a light reflection, seen from a low side angle, very wide and flat (about 5:1), plain pure solid green #00FF00 background, stylized 3D cartoon game asset

## Wenn du willst, außerdem

- `bison-jump.gif`: Bison, der einen Hüpfer macht, für die Stampede-Szene
- `chicken-*.png`: weitere Hühnerposen (Jubeln, Erschrecken) für die Start- und Endkarte
