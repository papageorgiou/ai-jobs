# Charts for the AI job-title search-volume study, v2 - plain-title variant.
#
# Same data, same geoms, same palette as 04_charts_v2.R. Two differences only:
#   1. Every title is cut to a short plain statement (no clause stacking, no
#      quoted term running into a claim).
#   2. No subtitles at all.
#
# Removing the subtitle removes the only legend some charts had - the v2 style
# encodes series colour in inline <span>s in the subtitle rather than a legend
# box. Where that was the case (charts 1, 14, 15) a real legend is turned back
# on; where the series are labelled directly on the plot (2, 7-10, 12) nothing
# is needed. Facts the subtitle carried about the transform (rolling average,
# log scale, filters) move into the axis label, which is the right place for
# them anyway.
#
# Writes to output_v2/charts_simple/ so 04_charts_v2.R's output is untouched.

library(arrow)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggtext)
library(ggrepel)
library(scales)
library(stringr)
library(forcats)
library(glue)

IN_DIR  <- "output_v2"
OUT_DIR <- file.path(IN_DIR, "charts_simple")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# --- Style (Warm Ledger, per the dataviz-linkedin skill) ----------------------
bg_plot   <- "#F6EFE8"
bg_figure <- "#FAF8F5"
gridlines <- "#E2D6CB"
text_axes <- "#2B2F33"

pal <- c(blue = "#2B5FB8", red = "#B83A2F", yellow = "#8F6A00", green = "#13734A",
         purple = "#6B4FA3", teal = "#1F7A7A", orange = "#C05A1A",
         rose = "#B44A7A", slate = "#4E5A63")

wrap_md <- function(x, width = 78) {
  vapply(x, function(s) paste(strwrap(s, width = width), collapse = "<br>"),
         character(1), USE.NAMES = FALSE)
}

theme_post <- function(base_size = 13) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.background   = element_rect(fill = bg_figure, colour = NA),
      panel.background  = element_rect(fill = bg_plot, colour = NA),
      panel.grid.major  = element_line(colour = gridlines, linewidth = 0.3),
      panel.grid.minor  = element_blank(),
      text              = element_text(colour = text_axes),
      # b = 18 rather than v2's 16: with no subtitle between it and the panel,
      # the title needs its own breathing room.
      plot.title         = element_markdown(size = rel(1.45), face = "bold", hjust = 0,
                                            margin = margin(b = 18), lineheight = 1.25),
      plot.caption       = element_text(size = rel(0.75), colour = "grey45", hjust = 0),
      legend.position    = "none",
      legend.title       = element_blank(),
      legend.background  = element_rect(fill = bg_figure, colour = NA),
      legend.key         = element_rect(fill = bg_figure, colour = NA),
      strip.text         = element_text(face = "bold", size = rel(0.8)),
      plot.margin        = margin(16, 18, 12, 16)
    )
}

# Charts that lost their colour key with the subtitle get it back here.
theme_legend <- function() {
  theme(legend.position = "top",
        legend.justification = "left",
        legend.margin = margin(b = 6),
        legend.text = element_text(size = rel(0.9)))
}

CAPTION <- paste("Source: Google Ads Keyword Planner, US, Sep 2022 - Aug 2026.",
                 "Retrieved 2026-08-20 (v2). Volumes are rounded buckets, not exact counts.",
                 "\nCode: github.com/papageorgiou/ai-jobs")

save_chart <- function(plot, name, w = 10, h = 8) {
  if (!is.null(plot$labels$title))
    plot$labels$title <- wrap_md(plot$labels$title, floor(w * 6.5))
  ggsave(file.path(OUT_DIR, name), plot, width = w, height = h, dpi = 150)
  message("wrote ", name)
}

# --- Data ---------------------------------------------------------------------
clusters <- read_parquet(file.path(IN_DIR, "clusters.parquet"))
rolling  <- read_parquet(file.path(IN_DIR, "rolling.parquet")) |>
  left_join(clusters |> select(keyword, function_ = "function", seniority, domain, intent,
                               momentum, pct_change, net_change),
            by = "keyword")

recent <- rolling |>
  group_by(keyword) |>
  arrange(month, .by_group = TRUE) |>
  summarise(last3     = mean(tail(searches, 3)),
            peak      = max(searches),
            peak_month = month[which.max(searches)],
            .groups   = "drop") |>
  mutate(off_peak = last3 / peak - 1)

clusters <- clusters |> left_join(recent, by = "keyword")

career <- clusters |> filter(intent == "career")
tools  <- clusters |> filter(intent == "tool-risk")
FDE    <- "forward deployed engineer"

# =============================================================================
# 1. The headline split
# =============================================================================
split_ts <- rolling |>
  group_by(intent, month) |>
  summarise(searches = sum(searches), .groups = "drop")

p1 <- ggplot(split_ts, aes(month, searches, colour = intent)) +
  geom_line(linewidth = 1.4) +
  scale_colour_manual(values = c(career = pal[["slate"]], `tool-risk` = pal[["red"]]),
                      labels = c(career = "Career: a job doing the work",
                                 `tool-risk` = "Tool: software doing the work")) +
  scale_y_continuous(labels = label_comma()) +
  labs(title = "Most AI job-title searches are for tools, not careers",
       x = NULL, y = "Searches per month", caption = CAPTION) +
  theme_post() + theme_legend()
save_chart(p1, "01_intent_split.png", 11, 7)

# =============================================================================
# 2. Spaghetti - career titles, top movers highlighted
# =============================================================================
top_movers <- career |> slice_max(momentum, n = 8) |> pull(keyword)

spag <- rolling |>
  filter(intent == "career") |>
  mutate(highlight = keyword %in% top_movers)

labels <- spag |> filter(highlight) |> group_by(keyword) |>
  slice_max(month, n = 1) |> ungroup()

p2 <- ggplot() +
  geom_line(data = filter(spag, !highlight),
            aes(month, roll_avg, group = keyword),
            colour = "grey72", linewidth = 0.3, alpha = 0.55) +
  geom_line(data = filter(spag, highlight),
            aes(month, roll_avg, colour = keyword), linewidth = 1.2) +
  geom_text_repel(data = labels, aes(month, roll_avg, label = keyword, colour = keyword),
                  hjust = 0, direction = "y", nudge_x = 45, size = 3.4,
                  segment.colour = "grey60", seed = 1) +
  scale_colour_manual(values = unname(pal)) +
  scale_y_log10(labels = label_comma()) +
  scale_x_date(expand = expansion(mult = c(0.02, 0.22))) +
  labs(title = "A few titles account for nearly all the growth",
       x = NULL,
       y = glue("Searches per month, {nrow(career)} AI career terms ",
                "(3-month rolling average, log scale)"),
       caption = CAPTION) +
  theme_post()
save_chart(p2, "02_spaghetti_career.png", 12, 8)

# =============================================================================
# 3. Growth vs volume quadrant
# =============================================================================
quad <- career |>
  filter(is.finite(pct_change), avg_monthly_searches > 0) |>
  mutate(lab = if_else(momentum > quantile(momentum, 0.93) |
                         avg_monthly_searches > 4000, keyword, NA_character_))

med_v <- median(quad$avg_monthly_searches)

p3 <- ggplot(quad, aes(avg_monthly_searches, pct_change)) +
  geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.4) +
  geom_vline(xintercept = med_v, linetype = "dashed", colour = "grey55", linewidth = 0.3) +
  geom_point(aes(size = pmax(net_change, 1), fill = pct_change > 0),
             shape = 21, colour = "white", stroke = 0.4, alpha = 0.85) +
  geom_text_repel(aes(label = lab), size = 3.1, max.overlaps = 25,
                  segment.colour = "grey65", segment.linewidth = 0.3, seed = 2) +
  scale_x_log10(labels = label_comma()) +
  scale_y_continuous(labels = label_percent(),
                     trans = scales::pseudo_log_trans(sigma = 0.5),
                     breaks = c(0, 1, 5, 20, 50, 100)) +
  scale_fill_manual(values = c(`TRUE` = pal[["green"]], `FALSE` = pal[["red"]])) +
  scale_size_area(max_size = 13) +
  labs(title = "Growth against volume, every AI career title",
       x = "Average searches per month (log scale)",
       y = "Growth, first 12 months vs last 12 (bubble size = searches gained)",
       caption = CAPTION) +
  theme_post()
save_chart(p3, "03_growth_vs_volume.png", 12, 8.5)

# =============================================================================
# 4. Net gain
# =============================================================================
p4 <- career |> slice_max(net_change, n = 20) |>
  mutate(keyword = fct_reorder(keyword, net_change),
         is_fde = keyword == FDE) |>
  ggplot(aes(net_change, keyword, fill = is_fde)) +
  geom_col(width = 0.72) +
  geom_text(aes(label = label_comma(accuracy = 1)(net_change)),
            hjust = -0.15, size = 3.2, colour = text_axes) +
  scale_fill_manual(values = c(`TRUE` = pal[["green"]], `FALSE` = pal[["blue"]])) +
  scale_x_continuous(labels = label_comma(), expand = expansion(mult = c(0, 0.16))) +
  labs(title = "One title added more searches than the rest combined",
       x = "Searches per month gained, first year vs last", y = NULL, caption = CAPTION) +
  theme_post()
save_chart(p4, "04_net_gain.png", 10, 8)

# =============================================================================
# 5. Fastest growth rate
# =============================================================================
p5 <- career |>
  filter(is.finite(pct_change), avg_monthly_searches >= 200) |>
  slice_max(pct_change, n = 20) |>
  mutate(keyword = fct_reorder(keyword, pct_change),
         is_fde = keyword == FDE) |>
  ggplot(aes(pct_change, keyword, fill = is_fde)) +
  geom_col(width = 0.72) +
  geom_text(aes(label = paste0(round(pct_change * 100), "%")),
            hjust = -0.15, size = 3.2, colour = text_axes) +
  scale_fill_manual(values = c(`TRUE` = pal[["green"]], `FALSE` = pal[["teal"]])) +
  scale_x_continuous(labels = label_percent(), expand = expansion(mult = c(0, 0.16))) +
  labs(title = "The fastest-growing AI job titles",
       x = "Growth, first year vs last (terms averaging 200+ searches/month)",
       y = NULL, caption = CAPTION) +
  theme_post()
save_chart(p5, "05_growth_rate.png", 10, 8)

# =============================================================================
# 6. Consistent growers
# =============================================================================
consistent <- career |> filter(slope > 0, r_squared >= 0.5) |>
  slice_max(momentum, n = 24) |> pull(keyword)

p6 <- rolling |> filter(keyword %in% consistent) |>
  mutate(keyword = factor(keyword, levels = consistent)) |>
  ggplot(aes(month, roll_avg)) +
  geom_area(fill = pal[["blue"]], alpha = 0.16) +
  geom_line(colour = pal[["blue"]], linewidth = 0.75) +
  facet_wrap(~keyword, scales = "free_y", ncol = 4) +
  scale_y_continuous(labels = label_comma(), n.breaks = 3) +
  labs(title = "Titles rising steadily, not spiking",
       x = NULL,
       y = "Searches per month (3-month rolling average; each panel has its own scale)",
       caption = CAPTION) +
  theme_post(11)
save_chart(p6, "06_consistent_growers.png", 13, 9)

# =============================================================================
# 7-9. Cluster rollups
# =============================================================================
cluster_chart <- function(axis, title, file) {
  d <- rolling |> filter(intent == "career") |>
    rename(grp = all_of(axis)) |>
    group_by(grp, month) |>
    summarise(searches = sum(searches), .groups = "drop")

  ends <- d |> group_by(grp) |> slice_max(month, n = 1) |> ungroup()

  p <- ggplot(d, aes(month, searches, colour = grp)) +
    geom_line(linewidth = 1.1) +
    geom_text_repel(data = ends, aes(label = grp), hjust = 0, nudge_x = 100,
                    direction = "y", size = 3.3, segment.colour = "grey65",
                    segment.linewidth = 0.3, seed = 3) +
    scale_colour_manual(values = rep(unname(pal), 3)) +
    scale_y_continuous(labels = label_comma()) +
    scale_x_date(expand = expansion(mult = c(0.02, 0.28))) +
    labs(title = title, x = NULL,
         y = "Searches per month, career-intent terms", caption = CAPTION) +
    theme_post()
  save_chart(p, file, 11, 7)
}

# As in 04_charts_v2.R: this plots level, not growth rate. Engineering leads on
# level and is the slowest-growing cluster in percentage terms. With no subtitle
# to carry that caveat, the title says "biggest" rather than anything about
# growth, so it cannot be read as a rate claim.
cluster_chart("function_",
              "Engineering is by far the biggest AI career cluster",
              "07_by_function.png")

cluster_chart("seniority",
              "People search the role, not the seniority level",
              "08_by_seniority.png")

cluster_chart("domain",
              "AI job searches are mostly industry-agnostic",
              "09_by_domain.png")

# =============================================================================
# 10. Slopegraph
# =============================================================================
slope_d <- career |> slice_max(momentum, n = 16) |>
  select(keyword, first_window, last_window) |>
  pivot_longer(-keyword, names_to = "period", values_to = "searches") |>
  mutate(period = factor(period, c("first_window", "last_window"),
                         c("2022-23", "2025-26")))

p10 <- ggplot(slope_d, aes(period, searches, group = keyword)) +
  geom_line(aes(colour = keyword == FDE, linewidth = keyword == FDE), alpha = 0.85) +
  geom_point(size = 2.2, colour = pal[["blue"]]) +
  geom_text_repel(data = filter(slope_d, period == "2025-26"),
                  aes(label = keyword), hjust = 0, nudge_x = 0.08, size = 3.2,
                  direction = "y", segment.colour = "grey70",
                  segment.linewidth = 0.3, seed = 4) +
  scale_colour_manual(values = c(`TRUE` = pal[["green"]], `FALSE` = pal[["slate"]])) +
  scale_linewidth_manual(values = c(`TRUE` = 1.5, `FALSE` = 0.7)) +
  scale_y_log10(labels = label_comma()) +
  scale_x_discrete(expand = expansion(mult = c(0.12, 0.62))) +
  labs(title = "First year against last, the 16 strongest movers",
       x = NULL, y = "Searches per month (log scale)", caption = CAPTION) +
  theme_post()
save_chart(p10, "10_slopegraph.png", 9.5, 8)

# =============================================================================
# 11. Career vs tool, term by term
# =============================================================================
contrast <- bind_rows(
  career |> slice_max(avg_monthly_searches, n = 12) |> mutate(grp = "Career: a job doing the work"),
  tools  |> slice_max(avg_monthly_searches, n = 12) |> mutate(grp = "Tool: software doing the work")
) |>
  arrange(grp, avg_monthly_searches) |>
  mutate(keyword = factor(keyword, levels = unique(keyword)))

p11 <- ggplot(contrast, aes(avg_monthly_searches, keyword, fill = grp)) +
  geom_col(width = 0.72) +
  facet_wrap(~grp, scales = "free", ncol = 2) +
  scale_fill_manual(values = c(pal[["slate"]], pal[["red"]])) +
  scale_x_continuous(labels = label_comma(), expand = expansion(mult = c(0, 0.14))) +
  labs(title = "The same word, two different searches",
       x = "Average searches per month (note the panels use different scales)",
       y = NULL, caption = CAPTION) +
  theme_post()
save_chart(p11, "11_career_vs_tool.png", 12, 6.5)

# =============================================================================
# 12. prompt -> context -> forward deployed
# =============================================================================
succession <- rolling |>
  filter(keyword %in% c("prompt engineer", "context engineer",
                        "ai engineer", FDE))

sx_lab <- succession |> group_by(keyword) |> slice_max(month, n = 1) |> ungroup()
peaks <- succession |>
  filter(keyword %in% c("prompt engineer", "context engineer")) |>
  group_by(keyword) |> slice_max(roll_avg, n = 1) |> ungroup()

succ_cols <- c(`prompt engineer` = pal[["red"]], `context engineer` = pal[["orange"]],
               `ai engineer` = pal[["blue"]])
succ_cols[[FDE]] <- pal[["green"]]

p12 <- ggplot(succession, aes(month, roll_avg, colour = keyword)) +
  geom_line(aes(linewidth = keyword == FDE)) +
  geom_point(data = peaks, size = 3) +
  geom_text_repel(data = peaks,
                  aes(label = paste0("peaked ", format(month, "%b %Y"), "\n",
                                     label_comma()(roll_avg), "/mo")),
                  nudge_y = 0.18, nudge_x = -240, size = 3.1, lineheight = 1,
                  segment.colour = "grey55", show.legend = FALSE, seed = 7) +
  geom_text_repel(data = sx_lab, aes(label = keyword), hjust = 0, nudge_x = 45,
                  direction = "y", size = 3.5, segment.colour = "grey65", seed = 8) +
  scale_colour_manual(values = succ_cols) +
  scale_linewidth_manual(values = c(`TRUE` = 1.7, `FALSE` = 1.2)) +
  scale_y_log10(labels = label_comma()) +
  scale_x_date(expand = expansion(mult = c(0.02, 0.26))) +
  labs(title = "Prompt engineer has been replaced twice",
       x = NULL,
       y = "Searches per month (3-month rolling average, log scale)",
       caption = CAPTION) +
  theme_post()
save_chart(p12, "12_prompt_to_context.png", 11, 7.5)

# =============================================================================
# 13. The FDE step change on its own
# =============================================================================
fde_ts <- rolling |> filter(keyword == FDE) |> mutate(month = as.Date(month))
takeoff <- fde_ts |> filter(month == as.Date("2025-02-01"))
latest  <- fde_ts |> slice_max(month, n = 1)
stopifnot(nrow(takeoff) == 1, nrow(latest) == 1,
          format(takeoff$month, "%Y-%m") == "2025-02")

p13 <- ggplot(fde_ts, aes(month, searches)) +
  annotate("rect", xmin = as.Date("2022-09-01"), xmax = as.Date("2025-01-31"),
           ymin = -Inf, ymax = Inf, fill = "grey70", alpha = 0.16) +
  annotate("text", x = as.Date("2023-11-01"), y = 30000,
           label = "Palantir-era baseline:\nflat at ~400/month for 29 months",
           size = 3.4, colour = "grey35", lineheight = 1.05) +
  geom_line(colour = pal[["green"]], linewidth = 1.5) +
  geom_point(data = bind_rows(takeoff, latest), size = 3, colour = pal[["green"]]) +
  geom_text_repel(data = takeoff,
                  aes(label = glue("Feb 2025\n{label_comma()(searches)}/mo")),
                  nudge_y = 6000, nudge_x = -200, size = 3.3, lineheight = 1,
                  colour = text_axes, segment.colour = "grey55", seed = 11) +
  geom_text_repel(data = latest,
                  aes(label = glue("Aug 2026\n{label_comma()(searches)}/mo")),
                  nudge_y = -7000, nudge_x = -260, size = 3.3, lineheight = 1,
                  colour = text_axes, segment.colour = "grey55", seed = 12) +
  scale_y_continuous(labels = label_comma()) +
  labs(title = "Forward deployed engineer, a step change not a trend",
       x = NULL, y = "Searches per month", caption = CAPTION) +
  theme_post()
save_chart(p13, "13_fde_stepchange.png", 12, 7)

# =============================================================================
# 14. Recent level vs the 12-month average that hides it
# =============================================================================
lead_order <- career |> slice_max(last3, n = 12) |> arrange(last3) |> pull(keyword)

lead_d <- career |> filter(keyword %in% lead_order) |>
  select(keyword, `Last 3 months` = last3, `12-month average` = avg_monthly_searches) |>
  pivot_longer(-keyword, names_to = "measure", values_to = "searches") |>
  mutate(keyword = factor(keyword, levels = lead_order),
         measure = factor(measure, c("12-month average", "Last 3 months")))

p14 <- ggplot(lead_d, aes(searches, keyword, fill = measure)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7) +
  scale_fill_manual(values = c(`12-month average` = "grey65",
                               `Last 3 months` = pal[["green"]]),
                    labels = c(`12-month average` = "Trailing 12-month average (as reported)",
                               `Last 3 months` = "Last 3 months (Jun-Aug 2026)")) +
  scale_x_continuous(labels = label_comma(), expand = expansion(mult = c(0, 0.12))) +
  labs(title = "The reported average hides a title that stepped up",
       x = "Searches per month", y = NULL, caption = CAPTION) +
  theme_post() + theme_legend()
save_chart(p14, "14_recent_vs_average.png", 11, 7.5)

# =============================================================================
# 15. How far each big career title is off its own peak
# =============================================================================
peak_d <- career |> filter(last3 >= 800) |> slice_max(peak, n = 16) |>
  mutate(keyword = fct_reorder(keyword, off_peak),
         band = case_when(off_peak > -0.15 ~ "at or near its peak",
                          off_peak > -0.5  ~ "well off peak",
                          TRUE             ~ "past its moment"))

p15 <- ggplot(peak_d, aes(off_peak, keyword, fill = band)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = percent(off_peak, accuracy = 1),
                hjust = if_else(off_peak > -0.06, -0.25, 1.2)),
            size = 3.2, colour = text_axes) +
  scale_fill_manual(values = c(`at or near its peak` = pal[["green"]],
                               `well off peak` = pal[["yellow"]],
                               `past its moment` = pal[["red"]]),
                    breaks = c("at or near its peak", "well off peak", "past its moment")) +
  scale_x_continuous(labels = label_percent(),
                     expand = expansion(mult = c(0.12, 0.10))) +
  labs(title = "Most AI job titles are already past their peak",
       x = "Last 3 months against the title's own best month", y = NULL, caption = CAPTION) +
  theme_post() + theme_legend()
save_chart(p15, "15_off_peak.png", 11, 8)

message("\nAll charts written to ", OUT_DIR, "/")
