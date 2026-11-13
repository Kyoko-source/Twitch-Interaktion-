// Fifth-edition rules data from the System Reference Document 5.2
// (Wizards of the Coast, CC-BY-4.0), translated for the table.

export const ABILITIES = [
  { key: "str", short: "STÄ", name: "Stärke" },
  { key: "dex", short: "GES", name: "Geschicklichkeit" },
  { key: "con", short: "KON", name: "Konstitution" },
  { key: "int", short: "INT", name: "Intelligenz" },
  { key: "wis", short: "WEI", name: "Weisheit" },
  { key: "cha", short: "CHA", name: "Charisma" },
];

export const SKILLS = [
  { key: "acrobatics", name: "Akrobatik", ability: "dex" },
  { key: "animal", name: "Mit Tieren umgehen", ability: "wis" },
  { key: "arcana", name: "Arkane Kunde", ability: "int" },
  { key: "athletics", name: "Athletik", ability: "str" },
  { key: "deception", name: "Täuschen", ability: "cha" },
  { key: "history", name: "Geschichte", ability: "int" },
  { key: "insight", name: "Motiv erkennen", ability: "wis" },
  { key: "intimidation", name: "Einschüchtern", ability: "cha" },
  { key: "investigation", name: "Nachforschungen", ability: "int" },
  { key: "medicine", name: "Heilkunde", ability: "wis" },
  { key: "nature", name: "Naturkunde", ability: "int" },
  { key: "perception", name: "Wahrnehmung", ability: "wis" },
  { key: "performance", name: "Auftreten", ability: "cha" },
  { key: "persuasion", name: "Überzeugen", ability: "cha" },
  { key: "religion", name: "Religion", ability: "int" },
  { key: "sleight", name: "Fingerfertigkeit", ability: "dex" },
  { key: "stealth", name: "Heimlichkeit", ability: "dex" },
  { key: "survival", name: "Überleben", ability: "wis" },
];

const ALL_SKILLS = SKILLS.map((s) => s.key);

export const CLASSES = [
  { name: "Barbar", kit: "Großaxt, 4 Wurfspeere, Entdeckerausrüstung", armor: "ungerüstet", ac: (m) => 10 + m.dex + m.con, die: 12, saves: ["str", "con"], primary: ["str", "con", "dex"], pick: 2, skills: ["animal", "athletics", "intimidation", "nature", "perception", "survival"], color: "#ff5a4f", blurb: "Kaum zu stoppen, wenn der Kampfrausch einsetzt." },
  { name: "Barde", kit: "Lederrüstung, Rapier, Dolch, Laute, Unterhalterausrüstung", armor: "Lederrüstung", ac: (m) => 11 + m.dex, die: 8, saves: ["dex", "cha"], primary: ["cha", "dex", "con"], pick: 3, skills: ALL_SKILLS, color: "#ff6fd0", blurb: "Magie durch Musik, Witz und Worte." },
  { name: "Kleriker", kit: "Schuppenpanzer, Schild, Streitkolben, heiliges Symbol, Priesterausrüstung", armor: "Schuppenpanzer + Schild", ac: (m) => 16 + Math.min(m.dex, 2), die: 8, saves: ["wis", "cha"], primary: ["wis", "con", "str"], pick: 2, skills: ["history", "insight", "medicine", "persuasion", "religion"], color: "#ffd56a", blurb: "Göttliche Macht heilt Freunde und straft Feinde." },
  { name: "Druide", kit: "Lederrüstung, Schild, Sichel, Druidenfokus, Entdeckerausrüstung", armor: "Lederrüstung + Schild", ac: (m) => 13 + m.dex, die: 8, saves: ["int", "wis"], primary: ["wis", "con", "dex"], pick: 2, skills: ["arcana", "animal", "insight", "medicine", "nature", "perception", "religion", "survival"], color: "#6fe08a", blurb: "Hüter der Natur, wandelt die Gestalt." },
  { name: "Kämpfer", kit: "Kettenhemd, Langschwert, Schild, 8 Wurfspeere, Gewölbeforscherausrüstung", armor: "Kettenhemd + Schild", ac: (m) => 18, die: 10, saves: ["str", "con"], primary: ["str", "con", "dex"], pick: 2, skills: ["acrobatics", "animal", "athletics", "history", "insight", "intimidation", "persuasion", "perception", "survival"], color: "#ff9d4f", blurb: "Meister aller Waffen und Rüstungen." },
  { name: "Mönch", kit: "Speer, 5 Dolche, Entdeckerausrüstung", armor: "ungerüstet", ac: (m) => 10 + m.dex + m.wis, die: 8, saves: ["str", "dex"], primary: ["dex", "wis", "con"], pick: 2, skills: ["acrobatics", "athletics", "history", "insight", "religion", "stealth"], color: "#5fe0ff", blurb: "Schnelle Fäuste und innere Disziplin." },
  { name: "Paladin", kit: "Kettenhemd, Schild, Langschwert, 6 Wurfspeere, heiliges Symbol, Priesterausrüstung", armor: "Kettenhemd + Schild", ac: (m) => 18, die: 10, saves: ["wis", "cha"], primary: ["str", "cha", "con"], pick: 2, skills: ["athletics", "insight", "intimidation", "medicine", "persuasion", "religion"], color: "#ffe58f", blurb: "Heiliger Krieger, an einen Eid gebunden." },
  { name: "Waldläufer", kit: "Schuppenpanzer, 2 Kurzschwerter, Langbogen mit 20 Pfeilen, Entdeckerausrüstung", armor: "Schuppenpanzer", ac: (m) => 14 + Math.min(m.dex, 2), die: 10, saves: ["str", "dex"], primary: ["dex", "wis", "con"], pick: 3, skills: ["animal", "athletics", "insight", "investigation", "nature", "perception", "stealth", "survival"], color: "#8be06f", blurb: "Spurenleser und Jäger der Wildnis." },
  { name: "Schurke", kit: "Lederrüstung, 2 Dolche, Kurzschwert, Kurzbogen mit 20 Pfeilen, Diebeswerkzeug", armor: "Lederrüstung", ac: (m) => 11 + m.dex, die: 8, saves: ["dex", "int"], primary: ["dex", "int", "con"], pick: 4, skills: ["acrobatics", "athletics", "deception", "insight", "intimidation", "investigation", "perception", "persuasion", "sleight", "stealth"], color: "#b0b6ff", blurb: "Aus dem Schatten, präzise und gerissen." },
  { name: "Zauberer", kit: "Speer, 2 Dolche, arkaner Fokus, Gewölbeforscherausrüstung", armor: "ungerüstet", ac: (m) => 10 + m.dex, die: 6, saves: ["con", "cha"], primary: ["cha", "con", "dex"], pick: 2, skills: ["arcana", "deception", "insight", "intimidation", "persuasion", "religion"], color: "#ff7a5c", blurb: "Angeborene Magie im Blut." },
  { name: "Hexenmeister", kit: "Lederrüstung, Sichel, 2 Dolche, arkaner Fokus, Gelehrtenausrüstung", armor: "Lederrüstung", ac: (m) => 11 + m.dex, die: 8, saves: ["wis", "cha"], primary: ["cha", "con", "dex"], pick: 2, skills: ["arcana", "deception", "history", "intimidation", "investigation", "nature", "religion"], color: "#b56cff", blurb: "Macht aus einem Pakt mit einem Mächtigen." },
  { name: "Magier", kit: "Kampfstab, 2 Dolche, Zauberbuch, arkaner Fokus, Gelehrtenausrüstung", armor: "ungerüstet", ac: (m) => 10 + m.dex, die: 6, saves: ["int", "wis"], primary: ["int", "con", "dex"], pick: 2, skills: ["arcana", "history", "insight", "investigation", "medicine", "nature", "religion"], color: "#62a8ff", blurb: "Gelehrter der arkanen Künste." },
];

export const SPECIES = [
  { name: "Mensch", speed: 30, trait: "Einfallsreich, eine zusätzliche Fertigkeit und ein Talent." },
  { name: "Elf", speed: 30, trait: "Dunkelsicht, Trance statt Schlaf, scharfe Sinne." },
  { name: "Zwerg", speed: 30, trait: "Dunkelsicht, Giftresistenz, zäh wie Stein." },
  { name: "Halbling", speed: 30, trait: "Glückspilz: eine gewürfelte 1 darf wiederholt werden." },
  { name: "Gnom", speed: 30, trait: "Dunkelsicht, gnomische Gerissenheit gegen Magie." },
  { name: "Drachenblütiger", speed: 30, trait: "Odemwaffe und Schadensresistenz deiner Drachenahnen." },
  { name: "Tiefling", speed: 30, trait: "Dunkelsicht, höllisches Erbe mit kleinen Zaubern." },
  { name: "Ork", speed: 30, trait: "Dunkelsicht, Adrenalinschub, unerbittliche Ausdauer." },
  { name: "Goliath", speed: 35, trait: "Riesenerbe, groß und kräftig." },
];

export const CONDITIONS = ["Blind", "Bezaubert", "Taub", "Erschöpft", "Verängstigt", "Gepackt", "Kampfunfähig", "Unsichtbar", "Gelähmt", "Versteinert", "Vergiftet", "Liegend", "Festgesetzt", "Betäubt", "Bewusstlos", "Konzentration"];

// Stat blocks condensed from the SRD. `art` picks the portrait in
// MonsterArt.jsx; attacks roll straight from the selection card.
const atk = (name, hit, dmg, note = "") => ({ name, hit, dmg, note });
const save = (name, dc, dmg, note = "") => ({ name, save: dc, dmg, note });
export const MONSTERS = [
  { name: "Riesenratte", art: "rat", max_hp: 7, ac: 12, init_bonus: 2, color: "#a07e6a", cr: "1/8", type: "Tier", lore: "Kanalplage mit gelben Zähnen. Allein harmlos, im Rudel lästig.", attacks: [atk("Biss", 4, "1d4+2")] },
  { name: "Kobold", art: "kobold", max_hp: 5, ac: 12, init_bonus: 2, color: "#d9844a", cr: "1/8", type: "Drache", lore: "Kleine Drachenverehrer. Feige allein, mit Rudeltaktik gefährlich: Vorteil, wenn ein Verbündeter neben dem Ziel steht.", attacks: [atk("Dolch", 4, "1d4+2"), atk("Schleuder", 4, "1d4+2", "Reichweite 9/36 m")] },
  { name: "Kultist", art: "cultist", max_hp: 9, ac: 12, init_bonus: 1, color: "#c23a4a", cr: "1/8", type: "Humanoid", lore: "Fanatische Diener finsterer Mächte. Dunkle Hingabe: Vorteil gegen Bezaubert und Verängstigt.", attacks: [atk("Ritualdolch", 3, "1d6+1")] },
  { name: "Bandit", art: "bandit", max_hp: 11, ac: 12, init_bonus: 1, color: "#c9a26b", cr: "1/8", type: "Humanoid", lore: "Straßenräuber und Halsabschneider, die selten allein auftauchen.", attacks: [atk("Krummsäbel", 3, "1d6+1"), atk("Leichte Armbrust", 3, "1d8+1", "Reichweite 24/96 m")] },
  { name: "Goblin", art: "goblin", max_hp: 7, ac: 15, init_bonus: 2, color: "#7bd35a", cr: "1/4", type: "Feenwesen", lore: "Flinke Plünderer. Flinke Flucht: Rückzug oder Verstecken als Bonusaktion.", attacks: [atk("Krummsäbel", 4, "1d6+2"), atk("Kurzbogen", 4, "1d6+2", "Reichweite 24/96 m")] },
  { name: "Wolf", art: "wolf", max_hp: 11, ac: 13, init_bonus: 2, color: "#9aa3b5", cr: "1/4", type: "Tier", lore: "Jagt im Rudel und reißt Beute zu Boden.", attacks: [atk("Biss", 4, "1d6+2", "Ziel: STÄ-Rettungswurf SG 11 oder liegend")] },
  { name: "Skelett", art: "skeleton", max_hp: 13, ac: 13, init_bonus: 2, color: "#e8e2cf", cr: "1/4", type: "Untoter", lore: "Belebte Knochen ohne eigenen Willen. Verwundbar gegen Wuchtschaden, immun gegen Gift.", attacks: [atk("Kurzschwert", 4, "1d6+2"), atk("Kurzbogen", 4, "1d6+2")] },
  { name: "Zombie", art: "zombie", max_hp: 22, ac: 8, init_bonus: -2, color: "#7f9c6a", cr: "1/4", type: "Untoter", lore: "Untote Ausdauer: Fällt er auf 0 TP, darf er einen KON-Rettungswurf (SG 5 + Schaden) machen und bleibt mit 1 TP stehen.", attacks: [atk("Hieb", 3, "1d6+1")] },
  { name: "Ork", art: "orc", max_hp: 15, ac: 13, init_bonus: 1, color: "#6fae4f", cr: "1/2", type: "Humanoid", lore: "Aggressiv: Kann als Bonusaktion auf einen sichtbaren Feind zustürmen.", attacks: [atk("Großaxt", 5, "1d12+3"), atk("Wurfspeer", 5, "1d6+3")] },
  { name: "Ghul", art: "ghoul", max_hp: 22, ac: 12, init_bonus: 2, color: "#a3b08a", cr: "1", type: "Untoter", lore: "Leichenfresser aus Grüften. Ihre Klauen lähmen alles außer Elfen.", attacks: [atk("Biss", 2, "2d6+2"), atk("Klauen", 4, "2d4+2", "KON-Rettungswurf SG 10 oder 1 Minute gelähmt")] },
  { name: "Harpyie", art: "harpy", max_hp: 38, ac: 11, init_bonus: 1, color: "#c98bd8", cr: "1", type: "Monstrosität", lore: "Ihr Lockgesang treibt Wanderer in Abgründe und Fallen.", attacks: [atk("Klauen", 3, "2d4+1"), save("Lockgesang", "WEI SG 11", "", "Bezaubert, bewegt sich auf die Harpyie zu")] },
  { name: "Riesenspinne", art: "spider", max_hp: 26, ac: 14, init_bonus: 3, color: "#5b4a6e", cr: "1", size: 2, type: "Tier", lore: "Klettert an Wänden und Decken und spürt jede Erschütterung im Netz.", attacks: [atk("Biss", 5, "1d8+3", "dazu 2d8 Gift, KON-RW SG 11 für die Hälfte"), save("Netz", "STÄ SG 12", "", "Ziel ist festgesetzt")] },
  { name: "Gallertwürfel", art: "cube", max_hp: 84, ac: 6, init_bonus: -4, color: "#4fe0c0", cr: "2", size: 2, type: "Schlick", lore: "Fast durchsichtig. Gleitet durch Gänge und verschlingt, was im Weg steht.", attacks: [atk("Scheinfuß", 4, "3d6", "Säureschaden"), save("Verschlingen", "GES SG 12", "3d6", "Säure, Ziel steckt im Würfel fest")] },
  { name: "Oger", art: "ogre", max_hp: 59, ac: 11, init_bonus: -1, color: "#c08a5a", cr: "2", size: 2, type: "Riese", lore: "Dumm, hungrig und furchtbar stark.", attacks: [atk("Großkeule", 6, "2d8+4"), atk("Wurfspeer", 6, "2d6+4")] },
  { name: "Mimik", art: "mimic", max_hp: 58, ac: 12, init_bonus: 1, color: "#b07a3a", cr: "2", type: "Monstrosität", lore: "Tarnt sich als Truhe, Tür oder Schatz und klebt an allem fest.", attacks: [atk("Scheinfuß", 5, "1d8+3", "Ziel klebt fest"), atk("Biss", 5, "1d8+3", "dazu 1d8 Säure")] },
  { name: "Eulenbär", art: "owlbear", max_hp: 59, ac: 13, init_bonus: 1, color: "#8b6a4a", cr: "3", size: 2, type: "Monstrosität", lore: "Halb Eule, halb Bär, ganz schlechte Laune.", attacks: [atk("Schnabel", 7, "1d10+5"), atk("Klauen", 7, "2d8+5")] },
  { name: "Minotaurus", art: "minotaur", max_hp: 76, ac: 14, init_bonus: 0, color: "#9a5a3a", cr: "3", size: 2, type: "Monstrosität", lore: "Herr des Labyrinths. Stürmt er 3 m auf ein Ziel zu, trifft sein Horn mit 2d8 Extraschaden.", attacks: [atk("Großaxt", 6, "2d12+4"), atk("Hörner", 6, "2d8+4")] },
  { name: "Troll", art: "troll", max_hp: 84, ac: 15, init_bonus: 1, color: "#4f8a5a", cr: "5", size: 2, type: "Riese", lore: "Regeneriert 10 TP pro Zug, außer er hat Feuer- oder Säureschaden erlitten.", attacks: [atk("Biss", 7, "1d6+4"), atk("Klauen", 7, "2d6+4")] },
  { name: "Junger roter Drache", art: "dragon", max_hp: 178, ac: 18, init_bonus: 0, color: "#e2442f", cr: "10", size: 2, type: "Drache", lore: "Gierig, stolz und feuerspeiend. Sein Hort ist ihm heilig.", attacks: [atk("Biss", 10, "2d10+6", "dazu 1d6 Feuer"), atk("Klauen", 10, "2d6+6"), save("Feuerodem", "GES SG 17", "16d6", "Kegel 9 m, halber Schaden bei Erfolg")] },
  { name: "Vampir", art: "vampire", max_hp: 144, ac: 16, init_bonus: 4, color: "#d0213a", cr: "13", type: "Untoter", lore: "Untoter Adliger. Regeneriert, wird zu Nebel und meidet Sonnenlicht und fließendes Wasser.", attacks: [atk("Biss", 9, "1d6+4", "dazu 3d6 nekrotisch"), atk("Waffenloser Schlag", 9, "1d8+4")] },
  { name: "Erwachsener roter Drache", art: "dragon-elder", max_hp: 256, ac: 19, init_bonus: 0, color: "#ff3b2f", cr: "17", size: 3, type: "Drache", lore: "Ein Tyrann aus Feuer und Schuppen. Legendäre Aktionen am Ende fremder Züge.", attacks: [atk("Biss", 14, "2d10+8", "dazu 2d6 Feuer"), atk("Klauen", 14, "2d6+8"), save("Feuerodem", "GES SG 21", "18d6", "Kegel 18 m, halber Schaden bei Erfolg")] },
  { name: "Lich", art: "lich", max_hp: 135, ac: 17, init_bonus: 3, color: "#7ad0ff", cr: "21", type: "Untoter", lore: "Unsterblicher Erzmagier. Solange sein Seelengefäß existiert, kehrt er zurück.", attacks: [atk("Lähmende Berührung", 12, "3d6", "Kälte, KON-RW SG 18 oder gelähmt"), save("Feuerball", "GES SG 20", "8d6")] },
];

// Portraits for custom creatures, in picker order.
export const ART_CHOICES = [
  ...MONSTERS.map((m) => ({ id: m.art, name: m.name })),
  { id: "shadow", name: "Schattenwesen" }, { id: "demon", name: "Dämon" }, { id: "elemental", name: "Elementar" },
];
export const monsterFor = (creature) => MONSTERS.find((m) => m.name === (creature?.base || creature?.name)) || null;

export const DICE = [4, 6, 8, 10, 12, 20, 100];
export const STANDARD_ARRAY = [15, 14, 13, 12, 10, 8];
export const MAP_THEMES = [
  { id: "dungeon", name: "Verlies" }, { id: "cave", name: "Höhle" }, { id: "forest", name: "Wald" },
  { id: "tavern", name: "Taverne" }, { id: "castle", name: "Burg" }, { id: "plain", name: "Neutral" },
];

export const mod = (score) => Math.floor((Number(score || 10) - 10) / 2);
export const signed = (n) => (n >= 0 ? `+${n}` : `${n}`);
export const profBonus = (level) => 2 + Math.floor((Math.max(1, level) - 1) / 4);
export const classInfo = (name) => CLASSES.find((c) => c.name === name) || CLASSES[4];

export function suggestedHp(sheet) {
  const info = classInfo(sheet.char_class);
  const con = mod(sheet.abilities?.con);
  const perLevel = Math.floor(info.die / 2) + 1 + con;
  return Math.max(1, info.die + con + (Math.max(1, sheet.level) - 1) * Math.max(1, perLevel));
}

export function suggestedAc(sheet) {
  const m = Object.fromEntries(Object.entries(sheet.abilities || {}).map(([k, v]) => [k, mod(v)]));
  return classInfo(sheet.char_class).ac(m);
}

export function blankCharacter(username) {
  const info = CLASSES[4];
  const abilities = { str: 15, dex: 13, con: 14, int: 10, wis: 12, cha: 8 };
  const sheet = { name: username ? `${username}s Held` : "Neuer Held", species: "Mensch", char_class: info.name, subclass: "", level: 1, background: "", alignment: "",
    abilities, max_hp: 12, hp: 12, temp_hp: 0, ac: 16, speed: 30, skills: ["athletics", "perception"], saves: info.saves, inventory: info.kit,
    features: "", spells: "", notes: "", color: "#b56cff", avatar_url: "", gold: 10, death_saves: { ok: 0, fail: 0 } };
  return { ...sheet, max_hp: suggestedHp(sheet), hp: suggestedHp(sheet), ac: suggestedAc(sheet) };
}
