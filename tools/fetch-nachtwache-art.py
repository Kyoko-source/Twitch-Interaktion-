"""Fetch pinned CC0 production assets; verify provider hashes and record provenance."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import urllib.request
import time

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "games/kinderparadies/assets"
HEADERS = {"User-Agent": "NachtwacheGameDevelopment/1.2"}
MODELS = ["SchoolChair_01", "wooden_bookshelf_worn", "cardboard_box_01",
          "desk_lamp_arm_01", "rubber_duck_toy", "hanging_industrial_lamp",
          "metal_office_desk", "power_box_01"]
MATERIALS = ["fabric_pattern_07", "rubberized_track", "fabric_leather_01",
             "painted_plaster_wall", "concrete_floor_worn_001"]

def get(url):
    for attempt in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=90) as response:
                return response.read()
        except OSError:
            if attempt == 3: raise
            time.sleep(attempt + 1)

def download(spec, destination):
    if destination.exists() and hashlib.md5(destination.read_bytes()).hexdigest() == spec["md5"]:
        data = destination.read_bytes()
    else:
        data = get(spec["url"])
        if hashlib.md5(data).hexdigest() != spec["md5"] or len(data) != spec["size"]:
            raise ValueError("Provider checksum/size mismatch: " + spec["url"])
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    return {"path": destination.relative_to(ASSETS).as_posix(), "url": spec["url"],
            "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}

def fetch_asset(item):
    kind, asset_id = item
    metadata = json.loads(get("https://api.polyhaven.com/files/" + asset_id))
    files = []
    if kind == "model":
        root = ASSETS / "models" / asset_id
        spec = metadata["gltf"]["2k"]["gltf"]
        files.append(download(spec, root / (asset_id + ".gltf")))
        for name, include in spec["include"].items():
            target = root / name
            if not target.resolve().is_relative_to(root.resolve()):
                raise ValueError("Invalid model dependency path")
            files.append(download(include, target))
    else:
        root = ASSETS / "pbr" / asset_id
        for channel, output in [("Diffuse" if "Diffuse" in metadata else "col_1", "albedo"), ("nor_gl", "normal"), ("Rough", "roughness")]:
            formats = metadata[channel]["2k"]
            fmt = "jpg" if "jpg" in formats else "png"
            files.append(download(formats[fmt], root / (output + "." + fmt)))
    print("Verified", asset_id, sum(f["bytes"] for f in files), flush=True)
    return {"id": asset_id, "kind": kind, "license": "CC0-1.0",
            "source": "https://polyhaven.com/a/" + asset_id, "files": files}

if __name__ == "__main__":
    jobs = [("model", asset_id) for asset_id in MODELS] + [("material", asset_id) for asset_id in MATERIALS]
    with ThreadPoolExecutor(max_workers=3) as pool:
        manifest = list(pool.map(fetch_asset, jobs))
    (ASSETS / "polyhaven-provenance.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf8")
    (ASSETS / "PolyHaven-CC0.txt").write_text(
        "Poly Haven assets are dedicated to the public domain under CC0 1.0.\n"
        "License: https://polyhaven.com/license\n"
        "Legal code: https://creativecommons.org/publicdomain/zero/1.0/legalcode\n"
        "Individual assets, original download URLs and SHA256 hashes: polyhaven-provenance.json.\n"
        "Godot-generated imports and modified geometry retain these source notices.\n", encoding="utf8")
