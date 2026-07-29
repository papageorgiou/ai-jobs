"""Rule-based clustering of job titles, plus a search-intent risk flag.

Three independent axes are tagged from the title string (ordered rules, first
match wins), so the data can be sliced by what the job does, how senior it is,
and which industry it sits in.

The fourth output, `intent`, is not a cluster - it is a data-quality flag. See
the note above TOOL_PROFESSIONS.
"""

import re
import sys

import pandas as pd

import config

# --- What the role does -------------------------------------------------------
# Order matters: leadership and governance markers are checked before the
# generic engineering ones, since "Director of AI Engineering" is a leadership
# role that happens to contain "engineering".
FUNCTION_RULES = [
    ("leadership",        r"\b(chief|c[a-z]?o\b|head of|vp\b|vice president|director|founding)\b"),
    ("governance & ethics", r"\b(ethic|governance|policy|compliance|risk|audit|responsible|safety|alignment|trust|privacy|legal|lawyer|attorney|philosopher)\b"),
    ("research",          r"\b(research|scientist|researcher)\b"),
    ("product & program", r"\b(product manager|program manager|project manager|tpm|business analyst|product owner|strategist|strategy|consultant|advisor)\b"),
    ("design & creative", r"\b(design|creative|artist|writ|copywrit|content|ux|ui|art director|animat|illustrat|photo|video|graphic|music|produc|actor|voice|color grad|podcast|report|journalis)"),
    ("infrastructure & ops", r"\b(infrastructure|platform|sre|reliability|devops|mlops|llmops|aiops|agentops|operations|ops\b|compute|cloud)\b"),
    ("education & coaching", r"\b(teacher|tutor|instructor|coach|professor|educat|train)"),
    ("data & alignment",  r"\b(annotat|label|rlhf|evaluat|evals?|rater|data)"),
    ("engineering",       r"\b(engineer|developer|architect|programmer|coder)\b"),
    ("other",             r".*"),
]

# --- How senior ---------------------------------------------------------------
SENIORITY_RULES = [
    ("c-suite",       r"\b(chief|c[a-z]?o\b)\b"),
    ("vp / director", r"\b(vp\b|vice president|director|head of)\b"),
    ("lead / manager", r"\b(lead|manager|management)\b"),
    ("staff / principal", r"\b(staff|principal|distinguished|fellow)\b"),
    ("senior",        r"\b(senior|sr\b)\b"),
    ("junior / entry", r"\b(junior|jr\b|entry|associate|intern|graduate)\b"),
    ("mid",           r"\b(mid|mid-level)\b"),
    ("unspecified",   r".*"),
]

# --- Which industry -----------------------------------------------------------
DOMAIN_RULES = [
    ("healthcare", r"\b(health|healthcare|clinical|medical|medicine|nursing|nurse|patient|radiolog|biomed|drug|genomic|life sciences|ehr|bioethic)\b"),
    ("finance",    r"\b(financ|fintech|bank|trading|trader|quant|actuarial|credit|fraud|insurance|invest)\b"),
    ("legal",      r"\b(legal|lawyer|attorney|patent|litigation|contract)\b"),
    ("hr",         r"\b(recruit|talent|hr\b|people|hiring)\b"),
    ("general",    r".*"),
]

# --- Search-intent risk -------------------------------------------------------
# The critical caveat for this dataset. A phrase like "ai photo editor" is
# overwhelmingly typed by someone looking for an AI tool that edits photos, not
# by someone researching that career. Those terms carry huge volume and would
# dominate any chart, so they are flagged rather than silently mixed in with
# genuine career searches like "ai engineer" or "chief ai officer".
#
# The pattern is: "ai <profession>", where the profession is work that AI now
# performs *for* the user. Career-intent titles instead describe work performed
# *on* AI systems.
TOOL_PROFESSIONS = {
    "photo editor", "video editor", "writer", "copywriter", "content writer",
    "artist", "animator", "videographer", "photographer", "illustrator",
    "graphic designer", "designer", "editor", "musician", "composer",
    "tutor", "teacher", "trainer", "instructor", "coach", "professor",
    "lawyer", "attorney", "paralegal", "accountant", "bookkeeper",
    "podcaster", "actor", "voice actor", "presenter", "narrator", "blogger",
    "journalist", "translator", "interpreter", "assistant", "receptionist",
    "therapist", "doctor", "nurse", "dentist", "veterinarian",
    "recruiter", "salesperson", "marketer", "realtor", "agent",
    "chef", "stylist", "architect", "engineer", "developer",
    "real estate agent", "producer", "music producer", "fitness coach",
    "life coach", "color grader", "reporter", "singer", "rapper", "dj",
    "model", "influencer", "editor in chief", "ghostwriter", "proofreader",
    "sculptor", "painter", "cartoonist", "comedian", "whisperer",
}
# Titles that match the shape but are unambiguously careers - "ai engineer" and
# "ai architect" are real job titles despite the shape, so they are exempt.
INTENT_EXEMPT = {"ai engineer", "ai architect", "ai developer", "ai trainer",
                 "ai researcher", "ai scientist"}

TOOL_SHAPE = re.compile(r"^ai (.+)$")


def tag(text, rules):
    for label, pattern in rules:
        if re.search(pattern, text, re.I):
            return label
    return rules[-1][0]


def intent(keyword):
    if keyword in INTENT_EXEMPT:
        return "career"
    m = TOOL_SHAPE.match(keyword)
    if m and m.group(1) in TOOL_PROFESSIONS:
        return "tool-risk"
    return "career"


def main():
    st = pd.read_parquet(config.out("kw_trend_stats.parquet"))

    st["function"] = st["keyword"].map(lambda k: tag(k, FUNCTION_RULES))
    st["seniority"] = st["keyword"].map(lambda k: tag(k, SENIORITY_RULES))
    st["domain"] = st["keyword"].map(lambda k: tag(k, DOMAIN_RULES))
    st["intent"] = st["keyword"].map(intent)

    # Carry the source taxonomy alongside for cross-checking, without using it
    # as the primary grouping.
    mapping = pd.read_csv(config.out("title_keyword_map.csv"))
    src = (mapping.dropna(subset=["Category"])
           .drop_duplicates("keyword")[["keyword", "Category"]]
           .rename(columns={"Category": "source_category"}))
    st = st.merge(src, on="keyword", how="left")

    st.to_parquet(config.out("clusters.parquet"))

    for axis in ["function", "seniority", "domain", "intent"]:
        counts = st.groupby(axis).agg(
            n=("keyword", "size"), volume=("avg_monthly_searches", "sum"))
        counts = counts.sort_values("volume", ascending=False)
        print(f"\n--- {axis} ---")
        print(counts.to_string())

    print("\n--- tool-intent risk terms (would dominate any chart) ---")
    risk = st[st["intent"] == "tool-risk"].nlargest(15, "avg_monthly_searches")
    print(risk[["keyword", "avg_monthly_searches", "pct_change"]]
          .to_string(index=False, float_format=lambda v: f"{v:,.1f}"))
    share = (st[st["intent"] == "tool-risk"]["avg_monthly_searches"].sum()
             / st["avg_monthly_searches"].sum())
    print(f"\ntool-risk terms are {share:.0%} of total volume across {len(st)} keywords")

    print("\n--- dominant-term check: one keyword >=50% of its function cluster ---")
    for fn, g in st.groupby("function"):
        total = g["avg_monthly_searches"].sum()
        top = g.nlargest(1, "avg_monthly_searches").iloc[0]
        if total > 0 and top["avg_monthly_searches"] / total >= 0.5:
            print(f"  {fn}: '{top['keyword']}' is "
                  f"{top['avg_monthly_searches'] / total:.0%} of the cluster")
    return 0


if __name__ == "__main__":
    sys.exit(main())
