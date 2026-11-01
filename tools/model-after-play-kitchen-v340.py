"""Rebuild the original kitchen with removable hardware and separate wear surfaces.

Preserve the established dimensions/collisions. Runtime supplies the five
different replacement handles; merging them into the old steel object would
leave duplicate handles behind. No new third-party model or textures.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
original = ROOT / 'tools/model-after-play-kitchen-v260.py'
source = original.read_text('utf-8')
changes = {
    "OUT=ASSETS/'kitchen-v260'": "OUT=ASSETS/'craft-v340'",
    "# Long west-wall units.": "cabinet=mat('Water damaged cabinet panels',(.21,.27,.225),.16,.79)\nworktop=mat('Hand polished worktops',(.30,.34,.31),.82,.43)\n\n# Long west-wall units.",
    "(.024,.60,.92),enamel,.018)": "(.024,.60,.92),cabinet,.018)",
    "    handle('Cabinet handle',(-16.12,.80,z),'z',.27)": "    # The five separately repairable handles are authored at runtime.",
    "(1.14,.08,zb-za),steel,.026)": "(1.14,.08,zb-za),worktop,.026)",
    "(.11,.08,1.02),steel,.014)": "(.11,.08,1.02),worktop,.014)",
    "[enamel,cream,steel,black,rust,glass,white]": "[enamel,cream,steel,black,rust,glass,white,cabinet,worktop]",
}
for old, new in changes.items():
    assert source.count(old) == 1, old
    source = source.replace(old, new)
exec(compile(source, str(original), 'exec'), {'__file__': str(original)})
