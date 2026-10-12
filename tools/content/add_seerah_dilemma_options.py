#!/usr/bin/env python3
"""Add `dilemma_options` to the Seerah stations whose own sources state the options.

Red line: no option is typed here. Each option is cut, word for word, out of a
challenge-scene quote already in the dataset, between two marker words (matched
without tashkeel). The script asserts every cut is a verbatim substring of its
quote and refuses to write anything it cannot prove.

Today only one station states its alternatives in its own source text: at Badr,
al-Hubab ibn al-Mundhir asks whether the halt is a place God commanded or "the
opinion, the war and the stratagem" (Ibn Hisham, vol. 1 p. 620). Every other
station has no alternatives in its sources and keeps the reveal-only flow.

Usage:
    python3 tools/content/add_seerah_dilemma_options.py [dataset.json]
"""
import json
import re
import sys

PATH = "assets/data/seerah_dataset.json"
TASHKEEL = re.compile("[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed\u0640]")
EDGE_PUNCT = "،,؛؟?.:"

# station id -> [(first marker word, last marker word), ...] one pair per option,
# each searched in the station's challenge-scene quotes in file order.
OPTIONS = {
    "badr_hubab_counsel": [("أمنزلا", "عنه،"), ("الرأي", "والمكيدة؟")],
}


def plain(word):
    return TASHKEEL.sub("", word)


def cut(quote, first, last):
    words = quote.split(" ")
    start = next((i for i, w in enumerate(words) if plain(w) == first), None)
    if start is None:
        return None
    end = next((i for i in range(start, len(words)) if plain(words[i]) == last), None)
    if end is None:
        return None
    return " ".join(words[start:end + 1]).strip(EDGE_PUNCT + " ")


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else PATH
    with open(path, encoding="utf-8") as fh:
        dataset = json.load(fh)
    stations = {s["id"]: s for s in dataset["stations"]}
    for station_id, pairs in OPTIONS.items():
        station = stations[station_id]
        quotes = [e["source"]["quote"] for e in station["evidence"] if e["scene"] == "challenge"]
        options = []
        for first, last in pairs:
            found = None
            for quote in quotes:
                found = cut(quote, first, last)
                if found:
                    assert found in quote, "an option must be a verbatim substring of its quote"
                    break
            assert found, f"{station_id}: markers {first!r}..{last!r} not found in a challenge quote"
            options.append(found)
        assert len(set(options)) == len(options) >= 2
        station["dilemma_options"] = options
        print(station_id, options)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(dataset, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


if __name__ == "__main__":
    main()
