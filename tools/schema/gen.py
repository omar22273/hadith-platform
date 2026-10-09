"""Generate the JSON Schema and the Dart immutable models from spec.py."""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from spec import ENUMS, MODELS, FILE_DOCS, FILE_DIRS, DEFAULT_DIR, Model, Enum  # noqa: E402
from extras import EXTRAS, EXTRA_IMPORTS  # noqa: E402

ROOT = sys.argv[1]
LIB_DIR = os.path.join(ROOT, "lib")
JSON_READER = os.path.join(LIB_DIR, "core/json/json_reader.dart")
SCHEMA_PATH = os.path.join(ROOT, "assets/data/schema/hadith_platform.schema.json")

MODEL_BY_NAME = {m.name: m for m in MODELS}
ENUM_BY_NAME = {e.name: e for e in ENUMS}


def parse_type(t):
    nullable = t.endswith("?")
    base = t[:-1] if nullable else t
    m = re.fullmatch(r"List<(.+)>", base)
    if m:
        return {"kind": "list", "item": m.group(1), "nullable": nullable}
    if base.startswith("E:"):
        return {"kind": "enum", "name": base[2:], "nullable": nullable}
    if base in ("String", "int", "double", "bool"):
        return {"kind": "prim", "name": base, "nullable": nullable}
    return {"kind": "model", "name": base, "nullable": nullable}


def dart_type(t):
    p = parse_type(t)
    q = "?" if p["nullable"] else ""
    if p["kind"] == "list":
        return f"List<{p['item']}>{q}"
    return f"{p['name']}{q}"


# ------------------------------------------------------------------ schema
def schema_for_field(f):
    p = parse_type(f.type)
    extra = {k: v for k, v in f.schema.items()}
    if p["kind"] == "prim":
        jt = {"String": "string", "int": "integer", "double": "number", "bool": "boolean"}[p["name"]]
        s = {"type": [jt, "null"] if p["nullable"] else jt}
        if p["name"] == "String" and not p["nullable"]:
            s["minLength"] = 1
        s.update(extra)
    elif p["kind"] == "enum":
        vals = [v[1] for v in ENUM_BY_NAME[p["name"]].values]
        s = {"enum": vals + ([None] if p["nullable"] else [])}
    elif p["kind"] == "model":
        ref = {"$ref": f"#/$defs/{p['name']}"}
        s = {"anyOf": [ref, {"type": "null"}]} if p["nullable"] else ref
    else:
        item = p["item"]
        if item in ("String",):
            items = {"type": "string", "minLength": 1}
        elif item in MODEL_BY_NAME:
            items = {"$ref": f"#/$defs/{item}"}
        else:
            raise ValueError(item)
        s = {"type": "array", "items": items}
        s.update(extra)
    s["description"] = f.doc
    return s


def build_schema():
    defs = {}
    for m in MODELS:
        defs[m.name] = {
            "type": "object",
            "description": m.doc,
            "additionalProperties": False,
            "required": [f.name for f in m.fields],
            "properties": {f.name: schema_for_field(f) for f in m.fields},
        }
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://hadith-platform.app/schema/hadith_platform.schema.json",
        "title": "HadithDailyModel",
        "description": "مخطط بيانات منصة الحديث النبوي. الجذر هو HadithDailyModel، والملفات الأخرى تُتحقق عبر $defs: SourceCatalog وNarratorCatalog وCurriculumManifest وWisdomCatalog وSeerahDataset، ومسودات لوحة الإدخال عبر HadithDraft.",
        "$ref": "#/$defs/HadithDailyModel",
        "$defs": defs,
    }


# ------------------------------------------------------------------ dart
def from_json_expr(f):
    p = parse_type(f.type)
    k = f"'{f.name}'"
    if p["kind"] == "prim":
        fn = {"String": "readString", "int": "readInt", "double": "readDouble", "bool": "readBool"}[p["name"]]
        if p["nullable"]:
            fn += "OrNull"
        return f"{fn}(json, {k})"
    if p["kind"] == "enum":
        fn = "readEnumOrNull" if p["nullable"] else "readEnum"
        return f"{fn}(json, {k}, {p['name']}.fromWire)"
    if p["kind"] == "model":
        fn = "readModelOrNull" if p["nullable"] else "readModel"
        return f"{fn}(json, {k}, {p['name']}.fromJson)"
    if p["item"] == "String":
        return f"readStringList(json, {k})"
    return f"readModelList(json, {k}, {p['item']}.fromJson)"


def to_json_expr(f):
    p = parse_type(f.type)
    q = "?" if p["nullable"] else ""
    if p["kind"] == "prim":
        return f.name
    if p["kind"] == "enum":
        return f"{f.name}{q}.wire"
    if p["kind"] == "model":
        return f"{f.name}{q}.toJson()"
    if p["item"] == "String":
        return f"List<String>.of({f.name})"
    return f"{f.name}.map(({p['item']} item) => item.toJson()).toList()"


def is_list(f):
    return parse_type(f.type)["kind"] == "list"


def wrap_doc(text, indent):
    return f"{indent}/// {text}\n"


def gen_enum(e: Enum):
    out = wrap_doc(e.doc, "")
    out += f"enum {e.name} {{\n"
    for i, (dname, wire, doc) in enumerate(e.values):
        out += wrap_doc(doc, "  ")
        sep = ";" if i == len(e.values) - 1 else ","
        out += f"  {dname}('{wire}'){sep}\n"
        if i != len(e.values) - 1:
            out += "\n"
    out += f"\n  const {e.name}(this.wire);\n\n"
    out += "  /// القيمة المخزنة في ملفات JSON.\n"
    out += "  final String wire;\n\n"
    out += f"  /// يحوّل قيمة JSON إلى عنصر التعداد، ويرمي [JsonParseException] للقيم المجهولة.\n"
    out += f"  static {e.name} fromWire(String value) {{\n"
    out += f"    for (final {e.name} candidate in {e.name}.values) {{\n"
    out += "      if (candidate.wire == value) {\n"
    out += "        return candidate;\n"
    out += "      }\n"
    out += "    }\n"
    out += f"    throw JsonParseException('Unknown {e.name} value: \"$value\".');\n"
    out += "  }\n"
    out += "}\n"
    return out


def gen_model(m: Model):
    out = wrap_doc(m.doc, "")
    out += "@immutable\n"
    out += f"class {m.name} {{\n"
    # constructor
    out += f"  const {m.name}({{\n"
    for f in m.fields:
        out += f"    required this.{f.name},\n"
    out += "  });\n\n"
    # fromJson
    out += f"  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.\n"
    out += f"  factory {m.name}.fromJson(JsonMap json) {{\n"
    out += f"    return {m.name}(\n"
    for f in m.fields:
        out += f"      {f.name}: {from_json_expr(f)},\n"
    out += "    );\n"
    out += "  }\n\n"
    # fields
    for f in m.fields:
        out += wrap_doc(f.doc, "  ")
        out += f"  final {dart_type(f.type)} {f.name};\n\n"
    # extras
    extra = EXTRAS.get(m.name, "")
    if extra:
        out += extra.strip("\n") + "\n\n"
    # toJson
    out += "  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.\n"
    out += "  JsonMap toJson() {\n"
    out += "    return <String, dynamic>{\n"
    for f in m.fields:
        out += f"      '{f.name}': {to_json_expr(f)},\n"
    out += "    };\n"
    out += "  }\n\n"
    # equality
    out += "  @override\n"
    out += "  bool operator ==(Object other) {\n"
    out += "    if (identical(this, other)) {\n"
    out += "      return true;\n"
    out += "    }\n"
    conds = []
    for f in m.fields:
        if is_list(f):
            conds.append(f"listEquals({f.name}, other.{f.name})")
        else:
            conds.append(f"{f.name} == other.{f.name}")
    out += f"    return other is {m.name} &&\n"
    for i, c in enumerate(conds):
        end = ";" if i == len(conds) - 1 else " &&"
        out += f"        {c}{end}\n"
    out += "  }\n\n"
    out += "  @override\n"
    out += "  int get hashCode {\n"
    out += "    return Object.hashAll(<Object?>[\n"
    for f in m.fields:
        if is_list(f):
            out += f"      Object.hashAll({f.name}),\n"
        else:
            out += f"      {f.name},\n"
    out += "    ]);\n"
    out += "  }\n"
    out += "}\n"
    return out


def referenced_files(models_in_file):
    files = set()
    for m in models_in_file:
        for f in m.fields:
            p = parse_type(f.type)
            name = p.get("item") if p["kind"] == "list" else p.get("name")
            if name in MODEL_BY_NAME:
                files.add(MODEL_BY_NAME[name].file)
            if name in ENUM_BY_NAME:
                files.add(ENUM_BY_NAME[name].file)
    return files


def file_dir(fname):
    return os.path.join(LIB_DIR, FILE_DIRS.get(fname, DEFAULT_DIR))


def import_path(own, target_path):
    rel = os.path.relpath(target_path, start=file_dir(own))
    return rel.replace(os.sep, "/")


def gen_files():
    by_file = {}
    for e in ENUMS:
        by_file.setdefault(e.file, {"enums": [], "models": []})["enums"].append(e)
    for m in MODELS:
        by_file.setdefault(m.file, {"enums": [], "models": []})["models"].append(m)
    written = []
    for fname, parts in by_file.items():
        own = fname
        refs = sorted(referenced_files(parts["models"]) - {own})
        imports = ["import 'package:flutter/foundation.dart';", ""]
        local = set(refs) | set(EXTRA_IMPORTS.get(fname, ()))
        paths = [import_path(own, JSON_READER)]
        for r in local:
            target = os.path.join(file_dir(r), r) if r in FILE_DOCS else os.path.join(file_dir(own), r)
            paths.append(import_path(own, target))
        for path in sorted(paths):
            imports.append(f"import '{path}';")
        header = f"// {FILE_DOCS[fname]}\n//\n// Hadith Platform — data model v2.0.0. Generated by tools/schema/gen.py.\n\n"
        body = header + "\n".join(imports) + "\n"
        for e in parts["enums"]:
            body += "\n" + gen_enum(e)
        for m in parts["models"]:
            body += "\n" + gen_model(m)
        os.makedirs(file_dir(fname), exist_ok=True)
        path = os.path.join(file_dir(fname), fname)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(body)
        written.append(path)
    return written


if __name__ == "__main__":
    os.makedirs(os.path.dirname(SCHEMA_PATH), exist_ok=True)
    with open(SCHEMA_PATH, "w", encoding="utf-8") as fh:
        json.dump(build_schema(), fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    for p in gen_files():
        print("wrote", p)
    print("wrote", SCHEMA_PATH)
