"""Original Nullsignal puzzles. Answers and per-room rules stay server-side."""
import random
from uuid import uuid4

MODULES = [
    ("wires", "Kabelmatrix"), ("glyphs", "Glyphenfeld"),
    ("frequency", "Frequenzkern"), ("sequence", "Impulsfolge"),
    ("relays", "Relaiswerk"), ("sliders", "Phasenregler"),
    ("pipes", "Kreislauf"), ("vectors", "Vektorschloss"),
]
MISSIONS = {
    "contact": {"id": "contact", "name": "Erstkontakt", "modules": 3, "seconds": 180, "reward": 6, "level": "Einstieg"},
    "incident": {"id": "incident", "name": "Störfall", "modules": 6, "seconds": 300, "reward": 12, "level": "Standard"},
    "blackout": {"id": "blackout", "name": "Blackout", "modules": 8, "seconds": 360, "reward": 18, "level": "Experte"},
}
COLORS = {"red": "Rot", "blue": "Blau", "yellow": "Gelb", "white": "Weiß", "purple": "Violett", "green": "Grün"}
GLYPHS = ["hex", "diamond", "triangle", "cross", "dots", "wave", "orbit", "hourglass", "stairs", "eye", "fork", "chevron"]


def generate(mission, seed=None):
    rng = random.Random(seed if seed is not None else uuid4().int)
    serial = f"NS-{rng.randrange(1000, 9999)}"
    digit = int(serial[-1])
    facts = {"serial": serial, "coolant": rng.choice(["KALT", "WARM"]), "voltage": rng.choice([18, 24])}
    modules = []
    for kind, name in MODULES[:MISSIONS[mission]["modules"]]:
        item = {"id": kind, "kind": kind, "name": name, "solved": False, "progress": [], "data": {}, "manual": {}}
        data, manual = item["data"], item["manual"]
        if kind == "wires":
            wires = [rng.choice(list(COLORS)) for _ in range(rng.randint(4, 6))]
            priority, secondary = rng.sample(list(COLORS), 2)
            data.update(wires=wires, cut=[])
            manual.update(priority=priority, secondary=secondary, colors=COLORS)
            if len(wires) >= 5 and wires.count(priority) >= 2:
                answer = max(i for i, color in enumerate(wires) if color == priority)
            elif digit % 2 and secondary in wires:
                answer = wires.index(secondary)
            elif "red" not in wires:
                answer = 1
            else:
                answer = len(wires) - 1
            item["answer"] = answer
        elif kind == "glyphs":
            chosen = rng.sample(GLYPHS, 6)
            keys = rng.sample(chosen, 4)
            columns = [chosen]
            while len(columns) < 4:
                column = rng.sample(GLYPHS, 6)
                if not set(keys).issubset(column):
                    columns.append(column)
            rng.shuffle(columns)
            data["keys"] = keys
            manual["columns"] = columns
            item["answer"] = [glyph for glyph in chosen if glyph in keys]
        elif kind == "frequency":
            patterns = rng.sample(range(32), 9)
            channels = [round(72 + i * .5, 1) for i in range(9)]
            shuffled = rng.sample(channels, len(channels))
            rows = [{"pattern": f"{pattern:05b}", "frequency": channel} for pattern, channel in zip(patterns, shuffled)]
            chosen = rng.choice(rows)
            data.update(pattern=chosen["pattern"], channels=channels, tuning=0)
            manual["channels"] = rows
            item["answer"] = channels.index(chosen["frequency"])
        elif kind == "sequence":
            data.update(keys=rng.sample(list(range(1, 10)), 9), displays=[rng.randint(1, 4) for _ in range(3)])
            stages = []
            for stage in range(3):
                rows = []
                for _ in range(4):
                    rule = rng.choice(["position", "label"] + (["previous"] if stage else []))
                    rows.append({"rule": rule, "value": rng.randint(1, 9) if rule != "previous" else rng.randint(1, stage)})
                stages.append(rows)
            manual["stages"] = stages
        elif kind == "relays":
            pattern = rng.randrange(8)
            data.update(pattern=pattern, switches=[0, 0, 0])
            manual["rows"] = [{"pattern": i, "v18": [rng.randint(0, 1) for _ in range(3)], "v24": [rng.randint(0, 1) for _ in range(3)]} for i in range(8)]
            item["answer"] = manual["rows"][pattern][f"v{facts['voltage']}"]
        elif kind == "sliders":
            rows = [{"mark": mark, "values": [rng.randint(0, 4) for _ in range(3)]} for mark in ["AX", "BX", "CX", "DX", "EX", "FX"]]
            chosen = rng.choice(rows)
            data.update(mark=chosen["mark"], polarity=rng.choice(["+", "−"]), sliders=[2, 2, 2])
            manual["rows"] = rows
            item["answer"] = chosen["values"] if data["polarity"] == "+" else [4 - value for value in chosen["values"]]
        elif kind == "pipes":
            # Bits: north=1, east=2, south=4, west=8. Unused tiles are decoys.
            if facts["coolant"] == "KALT":
                route = {3: 9, 0: 6, 1: 10, 2: 12, 5: 3}
            else:
                route = {3: 12, 6: 3, 7: 10, 8: 9, 5: 6}
            base = [route.get(i, rng.choice([3, 6, 9, 12, 5, 10])) for i in range(9)]
            rotations = [rng.randrange(4) for _ in range(9)]
            data.update(tiles=base, rotations=rotations)
            item["answer"] = route
            manual.update(north=["A2", "A1", "B1", "C1", "C2"], south=["A2", "A3", "B3", "C3", "C2"])
        elif kind == "vectors":
            numbers = [rng.randint(10, 49) for _ in range(3)]
            weights = [rng.randint(1, 3) for _ in range(4)]
            data.update(numbers=numbers, entered="")
            manual["weights"] = weights
            a, b, c = numbers
            item["answer"] = "".join(str(value % 10) for value in [weights[0]*a+b, weights[1]*b+c, weights[2]*c+a, weights[3]*digit+b])
        modules.append(item)
    return {**facts, "modules": modules}


def rotate(mask, turns):
    for _ in range(turns % 4):
        mask = ((mask << 1) & 15) | (mask >> 3)
    return mask


def apply_action(module, operation, value):
    """Returns good/bad/neutral; malformed or impossible operations are errors."""
    data, kind, progress = module["data"], module["kind"], module["progress"]
    def index(limit):
        if type(value) is not int or not 0 <= value < limit:
            raise ValueError("Ungültige Taste oder Position.")
        return value
    if kind == "wires" and operation == "cut":
        i = index(len(data["wires"]))
        if i in data["cut"]:
            return "neutral"
        data["cut"].append(i)
        good = i == module["answer"]
    elif kind == "glyphs" and operation == "press":
        i = index(4)
        if data["keys"][i] != module["answer"][len(progress)]:
            progress.clear()
            return "bad"
        progress.append(data["keys"][i])
        good = len(progress) == 4
        if not good:
            return "neutral"
    elif kind == "frequency" and operation == "tune":
        data["tuning"] = index(9)
        return "neutral"
    elif kind == "frequency" and operation == "submit":
        good = data["tuning"] == module["answer"]
    elif kind == "sequence" and operation == "press":
        i = index(9)
        stage = len(progress)
        rule = module["manual"]["stages"][stage][data["displays"][stage]-1]
        expected = rule["value"]-1 if rule["rule"] == "position" else data["keys"].index(rule["value"]) if rule["rule"] == "label" else progress[rule["value"]-1]
        if i != expected:
            progress.clear()
            return "bad"
        progress.append(i)
        good = len(progress) == 3
        if not good:
            return "neutral"
    elif kind == "relays" and operation == "toggle":
        i = index(3)
        data["switches"][i] = 1-data["switches"][i]
        return "neutral"
    elif kind == "relays" and operation == "submit":
        good = data["switches"] == module["answer"]
    elif kind == "sliders" and operation == "slide":
        if not isinstance(value, list) or len(value) != 2 or any(type(v) is not int for v in value) or not 0 <= value[0] < 3 or not 0 <= value[1] < 5:
            raise ValueError("Ungültige Reglerposition.")
        data["sliders"][value[0]] = value[1]
        return "neutral"
    elif kind == "sliders" and operation == "submit":
        good = data["sliders"] == module["answer"]
    elif kind == "pipes" and operation == "rotate":
        i = index(9)
        data["rotations"][i] = (data["rotations"][i]+1) % 4
        return "neutral"
    elif kind == "pipes" and operation == "submit":
        good = all(rotate(data["tiles"][int(i)], data["rotations"][int(i)]) == mask for i, mask in module["answer"].items())
    elif kind == "vectors" and operation == "digit":
        i = index(10)
        if len(data["entered"]) < 4:
            data["entered"] += str(i)
        return "neutral"
    elif kind == "vectors" and operation == "clear":
        data["entered"] = ""
        return "neutral"
    elif kind == "vectors" and operation == "submit":
        good = data["entered"] == module["answer"]
        if not good:
            data["entered"] = ""
    else:
        raise ValueError("Diese Aktion gibt es an diesem Modul nicht.")
    if good:
        module["solved"] = True
    return "good" if good else "bad"
