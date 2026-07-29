"""Merge the four AI job-title sources into one deduplicated master list.

The sources were generated independently (two in-repo lists, one from Gemini, one
from Claude web) and overlap heavily, so titles are matched case-insensitively
after whitespace normalisation. Only titles carrying an AI-signal token survive:
per the brief, LLM/RAG/agentic/prompt-style names count as AI, but bare machine
learning, data science, NLP, computer vision and speech titles do not.
"""

import csv
import re
from pathlib import Path

REPO = Path(__file__).parent
WEB = Path("/Users/alexp/gd_alpapag/apclients/OBSIDIAN/@INBOX/ai_job_titles.csv")

# Tokens that qualify a title as AI. Matched on word boundaries so "RAG" does not
# fire on "fragment" and "AI" does not fire on "Maintenance".
ALLOW = [
    r"AI", r"A\.I\.", r"Artificial Intelligence", r"GenAI", r"Gen AI",
    r"LLM", r"LLMs", r"LLMOps", r"Large Language Model", r"SLM",
    r"RAG", r"Agentic", r"Agent", r"Agents", r"AgentOps",
    r"Prompt", r"Generative", r"Foundation Model", r"Frontier Model",
    r"Copilot", r"ChatGPT", r"Transformer", r"MCP",
]
ALLOW_RE = re.compile(r"(?<![A-Za-z])(?:" + "|".join(ALLOW) + r")(?![A-Za-z])", re.I)

# Roles that only exist because of LLMs, or that paraphrase "AI", but whose
# titles carry no matchable token. Kept by name rather than by loosening ALLOW,
# which would drag in unrelated ML and analytics titles.
ALLOW_EXACT = {
    "evals engineer", "context engineer", "rlhf contributor",
    "aiops engineer", "machine intelligence engineer",
}

# Sources in precedence order: earlier files win when supplying metadata for a
# title that appears in several lists.
SOURCES = [
    ("gemini", REPO / "ai_job_titles_gemini.csv", "Job Title",
     "Primary Functional Category", "Seniority Level", "Domain Focus"),
    ("original", REPO / "ai_job_titles.csv", "Job Title", "Category", None, None),
    ("expanded", REPO / "ai_job_titles_new.csv", "Job Title", None, None, None),
    ("claude_web", WEB, "Job Title", "Category", None, None),
]


def norm(title):
    return re.sub(r"\s+", " ", title).strip()


master = {}   # lowercase title -> row dict
dropped = {}  # lowercase title -> canonical title

for name, path, t_col, cat_col, sen_col, dom_col in SOURCES:
    with path.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            title = norm(row.get(t_col) or "")
            if not title:
                continue
            key = title.lower()
            if key not in ALLOW_EXACT and not ALLOW_RE.search(title):
                dropped.setdefault(key, title)
                continue
            entry = master.get(key)
            if entry is None:
                entry = master[key] = {
                    "Job Title": title, "Category": "",
                    "Seniority Level": "", "Domain Focus": "", "sources": []
                }
            entry["sources"].append(name)
            # First source to supply a field keeps it.
            for field, col in (("Category", cat_col),
                               ("Seniority Level", sen_col),
                               ("Domain Focus", dom_col)):
                if col and not entry[field]:
                    entry[field] = norm(row.get(col) or "")

out = REPO / "ai_job_titles_master.csv"
with out.open("w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh)
    w.writerow(["Job Title", "Category", "Seniority Level", "Domain Focus",
                "Sources", "Source Count"])
    for e in sorted(master.values(), key=lambda r: r["Job Title"].lower()):
        srcs = sorted(set(e["sources"]))
        w.writerow([e["Job Title"], e["Category"], e["Seniority Level"],
                    e["Domain Focus"], ";".join(srcs), len(srcs)])

(REPO / "ai_job_titles_dropped.csv").write_text(
    "Job Title\n" + "\n".join(sorted(dropped.values(), key=str.lower)) + "\n",
    encoding="utf-8")

print(f"master: {len(master)} titles -> {out.name}")
print(f"dropped (no AI signal): {len(dropped)}")
