# AI job titles: what people actually search for

US Google search volume for 1,052 AI job titles, August 2022 to July 2026, pulled from the
Google Ads Keyword Planner API on 2026-07-29.

## The one thing to read first

**71% of all search volume in this dataset is not people researching AI careers. It is people
shopping for AI tools.**

`ai photo editor` (201,000/month), `ai videographer` (49,500), `ai writer` (33,100) and
`ai lawyer` (18,100) look like job titles and are not searched like job titles. Someone typing
"ai lawyer" wants cheap legal help, not a law degree. These 29 terms carry 359,240 searches a
month between them; the 254 genuine career terms carry 146,610.

This matters because those terms are concentrated enough to swallow whole categories.
`ai photo editor` alone was 63% of the design cluster and `ai lawyer` 95% of governance before
they were separated out. Any chart that pools them shows AI product demand while claiming to
show job-title demand.

Every figure below is career-intent terms only, unless it says otherwise.

## Coverage

| Stage | Count |
|---|---|
| Titles in the master list | 1,052 |
| Unique after normalisation | 1,051 |
| Returned by the API | 1,048 |
| With any search volume | 390 |
| After collapsing identical series and zero-volume rows | 379 |
| Modelable (peak above 20 searches/month) | 283 |
| — career intent | 254 |
| — tool intent | 29 |

A 37% hit rate on a deliberately generous list is the expected outcome, not a failure. Roughly
two-thirds of the titles circulating in "AI jobs of the future" listicles have effectively no
search demand at all — nobody is looking them up. That absence is itself a finding.

## Finding 1: "Prompt engineer" already peaked

The most-searched AI career term is `prompt engineer`, and it topped out **three years ago**.

- Peak: 65,000/month, June 2023
- Latest: 19,467/month
- Down roughly 70% from peak

The first-year-to-last-year comparison is nearly flat (-3.6%), which understates the story —
the first year of the window captured the initial surge. Measured from the peak, the decline is
unambiguous.

Meanwhile `ai engineer` never spiked and never fell. It went from 4,017/month to 18,300/month
and hit its highest-ever month in July 2026, the last month of data. The durable title is the
boring one.

## Finding 2: "Context engineer" came from nothing

- First 12 months: 62 searches/month
- Last 12 months: 5,975/month
- A 96x increase, and the single fastest-growing term in the dataset

The series is a step change, not a ramp: near-flat until July 2025, then a jump of 164x the
median in August 2025. That is flagged as an anomalous spike by the pipeline, and it is worth
being explicit about why it is credible anyway — "context engineering" entered circulation as a
term in mid-2025, so a step change is what genuine, sudden vocabulary adoption looks like. It
is not the pattern of a keyword drifting upward on bot traffic. It has since settled back to
around 4,500/month, so the peak was an adoption spike rather than a new plateau.

If you want the sharpest version of the story: **the industry replaced its hottest job title in
under two years, and most people have not noticed.**

## Finding 3: growth rate and net volume tell different stories

This is why both are worth showing.

Ranked by percentage growth, the top of the list is titles that barely existed in 2022 —
`ai sre` (+7,509%), `ai agent architect` (+6,157%), `ai automation engineer` (+3,876%). Real
signals, but all under 1,000 searches/month. Percentage growth flatters a small base.

Ranked by searches actually gained, it is a different list:

| Title | Searches/mo gained | Growth |
|---|---|---|
| ai engineer | +14,283 | +357% |
| ai consultant | +6,663 | +566% |
| context engineer | +5,913 | +9,460% |
| ai ethicist | +5,233 | +100% |
| ai trainer | +3,991 | +1,291% |

Only `context engineer` appears near the top of both. The `momentum` score in the data averages
the percentile ranks of the two, and is the right column to sort by when picking examples.

## Finding 4: the clusters

Career-intent volume by function:

| Function | Terms | Searches/mo | Gained |
|---|---|---|---|
| engineering | 76 | 79,230 | +37,616 |
| product & program | 22 | 19,660 | +15,629 |
| research | 13 | 6,970 | +5,603 |
| data & alignment | 10 | 5,470 | +4,219 |
| education & coaching | 8 | 4,870 | +4,288 |
| design & creative | 22 | 4,490 | +2,946 |
| leadership | 12 | 2,880 | +2,232 |
| infrastructure & ops | 10 | 1,690 | +1,541 |
| governance & ethics | 15 | 910 | +405 |

Two things stand out.

**Engineering dominates but is not the whole story.** It is 54% of career volume, yet product
and program management gained nearly half as many searches as engineering did off a quarter of
the base.

**Governance and ethics is tiny.** 15 distinct titles, 910 searches a month between them, and
almost no growth. For all the conference-panel attention AI governance receives, essentially
nobody is searching these roles as careers. (Note the caveat: `ai ethicist` at 9,900/month is
classified into `other` by the function rules, so governance is understated — but even adding it
back, the cluster is small and its growth is driven by one term.)

## Finding 5: seniority is almost never searched

231 of 254 career terms carry no seniority marker at all, and they account for essentially all
the volume. `senior ai engineer`, `staff ai engineer`, `principal ai engineer` and the rest are
rounding errors.

People search the role, not the level. Any content strategy built around seniority-qualified AI
titles is targeting demand that does not exist.

The same holds for industry: 270 of 283 terms are industry-agnostic. `healthcare ai engineer`
and the finance equivalents barely register.

## Caveats

- **Google's reported volume is not ground truth.** Keyword Planner returns rounded buckets
  (720, 880, 1,000, 1,300...), not exact counts, and volume can be inflated by bot or
  AI-driven traffic. Treat every number here as an order of magnitude with a direction.
- **76 non-seasonal spikes were flagged**, of which 3 are material (above 1% of total volume):
  `context engineer` (discussed above, judged genuine), `ai actor` and `ai artist` — both
  tool-intent terms, so they sit outside the career analysis anyway.
- **The tool-vs-career split is a judgement call**, applied by rule against a list of
  professions AI performs as a service. `ai trainer` and `ai architect` were deliberately kept
  as careers despite matching the shape. The rules are in `03_cluster.py` and the split is
  worth re-reading before publishing.
- The `other` function bucket still holds 66 terms including `ai ethicist`, the third-largest
  career term. Worth tightening if the function cluster becomes the post's angle.

## Candidate LinkedIn angles

1. **"The hottest AI job title already peaked."** Prompt engineer down 70% from its June 2023
   high while context engineer went 96x. Chart 12 is built for this. Strongest and most
   counterintuitive.
2. **"Most 'AI job titles' are not jobs."** The 71% tool-intent split — people are searching for
   software that does the work, not for the career doing it. Chart 1 and 11. This is the most
   original finding in the dataset and nobody else will have it.
3. **"Two-thirds of AI job titles have zero search demand."** 1,052 titles in circulation, 390
   with any volume, 283 worth modelling. A piece about how much of the AI-jobs discourse is
   invented vocabulary.
4. **"Nobody searches for senior AI engineer."** The seniority finding — people search roles,
   not levels. Narrower, but a clean practical takeaway for recruiters.

Angle 1 is the most shareable; angle 2 is the most defensible as original analysis. They can
also run as a two-part sequence.

## Files

- `output/charts/` — 12 exploratory charts
- `output/clusters.parquet` — per-title metrics, clusters and intent flag
- `output/rolling.parquet` — long-format monthly series
- `output/df_clean.csv` — cleaned volumes, glanceable
