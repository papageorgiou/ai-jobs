# Exploratory charts for the AI job-title search-volume study.
#
# Two populations run through every chart and must never be silently mixed:
#   career    - people researching a job ("ai engineer", "prompt engineer")
#   tool-risk - people shopping for software ("ai photo editor", "ai lawyer")
# The tool-risk terms carry 71% of all volume, so any chart that pools them
# shows AI product demand while appearing to show job-title demand.

library(arrow)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggtext)
library(ggrepel)
library(scales)
library(stringr)
library(forcats)

dir.create("output/charts", showWarnings = FALSE, recursive = TRUE)

# --- Style (Warm Ledger, per the dataviz-linkedin skill) ----------------------
bg_plot   <- "#F6EFE8"
bg_figure <- "#FAF8F5"
gridlines <- "#E2D6CB"
text_axes <- "#2B2F33"

pal <- c(blue = "#2B5FB8", red = "#B83A2F", yellow = "#8F6A00", green = "#13734A",
         purple = "#6B4FA3", teal = "#1F7A7A", orange = "#C05A1A",
         rose = "#B44A7A", slate = "#4E5A63")

# element_textbox_simple does not reserve height for lines it wraps itself, so a
# two-line title collides with the subtitle. Wrap explicitly and use
# element_markdown, which does account for hard breaks.
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
      plot.title         = element_markdown(size = rel(1.45), face = "bold", hjust = 0,
                                            margin = margin(b = 8), lineheight = 1.25),
      # Subtitles carry inline <span> colour, which strwrap would split mid-tag,
      # so let textbox_simple wrap them itself. Only the title is hand-wrapped.
      plot.subtitle      = element_textbox_simple(size = rel(1.0), colour = "grey30",
                                                  margin = margin(b = 14), lineheight = 1.35),
      plot.caption       = element_text(size = rel(0.75), colour = "grey45", hjust = 0),
      legend.position    = "none",
      strip.text         = element_text(face = "bold", size = rel(0.8)),
      plot.margin        = margin(16, 18, 12, 16)
    )
}

CAPTION <- paste("Source: Google Ads Keyword Planner, US, Aug 2022 - Jul 2026.",
                 "Retrieved 2026-07-29. Volumes are rounded buckets, not exact counts.",
                 "\nCode: github.com/papageorgiou/ai-jobs")

save_chart <- function(plot, name, w = 10, h = 8) {
  # Wrap centrally so every chart gets it, rather than hand-wrapping each labs().
  # Title wraps narrower because it renders ~45% larger than the subtitle.
  if (!is.null(plot$labels$title))
    plot$labels$title <- wrap_md(plot$labels$title, floor(w * 7.4))
  ggsave(file.path("output/charts", name), plot, width = w, height = h, dpi = 150)
  message("wrote ", name)
}

# --- Data ---------------------------------------------------------------------
clusters <- read_parquet("output/clusters.parquet")
rolling  <- read_parquet("output/rolling.parquet") |>
  left_join(clusters |> select(keyword, function_ = "function", seniority, domain, intent,
                               momentum, pct_change, net_change),
            by = "keyword")

career <- clusters |> filter(intent == "career")
tools  <- clusters |> filter(intent == "tool-risk")

# =============================================================================
# 1. The headline split - where the volume actually is
# =============================================================================
split_ts <- rolling |>
  group_by(intent, month) |>
  summarise(searches = sum(searches), .groups = "drop")

p1 <- ggplot(split_ts, aes(month, searches, colour = intent)) +
  geom_line(linewidth = 1.4) +
  scale_colour_manual(values = c(career = pal[["slate"]], `tool-risk` = pal[["red"]])) +
  scale_y_continuous(labels = label_comma()) +
  labs(
    title = "Most \"AI job title\" search demand is people shopping for software, not careers",
    subtitle = glue::glue(
      "Monthly US searches across 283 AI job titles, split by what the searcher wants: ",
      "<span style='color:{pal[['red']]}'>**an AI tool that does the job**</span> vs ",
      "<span style='color:{pal[['slate']]}'>**a career doing the job**</span>."),
    x = NULL, y = "Searches per month", caption = CAPTION) +
  theme_post()
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
  # Log scale: "prompt engineer" peaks at 74K while the emerging titles sit in
  # the hundreds, so a linear axis renders every line of interest as flat.
  scale_y_log10(labels = label_comma()) +
  scale_x_date(expand = expansion(mult = c(0.02, 0.22))) +
  labs(title = "A handful of AI job titles account for nearly all the growth",
       subtitle = paste0("Each grey line is one of ", nrow(career),
                         " AI career search terms; the eight with the strongest ",
                         "momentum are highlighted. 3-month rolling average, log scale."),
       x = NULL, y = "Searches per month", caption = CAPTION) +
  theme_post()
save_chart(p2, "02_spaghetti_career.png", 12, 8)

# =============================================================================
# 3. Growth vs volume quadrant - the angle-picking chart
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
  # A handful of terms grew 5,000-9,000% off a near-zero base and flatten
  # everything else on a linear axis. sqrt keeps them visible without letting
  # them own the scale.
  scale_y_continuous(labels = label_percent(),
                     trans = scales::pseudo_log_trans(sigma = 0.5),
                     breaks = c(0, 1, 5, 20, 50, 100)) +
  scale_fill_manual(values = c(`TRUE` = pal[["green"]], `FALSE` = pal[["red"]])) +
  scale_size_area(max_size = 13) +
  labs(title = "Small and exploding, or big and steady - very few titles are both",
       subtitle = paste("Every AI career search term. Horizontal = how much it is searched;",
                        "vertical = growth from the first year to the last.",
                        "Bubble size = searches per month gained."),
       x = "Average searches per month (log scale)",
       y = "Growth, first 12 months vs last 12", caption = CAPTION) +
  theme_post()
save_chart(p3, "03_growth_vs_volume.png", 12, 8.5)

# =============================================================================
# 4. Net gain - who actually added the most searches
# =============================================================================
p4 <- career |> slice_max(net_change, n = 20) |>
  mutate(keyword = fct_reorder(keyword, net_change)) |>
  ggplot(aes(net_change, keyword)) +
  geom_col(fill = pal[["blue"]], width = 0.72) +
  geom_text(aes(label = label_comma(accuracy = 1)(net_change)),
            hjust = -0.15, size = 3.2, colour = text_axes) +
  scale_x_continuous(labels = label_comma(), expand = expansion(mult = c(0, 0.16))) +
  labs(title = "Ranked by searches actually gained, the list looks very different",
       subtitle = paste("Absolute monthly searches added between the first and last year",
                        "of the window. Percentage growth flatters tiny terms;",
                        "this does not."),
       x = "Searches per month gained", y = NULL, caption = CAPTION) +
  theme_post()
save_chart(p4, "04_net_gain.png", 10, 8)

# =============================================================================
# 5. Fastest growth rate - the other half of the picture
# =============================================================================
p5 <- career |>
  filter(is.finite(pct_change), avg_monthly_searches >= 200) |>
  slice_max(pct_change, n = 20) |>
  mutate(keyword = fct_reorder(keyword, pct_change)) |>
  ggplot(aes(pct_change, keyword)) +
  geom_col(fill = pal[["teal"]], width = 0.72) +
  geom_text(aes(label = paste0(round(pct_change * 100), "%")),
            hjust = -0.15, size = 3.2, colour = text_axes) +
  scale_x_continuous(labels = label_percent(), expand = expansion(mult = c(0, 0.16))) +
  labs(title = "The fastest-growing AI job searches are roles that did not exist in 2022",
       subtitle = paste("Growth from the first 12 months to the last.",
                        "Restricted to terms averaging 200+ searches/month,",
                        "so rounding noise cannot top the chart."),
       x = "Growth, first year vs last", y = NULL, caption = CAPTION) +
  theme_post()
save_chart(p5, "05_growth_rate.png", 10, 8)

# =============================================================================
# 6. Consistent growers - facets
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
       subtitle = paste("AI career terms with a positive linear trend and R-squared of 0.5+,",
                        "ranked by momentum. Each panel has its own y-scale --",
                        "compare shapes, not heights."),
       x = NULL, y = "Searches per month (3-month rolling average)", caption = CAPTION) +
  theme_post(11)
save_chart(p6, "06_consistent_growers.png", 13, 9)

# =============================================================================
# 7-9. Cluster rollups
# =============================================================================
cluster_chart <- function(axis, title, sub, file) {
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
    labs(title = title, subtitle = sub, x = NULL,
         y = "Searches per month", caption = CAPTION) +
    theme_post()
  save_chart(p, file, 11, 7)
}

cluster_chart("function_",
              "Engineering is not where AI hiring curiosity is growing fastest",
              "Total monthly searches for AI career terms, grouped by what the role does. Career-intent terms only.",
              "07_by_function.png")

cluster_chart("seniority",
              "Almost nobody searches AI job titles with a seniority attached",
              paste("Grouped by seniority marker in the title.",
                    "The 'unspecified' line dwarfing the rest is itself the finding --",
                    "people search the role, not the level."),
              "08_by_seniority.png")

cluster_chart("domain",
              "AI job searches are still overwhelmingly industry-agnostic",
              "Grouped by industry named in the title. Career-intent terms only.",
              "09_by_domain.png")

# =============================================================================
# 10. Slopegraph - first year vs last year
# =============================================================================
slope_d <- career |> slice_max(momentum, n = 16) |>
  select(keyword, first_window, last_window) |>
  pivot_longer(-keyword, names_to = "period", values_to = "searches") |>
  mutate(period = factor(period, c("first_window", "last_window"),
                         c("2022-23", "2025-26")))

p10 <- ggplot(slope_d, aes(period, searches, group = keyword)) +
  geom_line(colour = pal[["slate"]], linewidth = 0.7, alpha = 0.8) +
  geom_point(size = 2.2, colour = pal[["blue"]]) +
  geom_text_repel(data = filter(slope_d, period == "2025-26"),
                  aes(label = keyword), hjust = 0, nudge_x = 0.08, size = 3.2,
                  direction = "y", segment.colour = "grey70",
                  segment.linewidth = 0.3, seed = 4) +
  scale_y_log10(labels = label_comma()) +
  scale_x_discrete(expand = expansion(mult = c(0.12, 0.62))) +
  labs(title = "Four years of movement in the AI titles with the strongest momentum",
       subtitle = "Average monthly searches in the first year of the window vs the last. Log scale.",
       x = NULL, y = "Searches per month", caption = CAPTION) +
  theme_post()
save_chart(p10, "10_slopegraph.png", 9.5, 8)

# =============================================================================
# 11. Career vs tool, term by term - the contrast made concrete
# =============================================================================
contrast <- bind_rows(
  career |> slice_max(avg_monthly_searches, n = 12) |> mutate(grp = "Career: a job doing the work"),
  tools  |> slice_max(avg_monthly_searches, n = 12) |> mutate(grp = "Tool: software doing the work")
) |>
  # Facets have independent scales, so order the bars globally and let each
  # panel drop the levels it does not use.
  arrange(grp, avg_monthly_searches) |>
  mutate(keyword = factor(keyword, levels = unique(keyword)))

p11 <- ggplot(contrast, aes(avg_monthly_searches, keyword, fill = grp)) +
  geom_col(width = 0.72) +
  facet_wrap(~grp, scales = "free", ncol = 2) +
  scale_fill_manual(values = c(pal[["slate"]], pal[["red"]])) +
  scale_x_continuous(labels = label_comma(), expand = expansion(mult = c(0, 0.14))) +
  labs(title = "The same word, two completely different searches",
       subtitle = paste("Biggest AI career terms next to the biggest AI tool terms.",
                        "Note the axis scales differ by an order of magnitude."),
       x = "Average searches per month", y = NULL, caption = CAPTION) +
  theme_post()
save_chart(p11, "11_career_vs_tool.png", 12, 6.5)

# =============================================================================
# 12. The succession story - prompt engineer peaked, context engineer replaced it
# =============================================================================
succession <- rolling |>
  filter(keyword %in% c("prompt engineer", "context engineer",
                        "ai engineer", "ai agent architect"))

sx_lab <- succession |> group_by(keyword) |> slice_max(month, n = 1) |> ungroup()
peak <- succession |> filter(keyword == "prompt engineer") |> slice_max(roll_avg, n = 1)

p12 <- ggplot(succession, aes(month, roll_avg, colour = keyword)) +
  geom_line(linewidth = 1.3) +
  geom_point(data = peak, size = 3) +
  geom_text_repel(data = peak,
                  aes(label = paste0("peaked ", format(month, "%b %Y"), "\n",
                                     label_comma()(roll_avg), "/mo")),
                  nudge_y = 0.18, nudge_x = -240, size = 3.3, lineheight = 1,
                  segment.colour = "grey55", show.legend = FALSE, seed = 7) +
  geom_text_repel(data = sx_lab, aes(label = keyword), hjust = 0, nudge_x = 45,
                  direction = "y", size = 3.5, segment.colour = "grey65", seed = 8) +
  scale_colour_manual(values = c(`prompt engineer` = pal[["red"]],
                                 `context engineer` = pal[["green"]],
                                 `ai engineer` = pal[["blue"]],
                                 `ai agent architect` = pal[["orange"]])) +
  scale_y_log10(labels = label_comma()) +
  scale_x_date(expand = expansion(mult = c(0.02, 0.24))) +
  labs(
    title = "\"Prompt engineer\" already peaked - and something else took its place",
    subtitle = glue::glue(
      "<span style='color:{pal[['red']]}'>**Prompt engineer**</span> peaked in mid-2023 and is down roughly two-thirds from that high. ",
      "<span style='color:{pal[['green']]}'>**Context engineer**</span> went from near-zero to five figures in a single year, ",
      "while <span style='color:{pal[['blue']]}'>**AI engineer**</span> just kept climbing. Log scale."),
    x = NULL, y = "Searches per month (3-month rolling average)", caption = CAPTION) +
  theme_post()
save_chart(p12, "12_prompt_to_context.png", 11, 7.5)

message("\nAll charts written to output/charts/")
