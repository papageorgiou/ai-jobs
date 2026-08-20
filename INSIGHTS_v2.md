# AI job titles v2: the one that came out of nowhere

US Google search volume for 1,053 AI job titles, September 2022 to August 2026, pulled from
the Google Ads Keyword Planner API on 2026-08-20.

This is v1 rerun with one title added: **forward deployed engineer**. See `INSIGHTS.md` for
v1 and `report_v2.pdf` for the full write-up.

## Why the title was missing

The v1 universe was filtered by an AI-signal regex — a title had to contain `AI`, `LLM`,
`agentic`, `prompt` or similar. `Forward Deployed AI Engineer` passed. Bare `Forward Deployed
Engineer` did not, because it names no AI technology at all. That is the title OpenAI,
Anthropic, Palantir, Cohere, Mistral, Databricks, Ramp and Cursor actually hire under.

The filter is not wrong — loosening it to admit a bare `engineer` readmits every machine
learning and data science title the brief excludes. The lesson is that a rule-based inclusion
filter will miss exactly the roles whose names have not caught up with what they do, and
those are the interesting ones. v2 adds the title by name rather than by loosening the rule.

## The one thing to read first

**`forward deployed engineer` is now the largest AI career-intent search term in the study,
and it did not exist in v1.**

| | |
|---|---|
| Trailing 12-month average | 18,100/month |
| Last three months (Jun–Aug 2026) | **38,033/month** |
| Latest month (Aug 2026) | 40,500/month |
| Growth, first 12 months vs last 12 | +5,656% |
| Net searches/month gained | +17,581 — largest of any career term |
| Momentum rank | 1st of 289 modelable terms |

It sat flat between 210 and 880 searches a month for 29 months, then compounded roughly 30x
between February 2025 and August 2026. It is at its high in the last month of data.

This is a step change, not a trend. The linear fit is deliberately poor (R² 0.49) because a
straight line is the wrong model for the shape.

## Finding: v1 named the wrong successor to `prompt engineer`

v1 concluded that `context engineer` had replaced `prompt engineer`. One month of extra data
undoes it.

| Title | Peak | Last 3 months | Off peak |
|---|---|---|---|
| prompt engineer | 74,000 (May 2023) | 17,000 | −77% |
| context engineer | 14,800 (Aug 2025) | 3,867 | −74% |
| ai engineer | 22,200 (May 2026) | 20,833 | −6% |
| forward deployed engineer | 40,500 (Jul 2026) | 38,033 | −6% |

`context engineer` is still the fastest-growing term by percentage (+7,656%), but it peaked in
August 2025 and has given back three quarters of it. v1 read an adoption spike as a
succession. It was a spike — and v1's own caveat had allowed for exactly that.

`prompt engineer`'s decline also sharpened materially between the two runs: first-year-to-last
change went from −4% (reads as flat) to **−22%** (unambiguous), and its trailing average fell
27,100 → 22,200, the largest single move of any term between the two pulls.

## Finding: the reported average is the wrong ranking metric

Keyword Planner's `avg_monthly_searches` is a trailing 12-month mean. For a title that stepped
up mid-window it lands near the midpoint of the step — a number that describes no actual month.

`forward deployed engineer` reports 18,100 and is running at 38,033: the reported figure is
47% of the real current level. The error runs the other way for decliners — `ai ethicist`
reports 9,900 and is running at 6,700.

On the reported average, `prompt engineer` leads at 22,200. On the last three months the order
inverts completely: `forward deployed engineer` (38,033), `ai engineer` (20,833),
`prompt engineer` (17,000).

v1 ranked on the average throughout. That was a reasonable default for a set of mostly stable
series, and it stops being reasonable once a step-change term is in the universe.

## Finding: most AI job titles are already past their peak

Set each title against its own best month rather than against each other. Of the 16 career
terms in the chart, only `forward deployed engineer` and `ai engineer` are within 15% of their
peak. Four are 30–45% off. **Ten have lost more than half their search demand** — including
`prompt engineer` (−77%), `ai prompt engineer` (−83%), `ai software engineer` (−83%) and
`ai content creator` (−91%).

The vocabulary turns over fast, and the growth concentrates in a very small number of names.

## What survived v1 unchanged

- The tool-versus-career split and roughly its size (71.0% → 69.5% tool intent).
- `prompt engineer` peaked and is declining — more so than v1 could see.
- `ai engineer` rises steadily without ever spiking; at 96% of its all-time high.
- Nobody searches with a seniority level attached (208 of 260 career terms) or by industry
  (274 of 289 terms).
- Growth rate and net volume rank near-disjoint sets of titles.
- Governance and ethics is tiny — 16 titles, 640 searches/month.
- Roughly two-thirds of circulating AI job titles have no measurable search demand.
- Engineering is still the slowest-growing cluster in percentage terms (+114%, last of ten),
  even though its absolute lead widened from +39,159 to +48,958 searches/month gained. Level
  and rate genuinely disagree; v1's conclusion was about rate and it holds.

## Two things changed, not one

The pull was redone, so the window moved forward a month (Sep 2022 – Aug 2026 vs Aug 2022 –
Jul 2026). Only 45 of the 283 shared keywords moved at all, and most by one rounding bucket.
The material ones — `prompt engineer` (−4,900), `context engineer` (−1,200),
`ai podcaster` (−1,200), `ai architect` (−800) — are all declines consistent with the newer
window catching more of a downturn.

Six more terms cleared the modelling threshold in v2: `forward deployed engineer` plus
`llmops engineer`, `ai compliance specialist`, `ai frontend engineer`,
`ai drug discovery scientist` and `clinical ai reviewer`. Nothing modelable in v1 dropped out.

## Caveats

- `forward deployed engineer` is flagged by the spike detector (ratio 68.6 vs its own median).
  Kept, because the detector compares the max against the median of the whole 48-month series
  and any genuine step change scores high — the median here is dominated by 29 flat baseline
  months. The distinguishing evidence is duration: eighteen consecutive months of increase,
  with the last three all at the top. `context engineer` was kept on the same reasoning in v1
  and subsequently reverted, which is exactly the risk this caveat exists to flag.
- Only the bare title was added. `Forward Deployed Software Engineer` and `Forward Deployed
  Machine Learning Engineer` are in circulation and were deliberately left out to keep v2
  comparable to v1 at one changed input, so the role family's true demand is somewhat higher
  than the figures here.
- Volumes are rounded buckets and can be inflated by non-human traffic. Every figure is an
  order of magnitude with a direction.
- `ai ethicist` (9,900/month) still sits in the `other` function bucket rather than governance
  and ethics, which understates that cluster. Unchanged from v1, still not hand-patched.
