import json, sys
from jsonschema import Draft202012Validator
root = sys.argv[1]
schema = json.load(open(f"{root}/assets/data/schema/hadith_platform.schema.json"))
Draft202012Validator.check_schema(schema)
def check(path, defname=None):
    s = dict(schema)
    if defname:
        s = {"$schema": schema["$schema"], "$defs": schema["$defs"], "$ref": f"#/$defs/{defname}"}
    v = Draft202012Validator(s)
    data = json.load(open(f"{root}/{path}"))
    errs = sorted(v.iter_errors(data), key=lambda e: list(e.path))
    print(("OK  " if not errs else "FAIL"), path)
    for e in errs[:10]: print("   ", list(e.path), e.message[:200])
    return not errs
ok = all([
    check("assets/data/hadith/nawawi40/nawawi40_001.json"),
    check("assets/data/hadith/nawawi40/nawawi40_002.json"),
    check("assets/data/catalogs/narrators.json", "NarratorCatalog"),
    check("assets/data/catalogs/sources.json", "SourceCatalog"),
    check("assets/data/catalogs/journey_stations.json", "JourneyCatalog"),
    check("assets/data/curriculum/nawawi40_curriculum.json", "CurriculumManifest"),
    check("assets/data/catalogs/wisdom_bank.json", "WisdomCatalog"),
])
sys.exit(0 if ok else 1)
