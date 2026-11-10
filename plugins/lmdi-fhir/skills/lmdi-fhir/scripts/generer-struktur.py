#!/usr/bin/env python3
"""Genererer references/struktur.md fra LMDI sine StructureDefinition-filer.

Bruk:
    python generer-struktur.py <katalog med StructureDefinition-*.json> [utfil]

Katalogen kan være den publiserte IG-en (LMDI/output eller utpakket package.tgz, med
snapshot) eller LMDI/fsh-generated/resources (uten snapshot). Uten snapshot mangler
linja «Påkrevd inkl. FHIR-basis», og en kardinalitetsgrense som ikke er endret i
profilen vises som «·».

IG-versjonen leses fra StructureDefinitionene. SUSHI setter ikke `version` på dem (det
gjør IG Publisher), så da brukes versjonen i ImplementationGuide-*.json i samme katalog.

Bare standardbiblioteket. Utdata er deterministisk, slik at `git diff` på struktur.md
viser nøyaktig hva som er endret i profilene.
"""
import glob
import json
import os
import sys

STRUKTURNOKLER = ("min", "max", "mustSupport", "type", "binding", "slicing", "constraint")


def siste(url):
    return url.rstrip("/").split("/")[-1].split("|")[0]


def celle(tekst):
    return str(tekst).replace("|", "\\|").replace("\n", " ")


def fast_verdi(el):
    ut = []
    for nokkel in sorted(el):
        if nokkel.startswith(("fixed", "pattern")):
            verdi = el[nokkel]
            if not isinstance(verdi, str):
                verdi = json.dumps(verdi, ensure_ascii=False, sort_keys=True)
            ut.append("`%s`" % verdi)
    return ", ".join(ut)


def typer(el):
    ut = []
    for t in el.get("type", []):
        kode = t.get("code", "")
        if kode.startswith("http://hl7.org/fhirpath/"):
            continue
        mal = [siste(p) for p in t.get("targetProfile", [])]
        profiler = [siste(p) for p in t.get("profile", [])]
        if mal:
            ut.append("%s(%s)" % (kode, " | ".join(mal)))
        elif profiler:
            ut.append("%s: %s" % (kode, ", ".join(profiler)))
        else:
            ut.append(kode)
    return ", ".join(ut)


def binding(el):
    b = el.get("binding")
    if not b:
        return ""
    return "%s: `%s`" % (b.get("strength", "?"), b.get("valueSet", "(ingen valueSet)"))


def slicing(el):
    s = el.get("slicing")
    if not s:
        return ""
    disk = ", ".join("%s:%s" % (d.get("type"), d.get("path")) for d in s.get("discriminator", []))
    return "slicing %s (%s)" % (s.get("rules", "?"), disk)


def egne_invarianter(el, sd_url):
    return [c for c in el.get("constraint", []) if c.get("source", sd_url) == sd_url]


def kardinalitet(el, snap):
    s = snap.get(el["id"], {})
    mn = el.get("min", s.get("min", "·"))
    mx = el.get("max", s.get("max", "·"))
    return "%s..%s" % (mn, mx)


def kortsti(el_id, rot):
    return el_id[len(rot) + 1:] if el_id.startswith(rot + ".") else el_id


def skriv_sd(sd, ut):
    url = sd["url"]
    rot = sd["type"]
    diff = sd["differential"]["element"]
    snap = {e["id"]: e for e in sd.get("snapshot", {}).get("element", [])}

    ut.append("## %s (`%s`)" % (sd.get("title", sd["name"]), sd["id"]))
    ut.append("")
    ut.append("- Canonical: `%s`" % url)
    ut.append("- Type: `%s`, parent: `%s`" % (rot, sd.get("baseDefinition", "")))
    if rot == "Extension":
        kontekst = ", ".join("`%s`" % c.get("expression") for c in sd.get("context", []))
        ut.append("- Context: %s" % kontekst)
    elif snap:
        pakrevd = [
            "`%s` %s..%s" % (kortsti(e["id"], rot), e.get("min"), e.get("max"))
            for e in sd["snapshot"]["element"]
            if e.get("min", 0) >= 1 and e["id"].count(".") == 1 and ":" not in e["id"]
        ]
        ut.append("- Påkrevd inkl. FHIR-basis (toppnivå): %s" % (", ".join(pakrevd) or "ingen"))

    deaktivert = [kortsti(e["id"], rot) for e in diff if e.get("max") == "0"]
    if deaktivert:
        ut.append("- Deaktivert (0..0): %s" % ", ".join("`%s`" % d for d in deaktivert))
    ut.append("")

    rader = []
    invarianter = []
    for el in diff:
        egne = egne_invarianter(el, url)
        invarianter.extend(c for c in egne if c["key"] not in {i["key"] for i in invarianter})
        if el.get("max") == "0":
            continue
        fast = fast_verdi(el)
        if not fast and not any(k in el for k in STRUKTURNOKLER):
            continue
        if not fast and "constraint" in el and not egne and not any(
            k in el for k in STRUKTURNOKLER if k != "constraint"
        ):
            continue
        annet = "; ".join(x for x in (slicing(el), ", ".join("`%s`" % c["key"] for c in egne)) if x)
        rader.append("| `%s` | %s | %s | %s | %s | %s | %s |" % (
            celle(kortsti(el["id"], rot)),
            "" if el["id"] == rot else kardinalitet(el, snap),
            "MS" if el.get("mustSupport") else "",
            celle(typer(el)),
            celle(binding(el)),
            celle(fast),
            celle(annet),
        ))
    if rader:
        ut.append("| Element | Kard. | MS | Type / mål | Binding | Fast verdi | Slicing / invariant |")
        ut.append("|---|---|---|---|---|---|---|")
        ut.extend(rader)
        ut.append("")
    if invarianter:
        ut.append("Invarianter:")
        ut.append("")
        for c in invarianter:
            ut.append("- `%s` (%s): %s. FHIRPath: `%s`" % (
                c["key"], c.get("severity"), c.get("human", "").rstrip("."), " ".join(c.get("expression", "").split())))
        ut.append("")


def les_json(katalog, monster):
    ut = []
    for sti in sorted(glob.glob(os.path.join(katalog, monster))):
        with open(sti, encoding="utf-8") as f:
            ut.append(json.load(f))
    return ut


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    katalog = sys.argv[1]
    standard_ut = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "references", "struktur.md")
    utfil = sys.argv[2] if len(sys.argv) > 2 else standard_ut

    sder = les_json(katalog, "StructureDefinition-*.json")
    if not sder:
        sys.exit("Fant ingen StructureDefinition-*.json i %s" % katalog)

    versjoner = sorted({sd["version"] for sd in sder if sd.get("version")})
    if not versjoner:
        igs = les_json(katalog, "ImplementationGuide-*.json")
        versjoner = sorted({ig["version"] for ig in igs if ig.get("version")})
    if not versjoner:
        sys.exit("Fant ingen IG-versjon i StructureDefinition-*.json eller ImplementationGuide-*.json i %s" % katalog)
    profiler = sorted((sd for sd in sder if sd["type"] != "Extension"), key=lambda s: s["id"])
    extensions = sorted((sd for sd in sder if sd["type"] == "Extension"), key=lambda s: s["id"])

    ut = [
        "# Struktur — generert fra StructureDefinition",
        "",
        "**Generert av `scripts/generer-struktur.py`. Ikke rediger for hånd.** IG-versjon: %s." % ", ".join(versjoner),
        "",
        "Fila viser det LMDI endrer i forhold til parent (differential): kardinalitet, MustSupport,",
        "typer og referansemål, bindinger, faste verdier, slicing og invarianter. Elementer som ikke",
        "står her, arves uendret fra parent. Ved motstrid med de håndskrevne referansefilene gjelder",
        "denne fila. Forklaring, praksis og bruksregler står i `profiler.md` og `extensions.md`.",
        "",
        "Elementnavn med kolon er slices (`code.coding:ICD10`). «·» betyr at grensen ikke er endret",
        "i profilen og at snapshot manglet da fila ble generert.",
        "",
        "# Profiler",
        "",
    ]
    for sd in profiler:
        skriv_sd(sd, ut)
    ut += ["# Extensions", ""]
    for sd in extensions:
        skriv_sd(sd, ut)

    with open(utfil, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(ut).rstrip("\n") + "\n")
    print("Skrev %s (%d profiler, %d extensions, IG %s)" % (
        os.path.normpath(utfil), len(profiler), len(extensions), ", ".join(versjoner)))


if __name__ == "__main__":
    main()
