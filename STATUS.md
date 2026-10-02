# Status

Last updated: 2026-10-02 by cloud session (first version, built from git history, README, CLAUDE.md and outputs)
State: done (inferred: the article, report, charts and video deck are built, the last commit on 2026-09-01 retitled one chart)
Category: content (LinkedIn post and public article)
Client: none

## Goal

Measure which AI job titles are actually growing in US Google search demand, from four years of search volume for about 1,050 titles, and publish the findings as LinkedIn posts and a public article.

## Needs Alex

- [ ] Confirm this status is right (first version, written from the repo alone).
- [ ] Decide whether the article should take the retitled career chart. `output_v2/charts_simple/` has the new title, `site/images/` still holds the old copy on purpose.
- [ ] Record whether the LinkedIn posts and the 60-second video went out, and how they did (see Delivered).

## Blocked by

Nothing

## Next

Nothing recorded.

## Where we stand

1. v1: 1,052 titles pulled 2026-07-29. Frozen. Its true window is Jul 2022 to Jun 2026, though its charts and report say Aug 2022 to Jul 2026.
2. v2: adds Forward Deployed Engineer, 1,053 titles pulled 2026-08-20, window Aug 2022 to Jul 2026 after the month-label fix of 2026-08-27.
3. Headline: forward deployed engineer is the largest AI career-intent term on the last three months (38,033 a month), up about 42 times in eighteen months.
4. Career and tool intent are split and never pooled. Tool terms are 71% of all volume.
5. Chart variants: plain titles, Karpathy annotation in four axis treatments, banded layout.
6. Article rendered from `site/` into `docs/` for GitHub Pages, with an AI-assistance note and an About section.
7. 14-slide deck for a 60-second video, with speaker notes from the video script.

## Delivered

| Date | What | To whom | How | Feedback |
|---|---|---|---|---|
| 2026-08-29 | Public article on AI job titles | Public | GitHub Pages from `docs/` (live URL not recorded) | Not recorded |

## Outside this folder

- Routines: none recorded.
- Google Ads Keyword Planner API through the sibling `../ads-api` helper library. One request covers the whole title list.
- Other repos: `../posts` (publication charts, on `master`).
- Obsidian: LinkedIn drafts and the video script (`ai-jobs-video-script.md`) sit in the vault inbox. `build_deck.py` reads the script from there.

## Key outputs

- Article: `site/index.qmd`, rendered `docs/index.html`
- Reports: `report_v2.pdf`, `INSIGHTS_v2.md` (v1: `report.pdf`, `INSIGHTS.md`)
- Video deck: `slides.pdf`, `slides.qmd`, frames in `output_v2/slides_video/`
- Charts: `output_v2/charts_simple/`, `output_v2/charts_karpathy*/`
- Data: `output_v2/kw_trend_stats.parquet`, `ai_job_titles_master_v2.csv`

## Loose ends

- `INSIGHTS_v2.md` still states the window as September 2022 to August 2026, the label from before the month fix (inferred: not updated after 2026-08-27).
- `README.md` says "Purpose and contents TBD".
- `ai ethicist` falls into the `other` function bucket, which understates governance and ethics.
- A photo, two empty log files and many scripts sit at the repo root.
