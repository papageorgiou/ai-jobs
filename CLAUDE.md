# ai-jobs

Search-demand analysis of AI job titles. Assembles a master list of AI job titles from several
independently generated sources, pulls four years of US Google search volume for them, and
analyses which titles are actually growing.

Output feeds LinkedIn posts. Charts for publication live in the separate `posts` repo.

## Two versions live side by side

**v1** is the original study (1,052 titles, pulled 2026-07-29): `output/`, `04_charts.R`,
`report.qmd`, `INSIGHTS.md`. Its real window is **Jul 2022 - Jun 2026**; its charts and report
say Aug 2022 - Jul 2026 because of the month-label bug below, and were not re-rendered.

**v2** adds one title, `Forward Deployed Engineer`, and re-pulls (1,053 titles, Aug 2022 -
Jul 2026, pulled 2026-08-20): `output_v2/`, `04_charts_v2.R`, `report_v2.qmd`,
`INSIGHTS_v2.md`.

v1 is frozen and must stay reproducible - do not edit `04_charts.R`, `report.qmd`,
`INSIGHTS.md` or anything in `output/`. The Python pipeline is shared: `config.py` already
reads `OUTPUT_DIR` and `MASTER_CSV` from the environment, so `00_prep` through `03_cluster`
run unmodified for both. Only the chart script and report are duplicated, because several v1
chart *conclusions* no longer hold and rewriting them in place would break v1.

## Run order

Everything runs from the project root (path fallbacks in `config.py` are cwd-relative).

v1:

```
uv run build_master.py        # merge the four title lists -> ai_job_titles_master.csv
uv run 00_prep_keywords.py    # -> output/arg_df_gapi.csv, prints planned API request count
uv run 00b_preflight.py       # REQUIRED GATE - must print "Preflight passed"
uv run 00c_full_pull.py       # the actual pull (resumable, sharded)
uv run 01_clean.py            # -> output/df_clean.parquet
uv run 02_stats.py            # -> output/kw_trend_stats.parquet, rolling.parquet
uv run 03_cluster.py          # -> output/clusters.parquet
Rscript 04_charts.R           # -> output/charts/*.png
quarto render report.qmd      # -> report.pdf
```

v2 - same scripts, redirected by environment variables:

```
EXTRA_TITLES_CSV=ai_job_titles_fde.csv MASTER_OUT=ai_job_titles_master_v2.csv \
  DROPPED_OUT=ai_job_titles_dropped_v2.csv uv run build_master.py

export MASTER_CSV=ai_job_titles_master_v2.csv OUTPUT_DIR=output_v2/
uv run 00_prep_keywords.py && uv run 00b_preflight.py && uv run 00c_full_pull.py
uv run 01_clean.py && uv run 02_stats.py && uv run 03_cluster.py
unset MASTER_CSV OUTPUT_DIR

Rscript 04_charts_v2.R        # -> output_v2/charts/*.png (reads output_v2/ directly)
Rscript 04_charts_v2_karpathy.R  # -> output_v2/charts_karpathy/*.png (four layouts)
quarto render report_v2.qmd   # -> report_v2.pdf
```

Never skip `00b_preflight.py`. It exercises the same `get_volumes` entry point the real pull
uses and catches bad credentials, the gRPC/proxy CA block, and wrong location/language wiring in
about three seconds.

## The one thing to know about this dataset

**Search intent is split two ways and must never be pooled.**

- `career` — someone researching a job (`ai engineer`, `prompt engineer`)
- `tool-risk` — someone shopping for software (`ai photo editor`, `ai lawyer`)

The tool terms are 71% of all search volume. `ai photo editor` alone is 201,000/month. Pooled,
they dominate every chart and produce analysis that reports AI *product* demand while claiming to
report *job-title* demand. Before the split, `ai photo editor` was 63% of the design cluster and
`ai lawyer` was 95% of governance.

The flag is set by rule in `03_cluster.py` (`TOOL_PROFESSIONS` + `INTENT_EXEMPT`). It is a
judgement call, not a fact — `ai trainer` and `ai architect` are deliberately kept as careers
despite matching the tool shape. Re-read those lists before publishing anything that depends on
the split.

## Conventions and gotchas

**Adding a title that the AI-signal regex rejects.** Put it in a CSV and pass
`EXTRA_TITLES_CSV`. Titles from that source bypass `ALLOW` / `ALLOW_EXACT` entirely. Do not
loosen the regex instead - admitting a bare `engineer` readmits every ML and data-science
title the brief excludes. This is how `Forward Deployed Engineer` enters v2, and it is worth
remembering as a general failure mode: a rule-based inclusion filter misses exactly the roles
whose names have not caught up with what they do.

**The `claude_web` source lives in the Obsidian vault and moves.** It was at
`OBSIDIAN/@INBOX/ai_job_titles.csv` when v1 ran and is now under `OBSIDIAN/Create post auto-
AI jobs/`. `build_master.py` tries known locations in order; override with `WEB_TITLES_CSV`.
A hardcoded path here breaks the whole build.

**These titles are keywords, not seeds.** `00_prep_keywords.py` deliberately does *not* apply the
seed-cleaning rules from the `get-search-data` skill's `00_prep_seeds.py`. The ≤4-word cap and
letters-only filter exist to keep *seeds* broad enough to expand well. Applied here they would
discard most of the list and drop titles like `3D Modeling AI Engineer`. Do not "fix" this.

**What counts as an AI title.** LLM / RAG / agentic / prompt-style names qualify. Bare machine
learning and data science ones do not, because the question is AI demand rather than analytics
demand generally. NLP, computer vision and speech were dropped too — AI subfields, but they read
as classic ML in a search-volume context. Five LLM-native roles whose titles carry no matchable
token (`Evals Engineer`, `Context Engineer`, `RLHF Contributor`, `AIOps Engineer`, `Machine
Intelligence Engineer`) are kept via an explicit name list in `build_master.py`, not by loosening
the regex — loosening it readmits the ML titles.

**Growth is measured three ways**, because slope alone is scale-dependent and ranks every
high-volume title above every emerging one:
- `pct_change` — last 12 months vs first 12 (robust to seasonality)
- `net_change` — absolute searches/month gained
- `momentum` — mean of the percentile ranks of the two. Sort by this when picking examples.

Growth rate and net volume rank almost disjoint sets of titles. Report both or say which you used.

**The `past_months` labels need no correction — and an earlier version of this file said they
did.** `kwideas_funcs` encodes months as `f"{vol.month - 1}-{year}"`, and the Google Ads
`MonthOfYearEnum` starts at `JANUARY = 2`, so `month - 1` is *already* the true calendar month.
`"8-2022"` means August 2022. Do not add 1.

`02_stats.py` used to add 1, on the since-corrected reading that `"8-2022"` meant September. That
put every v2 month one late: the window was labelled Sep 2022 - Aug 2026 when the pull ran
2026-08-20 and can only reach the last complete month, July 2026. Fixed 2026-08-27 in
`resolve_months()`, which now reads the labels, asserts all rows agree and that they are
chronological, and persists them to `output*/month_labels.json`.

**v1's `output/` is still shifted** — it is frozen, so it was not re-run. Its real window is
Jul 2022 - Jun 2026, not the Aug 2022 - Jul 2026 its charts and report state. Re-run
`02_stats.py`/`03_cluster.py` against `output/` before reusing any v1 date claim.

The lesson generalises: a window shifted by a month is invisible downstream. Every internal check
passes, the shape stays smooth, nothing looks broken. Derive the range from the data and print it
— never restate it in a caption or a `START` constant. `04_charts_v2.R` now builds `CAPTION` from
`range(rolling$month)` for exactly this reason.

**Log scales are usually required.** `prompt engineer` peaks at 65,000/month while emerging
titles sit in the hundreds. On a linear axis every line of interest renders as flat.

**Charts render via Typst, not LaTeX.** There is no TeX distribution on this machine. Quarto 1.8
bundles Typst, so `format: typst` works with no extra install. Do not switch `report.qmd` to
`format: pdf`.

**ggtext heights.** `element_textbox_simple` does not reserve height for lines it wraps itself, so
two-line titles collide with the subtitle. Titles are hand-wrapped through `wrap_md()` +
`element_markdown`. Subtitles keep `textbox_simple` because they carry inline `<span>` colour that
`strwrap` would split mid-tag.

**Google's volumes are not ground truth.** Keyword Planner returns rounded buckets (720, 880,
1,000, 1,300…), not exact counts, and volume can be inflated by bot or AI traffic. Spikes are
flagged to `spikes_flagged.parquet` for review, never auto-dropped. Treat every figure as an
order of magnitude with a direction.

**Reported volume is a trailing 12-month mean, so it lies about step changes.**
`avg_monthly_searches` lands near the midpoint of a step - `forward deployed engineer` reports
18,100 while running at 38,033. v2 computes a `last3` (mean of the final three months) and
ranks on it wherever the ranking is the point. Do not rank a universe containing a
step-change term on the reported average.

**A step change trips the spike detector by construction.** `SPIKE_RATIO` compares the max
against the median of the whole 48-month series, so a term that was flat for years and then
climbed scores enormously (`forward deployed engineer`: 68.6). The discriminator is duration -
eighteen consecutive rising months is adoption, one anomalous month is not. Note that
`context engineer` passed the same test in v1 and then reverted, so a pass is not a guarantee.

## Known rough edge

`ai ethicist` (9,900/month, the third-largest career term) falls into the `other` function bucket
rather than `governance & ethics`, which understates that cluster. Left as-is rather than
hand-patching one term into a rule-based taxonomy. Tighten the rules in `03_cluster.py` before
using the function clusters as a headline.

## External dependencies

- `../ads-api/` — Google Ads helper library. Import by bare name after
  `sys.path.append(ADS_API_DIR)`. `get_volumes` is in `kwideas_funcs.py`; the orchestration
  helpers (`process_row_arg_dicts_simple`, `get_final_res_df`, `get_summary_table`) are in
  `pyevangelion_powerfuncs_ai.py`. Credentials at `../ads-api/ads.yaml`.
- `../posts/` — publication charts. **This repo is on `master`, not `main`.** Push accordingly.
- `../OBSIDIAN/@INBOX/` — where LinkedIn post drafts go, per global preferences.

## API budget

`get_volumes` accepts up to 10,000 keywords per request, so the whole 1,052-title universe is a
single call. Always state the planned request count and get a go-ahead before pulling, even when
it is cheap.
