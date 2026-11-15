// The 50 live effects of Admin Stream Control. Ids must match backend/app/stream_control.py.
export const CATEGORIES = [
  { id: "party", label: "Party & Jubel" },
  { id: "weather", label: "Wetter & Stimmung" },
  { id: "retro", label: "Filter & Bildeffekte" },
  { id: "farm", label: "Hühnerhof & Quatsch" },
  { id: "react", label: "Reaktionen" },
];

export const EFFECTS = [
  { id: "confetti-cannon", cat: "party", emoji: "🎉", label: "Konfetti-Kanone", dur: 8, text: "Zwei Kanonen ballern den Bildschirm voll." },
  { id: "confetti-rain", cat: "party", emoji: "🎊", label: "Konfetti-Regen", dur: 12, text: "Bunter Konfetti fällt von oben." },
  { id: "fireworks", cat: "party", emoji: "🎆", label: "Feuerwerk", dur: 12, text: "Raketen steigen auf und explodieren." },
  { id: "balloons", cat: "party", emoji: "🎈", label: "Ballons", dur: 12, text: "Luftballons steigen auf." },
  { id: "gold-rain", cat: "party", emoji: "🪙", label: "Goldregen", dur: 10, text: "Goldmünzen prasseln herunter." },
  { id: "money-rain", cat: "party", emoji: "💸", label: "Geldregen", dur: 10, text: "Scheine flattern durchs Bild." },
  { id: "stars", cat: "party", emoji: "✨", label: "Sternenschauer", dur: 10, text: "Funkelnde Sterne überall." },
  { id: "hearts", cat: "party", emoji: "💖", label: "Herzen-Flut", dur: 10, text: "Herzen steigen von unten auf." },
  { id: "applause", cat: "party", emoji: "👏", label: "Applaus", dur: 7, text: "Klatschende Hände und Beifall." },
  { id: "disco", cat: "party", emoji: "🪩", label: "Disco", dur: 15, text: "Discokugel mit bunten Scheinwerfern." },
  { id: "rainbow", cat: "party", emoji: "🌈", label: "Regenbogen", dur: 10, text: "Ein Regenbogen spannt sich übers Bild." },
  { id: "hype", cat: "party", emoji: "🔥", label: "HYPE!", dur: 7, text: "Riesiger HYPE-Schriftzug mit Flammen." },

  { id: "noir-rain", cat: "weather", emoji: "🌧️", label: "Schwarz-Weiß + Regen", dur: 25, text: "Grauer Film-Noir-Look mit Regen und Blitzen." },
  { id: "thunderstorm", cat: "weather", emoji: "⛈️", label: "Gewitter", dur: 20, text: "Starkregen, Blitze und Donner." },
  { id: "snow", cat: "weather", emoji: "❄️", label: "Schneefall", dur: 25, text: "Sanfter Schneefall." },
  { id: "fog", cat: "weather", emoji: "🌫️", label: "Nebel", dur: 20, text: "Dichter Nebel zieht durchs Bild." },
  { id: "sandstorm", cat: "weather", emoji: "🏜️", label: "Sandsturm", dur: 15, text: "Wüstenwind mit Sand." },
  { id: "autumn", cat: "weather", emoji: "🍂", label: "Herbstlaub", dur: 20, text: "Bunte Blätter wehen herab." },
  { id: "sakura", cat: "weather", emoji: "🌸", label: "Kirschblüten", dur: 20, text: "Rosa Blütenblätter schweben." },
  { id: "underwater", cat: "weather", emoji: "🐠", label: "Unterwasser", dur: 15, text: "Blaues Wasser, Lichtspiel und Blasen." },
  { id: "fire", cat: "weather", emoji: "🔥", label: "Flammenmeer", dur: 12, text: "Flammen lodern am unteren Rand." },
  { id: "frost", cat: "weather", emoji: "🧊", label: "Eiszeit", dur: 15, text: "Der Bildschirm friert vom Rand her ein." },
  { id: "sunset", cat: "weather", emoji: "🌅", label: "Sonnenuntergang", dur: 15, text: "Warmes Abendlicht mit Lens-Flare." },
  { id: "night-vision", cat: "weather", emoji: "🟢", label: "Nachtsicht", dur: 15, text: "Grünes Nachtsichtgerät mit Rauschen." },

  { id: "vhs", cat: "retro", emoji: "📼", label: "VHS-Kassette", dur: 15, text: "Alte Videokassette mit Bildstörungen." },
  { id: "glitch", cat: "retro", emoji: "📺", label: "Signalstörung", dur: 5, text: "Das Bild zerfällt in Glitches." },
  { id: "matrix", cat: "retro", emoji: "💾", label: "Matrix-Code", dur: 12, text: "Grüner Code regnet herab." },
  { id: "old-film", cat: "retro", emoji: "🎞️", label: "Alter Film", dur: 15, text: "Sepia, Kratzer und Flackern." },
  { id: "crt-off", cat: "retro", emoji: "📴", label: "TV aus", dur: 4, text: "Röhrenfernseher schaltet ab und wieder an." },
  { id: "shockwave", cat: "retro", emoji: "💥", label: "Bass-Drop", dur: 6, text: "Druckwellen pumpen im Takt." },
  { id: "glass-crack", cat: "retro", emoji: "🪟", label: "Bildschirm-Riss", dur: 6, text: "Das Glas springt mit lautem Knall." },
  { id: "spotlight", cat: "retro", emoji: "🔦", label: "Spotlight", dur: 10, text: "Alles dunkel, nur ein Lichtkegel wandert." },
  { id: "dizzy", cat: "retro", emoji: "💫", label: "Schwindelig", dur: 6, text: "Kreisende Sterne wie nach einem Treffer." },
  { id: "hypno", cat: "retro", emoji: "🌀", label: "Hypnose", dur: 8, text: "Eine drehende Hypnose-Spirale." },

  { id: "chicken-run", cat: "farm", emoji: "🐔", label: "Hühner-Invasion", dur: 10, text: "Eine Hühnerherde rennt durchs Bild." },
  { id: "egg-rain", cat: "farm", emoji: "🥚", label: "Eier-Regen", dur: 10, text: "Eier fallen und zerplatzen unten." },
  { id: "feathers", cat: "farm", emoji: "🪶", label: "Federsturm", dur: 10, text: "Federn wirbeln durch die Luft." },
  { id: "popcorn", cat: "farm", emoji: "🍿", label: "Popcorn", dur: 8, text: "Popcorn ploppt von unten hoch." },
  { id: "pizza", cat: "farm", emoji: "🍕", label: "Pizza-Regen", dur: 10, text: "Es regnet Pizza." },
  { id: "laugh", cat: "farm", emoji: "😂", label: "Lachflash", dur: 6, text: "Lach-Emojis überall." },
  { id: "horror", cat: "farm", emoji: "👻", label: "Horror", dur: 12, text: "Rotes Pulsieren, Blut tropft, Herzschlag." },
  { id: "sunglasses", cat: "farm", emoji: "😎", label: "Deal With It", dur: 6, text: "Pixel-Sonnenbrille fällt ins Bild." },

  { id: "gg", cat: "react", emoji: "🏆", label: "GG", dur: 5, text: "Goldenes GG mit Pokalen." },
  { id: "rip", cat: "react", emoji: "🪦", label: "R.I.P.", dur: 6, text: "Grabstein, graues Bild, Trauer." },
  { id: "respect", cat: "react", emoji: "🫡", label: "F – Respekt", dur: 5, text: "Drückt F, um Respekt zu zollen." },
  { id: "clutch", cat: "react", emoji: "⚡", label: "CLUTCH!", dur: 5, text: "Elektrisches CLUTCH mit Blitzen." },
  { id: "fail", cat: "react", emoji: "🎺", label: "FAIL!", dur: 5, text: "Roter FAIL-Stempel und trauriges Horn." },
  { id: "wow", cat: "react", emoji: "😮", label: "WOW!", dur: 5, text: "Großes WOW mit Funkeln." },
  { id: "countdown", cat: "react", emoji: "⏱️", label: "Countdown 3-2-1", dur: 5, text: "3, 2, 1, LOS! mit Ansager." },
  { id: "ad", cat: "react", emoji: "📣", label: "Werbung", dur: 0, text: "Spielt ein Werbevideo einmal im Vollbild." },
];

export const VIDEOS = [
  { id: "marelle-trailer", label: "Marelle Trailer", file: "/stream-media/marelle-trailer.mp4", thumb: 4 },
  { id: "after-play", label: "After Play Trailer", file: "/stream-media/after-play.mp4", thumb: 40 },
];

export const BY_ID = Object.fromEntries(EFFECTS.map((e) => [e.id, e]));
