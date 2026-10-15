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
import glob, os
hadith_files = sorted(
    os.path.relpath(path, root)
    for path in glob.glob(f"{root}/assets/data/hadith/nawawi40/nawawi40_*.json")
)
adhkar_files = sorted(
    os.path.relpath(path, root)
    for path in glob.glob(f"{root}/assets/data/adhkar/*.json")
)
sunan_files = sorted(
    os.path.relpath(path, root)
    for path in glob.glob(f"{root}/assets/data/sunan/*.json")
)
ok = all([
    *[check(path) for path in hadith_files],
    check("assets/data/catalogs/narrators.json", "NarratorCatalog"),
    check("assets/data/catalogs/sources.json", "SourceCatalog"),
    check("assets/data/seerah_dataset.json", "SeerahDataset"),
    *[check(path, "AdhkarCatalog") for path in adhkar_files],
    *[check(path, "SunanCatalog") for path in sunan_files],
    check("assets/data/curriculum/nawawi40_curriculum.json", "CurriculumManifest"),
    check("assets/data/catalogs/wisdom_bank.json", "WisdomCatalog"),
])
sys.exit(0 if ok else 1)
