# ai-jobs

Search-demand analysis of AI job titles. Assembles a master list of AI job titles from several
independently generated sources, pulls four years of US Google search volume for them, and
analyses which titles are actually growing.

Output feeds LinkedIn posts. Charts for publication live in the separate `posts` repo.

## Run order

Everything runs from the project root (path fallbacks in `config.py` are cwd-relative).

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

**The `past_months` +1 correction.** `kwideas_funcs` encodes months as `f"{month-1}-{year}"`, so
`"5-2022"` means June 2022. `02_stats.py` applies the correction in `resolve_start()`. A naive
parse silently lands the whole series a month early.

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
