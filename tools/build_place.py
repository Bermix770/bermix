#!/usr/bin/env python3
"""Inject src/*.luau into the Roblox place file.

Usage: python3 tools/build_place.py [base.rbxlx] [out.rbxlx]
Defaults: place/MineRush.base.rbxlx -> MineRush.rbxlx

Edits are textual so the rest of the place file stays byte-identical.
"""
import re
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = {
    "Client": "Client.client.luau",
    "Config": "Config.luau",
    "GameServer": "GameServer.server.luau",
    "WorldBuilder": "WorldBuilder.luau",
    "ModelLibrary": "ModelLibrary.luau",
}

SOURCE_RE = re.compile(r'(<ProtectedString name="Source"><!\[CDATA\[)(.*?)(\]\]></ProtectedString>)(.*?)<string name="Name">([^<]*)</string>', re.S)


def load(name):
    src = (ROOT / "src" / SCRIPTS[name]).read_text()
    if "]]>" in src:
        raise SystemExit(f"{name}: source contains ']]>' which cannot live in CDATA")
    return src


def main():
    base = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "place" / "MineRush.base.rbxlx"
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "MineRush.rbxlx"
    xml = base.read_text()
    found = set()

    def repl(m):
        name = m.group(5)
        if name in SCRIPTS:
            found.add(name)
            return m.group(1) + load(name) + m.group(3) + m.group(4) + f'<string name="Name">{name}</string>'
        return m.group(0)

    xml = SOURCE_RE.sub(repl, xml)

    if "ModelLibrary" not in found:
        item = (
            '\n\t\t<Item class="ModuleScript" referent="RBXMODELLIBRARY0001">\n'
            "\t\t\t<Properties>\n"
            '\t\t\t\t<Content name="LinkedSource"><null></null></Content>\n'
            f'\t\t\t\t<ProtectedString name="Source"><![CDATA[{load("ModelLibrary")}]]></ProtectedString>\n'
            '\t\t\t\t<BinaryString name="AttributesSerialize"></BinaryString>\n'
            '\t\t\t\t<string name="Name">ModelLibrary</string>\n'
            f'\t\t\t\t<string name="ScriptGuid">{{{str(uuid.uuid5(uuid.NAMESPACE_DNS, "minerush.modellibrary")).upper()}}}</string>\n'
            "\t\t\t</Properties>\n"
            "\t\t</Item>"
        )
        rs = xml.index('class="ReplicatedStorage"')
        props_end = xml.index("</Properties>", rs) + len("</Properties>")
        xml = xml[:props_end] + item + xml[props_end:]
        found.add("ModelLibrary")

    missing = set(SCRIPTS) - found
    if missing:
        raise SystemExit(f"scripts not found in place: {sorted(missing)}")

    # Future lighting (Enum.Technology.Future = 4) and the 2022 material textures
    lighting = xml.index('class="Lighting"')
    tech = re.compile(r'<token name="Technology">\d+</token>')
    m = tech.search(xml, lighting)
    xml = xml[: m.start()] + '<token name="Technology">4</token>' + xml[m.end():]
    xml = xml.replace('<bool name="Use2022MaterialsXml">false</bool>', '<bool name="Use2022MaterialsXml">true</bool>')

    out.write_text(xml)
    print(f"wrote {out} ({len(xml)} bytes), scripts: {sorted(found)}")


if __name__ == "__main__":
    main()
