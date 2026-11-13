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

export const MONSTERS = [
  { name: "Kobold", max_hp: 5, ac: 12, init_bonus: 2, color: "#d9844a", cr: "1/8" },
  { name: "Goblin", max_hp: 7, ac: 15, init_bonus: 2, color: "#7bd35a", cr: "1/4" },
  { name: "Bandit", max_hp: 11, ac: 12, init_bonus: 1, color: "#c9a26b", cr: "1/8" },
  { name: "Wolf", max_hp: 11, ac: 13, init_bonus: 2, color: "#9aa3b5", cr: "1/4" },
  { name: "Skelett", max_hp: 13, ac: 13, init_bonus: 2, color: "#e8e2cf", cr: "1/4" },
  { name: "Zombie", max_hp: 22, ac: 8, init_bonus: -2, color: "#7f9c6a", cr: "1/4" },
  { name: "Ork", max_hp: 15, ac: 13, init_bonus: 1, color: "#6fae4f", cr: "1/2" },
  { name: "Ghul", max_hp: 22, ac: 12, init_bonus: 2, color: "#a3b08a", cr: "1" },
  { name: "Riesenspinne", max_hp: 26, ac: 14, init_bonus: 3, color: "#5b4a6e", cr: "1", size: 2 },
  { name: "Oger", max_hp: 59, ac: 11, init_bonus: -1, color: "#c08a5a", cr: "2", size: 2 },
  { name: "Eulenbär", max_hp: 59, ac: 13, init_bonus: 1, color: "#8b6a4a", cr: "3", size: 2 },
  { name: "Mimik", max_hp: 58, ac: 12, init_bonus: 1, color: "#b07a3a", cr: "2" },
  { name: "Troll", max_hp: 84, ac: 15, init_bonus: 1, color: "#4f8a5a", cr: "5", size: 2 },
  { name: "Junger roter Drache", max_hp: 178, ac: 18, init_bonus: 0, color: "#e2442f", cr: "10", size: 2 },
  { name: "Lich", max_hp: 135, ac: 17, init_bonus: 3, color: "#7ad0ff", cr: "21" },
  { name: "Erwachsener roter Drache", max_hp: 256, ac: 19, init_bonus: 0, color: "#ff3b2f", cr: "17", size: 3 },
];

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
