#!/usr/bin/env python3
"""Kontrollerer skillene i marketplacen før de speiles til GitHub.

Bruk (fra hvor som helst):
    python scripts/sjekk-skills.py

Sjekker for alle pluginer:
  - .claude-plugin/marketplace.json lar seg lese, og hver plugin har version og en source som finnes
  - frontmatteren i hver SKILL.md lar seg parse, har name og description, og name = katalognavnet
    (ugyldig frontmatter gjør at skillen ikke tilbys, uten feilmelding)
  - references/-filer nevnt i SKILL.md finnes, og alle filer i references/ er nevnt i SKILL.md
  - evals/evals.json lar seg lese og har skills, query og expected_behavior

Sjekker i tillegg for lmdi-fhir at LMDI-versjonen og commit-pinnen bare har én verdi:
  - versjonen i description = versjonen i **Versjon**-linja i SKILL.md
  - version i marketplace.json er <LMDI-versjon>-<løpenummer>
  - references/struktur.md er generert fra samme versjon
  - alle fulle commit-hasher i SKILL.md og UPDATE.md er pinnen

Avslutter med kode 1 ved feil. Krever PyYAML (python -m pip install pyyaml), fordi frontmatteren
må leses av en ordentlig YAML-parser for at kontrollen skal være til å stole på.
"""
import glob
import json
import os
import re
import sys

try:
    import yaml
except ImportError:
    sys.exit("sjekk-skills.py krever PyYAML. Installer med: python -m pip install pyyaml")

ROT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
feil = []


def les(sti):
    with open(sti, encoding="utf-8") as f:
        return f.read()


def rel(sti):
    return os.path.relpath(sti, ROT).replace(os.sep, "/")


def frontmatter(sti):
    tekst = les(sti)
    m = re.match(r"^---\r?\n(.*?)\r?\n---\r?\n", tekst, re.S)
    if not m:
        feil.append("%s: mangler frontmatter" % rel(sti))
        return {}, tekst
    try:
        data = yaml.safe_load(m.group(1))
    except yaml.YAMLError as e:
        feil.append("%s: frontmatter lar seg ikke parse: %s" % (rel(sti), " ".join(str(e).split())))
        return {}, tekst
    if not isinstance(data, dict):
        feil.append("%s: frontmatter er ikke en YAML-mapping" % rel(sti))
        return {}, tekst
    return data, tekst


def sjekk_skill(skill_dir):
    navn = os.path.basename(skill_dir)
    skill_md = os.path.join(skill_dir, "SKILL.md")
    fm, tekst = frontmatter(skill_md)
    if fm:
        if fm.get("name") != navn:
            feil.append("%s: name er «%s», forventet «%s»" % (rel(skill_md), fm.get("name"), navn))
        if not str(fm.get("description") or "").strip():
            feil.append("%s: mangler description" % rel(skill_md))

    nevnt = set(re.findall(r"references/([A-Za-z0-9_.-]+\.md)", tekst))
    finnes = {os.path.basename(p) for p in glob.glob(os.path.join(skill_dir, "references", "*.md"))}
    for fil in sorted(nevnt - finnes):
        feil.append("%s: viser til references/%s, som ikke finnes" % (rel(skill_md), fil))
    for fil in sorted(finnes - nevnt):
        feil.append("%s: references/%s er ikke nevnt i SKILL.md" % (rel(skill_md), fil))

    evals = os.path.join(skill_dir, "evals", "evals.json")
    if os.path.exists(evals):
        try:
            data = json.loads(les(evals))
        except ValueError as e:
            feil.append("%s: ugyldig JSON: %s" % (rel(evals), e))
            data = []
        for i, e in enumerate(data):
            if not (isinstance(e, dict) and e.get("skills") and e.get("query") and e.get("expected_behavior")):
                feil.append("%s: oppføring %d mangler skills, query eller expected_behavior" % (rel(evals), i))
    return fm, tekst


def sjekk_lmdi(skill_dir, fm, tekst, plugin):
    skill_md = rel(os.path.join(skill_dir, "SKILL.md"))
    m = re.search(r"\*\*Versjon\*\*: IG `([0-9.]+)`.*?commit `([0-9a-f]{40})`", tekst)
    if not m:
        feil.append("%s: fant ikke linja «**Versjon**: IG `x.y.z` … commit `<40 hex>`»" % skill_md)
        return
    versjon, pinne = m.groups()

    i_beskrivelse = re.findall(r"\b\d+\.\d+\.\d+\b", str(fm.get("description", "")))
    if i_beskrivelse != [versjon]:
        feil.append("%s: description har versjon %s, Versjon-linja har %s" % (skill_md, i_beskrivelse or "ingen", versjon))

    if not re.fullmatch(re.escape(versjon) + r"-[1-9]\d*", plugin.get("version", "")):
        feil.append("marketplace.json: lmdi-fhir har version «%s», forventet «%s-<løpenummer>»" % (plugin.get("version"), versjon))

    struktur = os.path.join(skill_dir, "references", "struktur.md")
    if os.path.exists(struktur) and "IG-versjon: %s." % versjon not in les(struktur):
        feil.append("%s: ikke generert fra IG %s. Kjør scripts/generer-struktur.py" % (rel(struktur), versjon))

    for fil in ("SKILL.md", "UPDATE.md"):
        sti = os.path.join(skill_dir, fil)
        if not os.path.exists(sti):
            continue
        for h in sorted(set(re.findall(r"\b[0-9a-f]{40}\b", les(sti))) - {pinne}):
            feil.append("%s: commit-hash %s er ikke pinnen (%s)" % (rel(sti), h[:9], pinne[:9]))


def main():
    mp_sti = os.path.join(ROT, ".claude-plugin", "marketplace.json")
    try:
        marketplace = json.loads(les(mp_sti))
    except ValueError as e:
        sys.exit("marketplace.json: ugyldig JSON: %s" % e)

    antall = 0
    for plugin in marketplace.get("plugins", []):
        navn = plugin.get("name", "?")
        kilde = os.path.normpath(os.path.join(ROT, plugin.get("source", "")))
        if not plugin.get("version"):
            feil.append("marketplace.json: %s mangler version" % navn)
        if not os.path.isdir(kilde):
            feil.append("marketplace.json: source for %s finnes ikke: %s" % (navn, plugin.get("source")))
            continue
        for skill_md in sorted(glob.glob(os.path.join(kilde, "skills", "*", "SKILL.md"))):
            skill_dir = os.path.dirname(skill_md)
            fm, tekst = sjekk_skill(skill_dir)
            antall += 1
            if os.path.basename(skill_dir) == "lmdi-fhir":
                sjekk_lmdi(skill_dir, fm, tekst, plugin)

    if feil:
        print("FEIL (%d):" % len(feil))
        for f in feil:
            print("  - " + f)
        sys.exit(1)
    print("OK: %d skills kontrollert" % antall)


if __name__ == "__main__":
    main()
