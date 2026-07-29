"""Build the get_volumes argument frame from the master job-title list.

Deliberately does NOT apply the seed-cleaning rules from 00_prep_seeds.py. Those
rules (<= 4 words, letters only) exist to keep *seeds* short and broad so they
expand well. These titles are not seeds - they are the exact keywords we want
measured - so a >4-word cap would discard most of the list and a no-digits rule
would drop titles like "3D Modeling AI Engineer".

Normalisation is limited to what Keyword Planner will not match literally:
case, surrounding punctuation, bracketed asides and separator characters.
"""

import re
import sys

import pandas as pd

import config

# Characters Keyword Planner treats as separators rather than as part of a term.
SEPARATORS = re.compile(r"[/&|,]")
# Parenthesised asides, e.g. "Member of Technical Staff (MTS) - AI Research".
PARENS = re.compile(r"\([^)]*\)")
# Anything left that is not a letter, digit, space or intra-word hyphen.
JUNK = re.compile(r"[^a-z0-9\- ]")


def to_keyword(title: str) -> str:
    kw = title.lower()
    kw = PARENS.sub(" ", kw)
    kw = SEPARATORS.sub(" ", kw)
    # Dashes used as separators (" - ") go; hyphens inside words (mid-level) stay.
    kw = re.sub(r"\s+-\s+", " ", kw)
    kw = JUNK.sub(" ", kw)
    return re.sub(r"\s+", " ", kw).strip()


def main():
    titles = pd.read_csv(config.MASTER_CSV)
    titles["keyword"] = titles["Job Title"].map(to_keyword)

    blank = titles["keyword"].eq("")
    if blank.any():
        print(f"dropping {blank.sum()} titles that normalised to empty")
        titles = titles[~blank]

    # Keep the full mapping so cluster labels and original casing can be rejoined
    # after the pull, and so normalisation collisions stay traceable.
    titles.to_csv(config.out("title_keyword_map.csv"), index=False)

    keywords = sorted(titles["keyword"].unique())
    collisions = len(titles) - len(keywords)
    print(f"{len(titles)} titles -> {len(keywords)} unique keywords "
          f"({collisions} collapsed by normalisation)")

    batches = [keywords[i:i + config.KW_BATCH_SIZE]
               for i in range(0, len(keywords), config.KW_BATCH_SIZE)]

    arg_df = pd.DataFrame({
        "kw_list": batches,
        "start": [i * config.KW_BATCH_SIZE for i in range(len(batches))],
        "finish": [i * config.KW_BATCH_SIZE + len(b) for i, b in enumerate(batches)],
        "location_ids": config.LOCATION_ID,
        "language_id": config.LANGUAGE_ID,
        "iteration": range(1, len(batches) + 1),
    })
    arg_df.to_csv(config.out("arg_df_gapi.csv"), index=False)

    print(f"\nwrote {config.out('arg_df_gapi.csv')}")
    print(f"PLANNED API REQUESTS: {len(batches)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
