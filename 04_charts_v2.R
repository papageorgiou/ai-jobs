# Exploratory charts for the AI job-title search-volume study, v2.
#
# v2 differs from v1 in exactly one input: the title "Forward Deployed Engineer"
# is added to the master list, and the pull was rerun (window moved one month,
# to Aug 2022 - Jul 2026). This is a separate file rather than a parameterised
# 04_charts.R because several v1 chart *conclusions* no longer hold - notably
# "Engineering is not where AI hiring curiosity is growing fastest" (chart 7)
# and the prompt -> context succession (chart 12). v1 stays reproducible as-is.
#
# Two populations run through every chart and must never be silently mixed:
#   career    - people researching a job ("ai engineer", "forward deployed engineer")
#   tool-risk - people shopping for software ("ai photo editor", "ai lawyer")

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
OUT_DIR <- file.path(IN_DIR, "charts")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

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
      # b = 16 rather than v1's 8: element_markdown reserves height for the hard
      # breaks wrap_md inserts, but at b = 8 a two-line title still sits almost
      # on the subtitle's first line.
      plot.title         = element_markdown(size = rel(1.45), face = "bold", hjust = 0,
                                            margin = margin(b = 16), lineheight = 1.25),
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

CAPTION <- NULL   # built from the data once it is loaded; see below

save_chart <- function(plot, name, w = 10, h = 8) {
  # Wrap centrally so every chart gets it, rather than hand-wrapping each labs().
  # Title wraps narrower because it renders ~45% larger than the subtitle. v1
  # used 7.4 chars/inch; the longer v2 titles overflow the canvas at that, so
  # this is tightened to 6.5.
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

# Recent level and own-peak, per keyword. avg_monthly_searches is a trailing
# 12-month mean, which badly understates a term that stepped up mid-window -
# the whole FDE story is invisible in it.
recent <- rolling |>
  group_by(keyword) |>
  arrange(month, .by_group = TRUE) |>
  summarise(last3     = mean(tail(searches, 3)),
            peak      = max(searches),
            peak_month = month[which.max(searches)],
            .groups   = "drop") |>
  mutate(off_peak = last3 / peak - 1)

clusters <- clusters |> left_join(recent, by = "keyword")

# The window is stated from the data, not typed. v2 was originally captioned
# "Sep 2022 - Aug 2026" because 02_stats.py added a spurious +1 to the API's own
# month labels; the pull ran 2026-08-20 and can only reach the last complete
# month, July 2026. A wrong-but-plausible date range is invisible downstream, so
# derive it rather than restate it.
win <- range(as.Date(rolling$month))
CAPTION <- paste0(
  "Source: Google Data, US, ", format(win[1], "%b %Y"), " - ", format(win[2], "%b %Y"),
  ". Retrieved 2026-08-20 (v2). Volumes are rounded buckets, not exact counts.",
  "\nAnalysis & code: github.com/papageorgiou/ai-jobs   |   @alex_papageo")

# The two spaghetti charts are the ones that go out as standalone images, where
# the retrieval date and the rounding caveat are noise the feed reader will not
# act on. They stay on every other chart and in the report.
CAPTION_SHORT <- paste0(
  "Source: Google Data, US, ", format(win[1], "%b %Y"), " - ", format(win[2], "%b %Y"), ".",
  "\nAnalysis & code: github.com/papageorgiou/ai-jobs   |   @alex_papageo")

career <- clusters |> filter(intent == "career")
tools  <- clusters |> filter(intent == "tool-risk")
FDE    <- "forward deployed engineer"

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
    subtitle = glue(
      "Monthly US searches across {nrow(clusters)} AI job titles, split by what the searcher wants: ",
      "<span style='color:{pal[['red']]}'>**an AI tool that does the job**</span> vs ",
      "<span style='color:{pal[['slate']]}'>**a career doing the job**</span>."),
    x = NULL, y = "Searches per month", caption = CAPTION) +
  theme_post()
save_chart(p1, "01_intent_split.png", 11, 7)

# =============================================================================
# 2. Spaghetti - career titles, the four that carry the story highlighted
# =============================================================================
# Hand-picked rather than taken from slice_max(momentum, n = 8): these four are
# the succession narrative (prompt -> context -> forward deployed) plus the
# steady incumbent (ai engineer). Momentum's top 8 pulls in tiny terms that are
# noise at this scale. `ai strategy consultant` was a fifth line and is dropped:
# at ~800/month it sits a decade and a half below the other three and made the
# reader track a series that is not part of the succession story.
highlights <- c(FDE, "prompt engineer", "context engineer", "ai engineer")
stopifnot(all(highlights %in% career$keyword))

# Red is the subject's colour, not prompt engineer's. That is a swap from the
# earlier version of this chart, where FDE was green and red went to the term
# with the tallest peak - which put the loudest colour on the line the chart is
# arguing *against*. Prompt engineer takes the purple freed up by dropping
# `ai strategy consultant`; ai engineer and context engineer keep blue and
# orange, so only two of the four mappings moved.
FDE_COL <- pal[["red"]]
hl_cols <- c(pal[["purple"]], pal[["orange"]], pal[["blue"]])
names(hl_cols) <- c("prompt engineer", "context engineer", "ai engineer")
hl_cols[[FDE]] <- FDE_COL
stopifnot(setequal(names(hl_cols), highlights))

# End labels run 1.5x the 3.5 the rest of the chart uses - they are the only
# text a feed reader zooms into. The right-hand pad below grows with them.
LAB_SIZE <- 5.3
PAD_DAYS <- 650

# Y floor at 10 rather than the series minimum: below that a log axis spends a
# third of its height on rounding noise (94 of 9,597 career points, none of them
# a term anyone is reading the chart for). Censor rather than clamp - pmax()ing
# to the floor would draw a solid wall of fake flat lines along the axis.
Y_FLOOR <- 10

spag <- rolling |>
  filter(intent == "career") |>
  mutate(highlight = keyword %in% highlights,
         is_fde    = keyword == FDE)

labels <- spag |> filter(highlight) |> group_by(keyword) |>
  slice_max(month, n = 1) |> ungroup()

fde_line <- filter(spag, is_fde)
x_rng    <- range(as.Date(spag$month))

p2 <- ggplot() +
  geom_line(data = filter(spag, !highlight),
            aes(month, roll_avg, group = keyword),
            colour = "grey78", linewidth = 0.28, alpha = 0.45) +
  geom_line(data = filter(spag, highlight, !is_fde),
            aes(month, roll_avg, colour = keyword), linewidth = 1.1) +
  # FDE gets a pale casing under a heavy stroke so it reads as the subject even
  # where it crosses the other highlighted lines.
  geom_line(data = fde_line, aes(month, roll_avg),
            colour = bg_plot, linewidth = 4.4, lineend = "round") +
  geom_line(data = fde_line, aes(month, roll_avg),
            colour = FDE_COL, linewidth = 2.3, lineend = "round") +
  geom_point(data = filter(labels, is_fde), aes(month, roll_avg),
             colour = FDE_COL, size = 3.6) +
  # ggrepel has no markdown, and the FDE label is the one that needs bolding -
  # but it is also the only one with clear air around it, so it can be placed
  # directly while the other three are repelled apart from each other.
  ggtext::geom_richtext(
    data = filter(labels, is_fde),
    aes(month, roll_avg,
        label = paste0("**", keyword, "**<br>", label_comma()(roll_avg), "/mo")),
    hjust = 0, nudge_x = 40, size = LAB_SIZE, lineheight = 1.15,
    colour = FDE_COL, fill = NA, label.colour = NA,
    label.padding = unit(1.5, "pt")) +
  geom_text_repel(
    data = filter(labels, !is_fde),
    aes(month, roll_avg, label = keyword, colour = keyword),
    hjust = 0, direction = "y", nudge_x = 40, size = LAB_SIZE,
    min.segment.length = 0.2, segment.colour = "grey60", seed = 1) +
  scale_colour_manual(values = hl_cols) +
  # Log scale: the biggest career terms sit in the tens of thousands while the
  # emerging ones sit in the hundreds, so a linear axis flattens everything.
  scale_y_log10(labels = label_comma(), limits = c(Y_FLOOR, NA),
                breaks = c(10, 100, 1000, 10000, 50000)) +
  # Breaks come from the data range, and the right-hand pad is added through
  # limits rather than expansion() - expansion() also stretches the break
  # sequence, which ran the axis a year past the last month of data.
  scale_x_date(breaks = unique(c(seq(x_rng[1], x_rng[2], by = "6 months"), x_rng[2])),
               date_labels = "%b %Y",
               # Pad in days, sized to the longest end-label ("forward deployed
               # engineer"), which otherwise clips against the panel edge. It
               # scales with LAB_SIZE - it was 430 back when the labels were 3.5.
               limits = c(x_rng[1], x_rng[2] + PAD_DAYS),
               expand = expansion(mult = c(0.02, 0))) +
  labs(
    title = "\"Forward deployed engineer\" is now America's most-searched AI career title",
    x = NULL, y = "Searches per month", caption = CAPTION_SHORT) +
  theme_post()
save_chart(p2, "02_spaghetti_career.png", 12, 8)

# =============================================================================
# 2b. Same four lines, no spaghetti - plus the Karpathy annotation
# =============================================================================
# A stripped version of chart 2 for the post itself. The 255 grey lines are the
# evidence that the four are not cherry-picked, which matters in a report and
# costs legibility in a feed, so the variant drops them. Everything else - the
# palette, the FDE casing, the log axis, the end labels - is identical, so the
# two charts read as the same chart twice rather than as two charts.
#
# The addition is an explanation for the one move on this chart that a reader
# cannot account for from the chart itself: context engineer sitting at ~90
# searches/month for thirty-four months and then multiplying 160x in two. That
# was Karpathy's 25 Jun 2025 post ("+1 for 'context engineering' over 'prompt
# engineering'", x.com/karpathy/status/1937902205765607626). A single tweet
# moving a national search series is the point worth making, so it is drawn as
# an annotation rather than left to the caption.
KARPATHY_IMG   <- "karpathy/karpathy_circle.png"
KARPATHY_MONTH <- as.Date("2025-06-01")   # the tweet month, first month of lift

# Anchor the arrow on the line itself rather than at a typed y: the series is
# plotted as a 3-month rolling average, so the June point is ~600, not the
# 1,600 the raw month shows.
ce_anchor <- spag |> filter(keyword == "context engineer",
                            as.Date(month) == KARPATHY_MONTH)

# Y floor lifted from 10 to 40: without the grey mass, and without
# `ai strategy consultant`, the lowest point on the chart is context engineer's
# 57. The empty decades below were only ever there to hold the spaghetti.
Y_FLOOR_5 <- 40

spag5 <- filter(spag, highlight)

p2b <- ggplot() +
  geom_line(data = filter(spag5, !is_fde),
            aes(month, roll_avg, colour = keyword), linewidth = 1.2) +
  geom_line(data = fde_line, aes(month, roll_avg),
            colour = bg_plot, linewidth = 4.4, lineend = "round") +
  geom_line(data = fde_line, aes(month, roll_avg),
            colour = FDE_COL, linewidth = 2.3, lineend = "round") +
  geom_point(data = filter(labels, is_fde), aes(month, roll_avg),
             colour = FDE_COL, size = 3.6) +

  # --- the annotation -------------------------------------------------------
  # Drawn before the labels so nothing of the arrow crosses a line label. The
  # curve arcs left-and-up out of the text block to the elbow, which keeps it
  # clear of the context engineer line's near-vertical segment.
  geom_point(data = ce_anchor, aes(month, roll_avg),
             colour = pal[["orange"]], size = 3.2) +
  geom_curve(aes(x = as.Date("2025-09-20"), y = 385,
                 xend = KARPATHY_MONTH + 20, yend = ce_anchor$roll_avg * 0.84),
             curvature = 0.42, angle = 105, ncp = 14,
             arrow = arrow(length = unit(0.022, "npc"), type = "closed"),
             colour = pal[["orange"]], linewidth = 0.6) +
  ggimage::geom_image(
    data = data.frame(x = as.Date("2025-12-10"), y = 235),
    aes(x, y), image = KARPATHY_IMG, size = 0.10, asp = 12 / 8) +
  ggtext::geom_richtext(
    data = data.frame(x = as.Date("2025-12-10"), y = 68),
    aes(x, y, label = paste0(
      "**Karpathy tweets<br>\"context engineering\"**<br>",
      "<span style='font-size:8pt'>25 Jun 2025</span>")),
    size = 3.5, lineheight = 1.25, colour = pal[["orange"]],
    fill = NA, label.colour = NA, label.padding = unit(2, "pt")) +

  ggtext::geom_richtext(
    data = filter(labels, is_fde),
    aes(month, roll_avg,
        label = paste0("**", keyword, "**<br>", label_comma()(roll_avg), "/mo")),
    hjust = 0, nudge_x = 40, size = LAB_SIZE, lineheight = 1.15,
    colour = FDE_COL, fill = NA, label.colour = NA,
    label.padding = unit(1.5, "pt")) +
  geom_text_repel(
    data = filter(labels, !is_fde),
    aes(month, roll_avg, label = keyword, colour = keyword),
    hjust = 0, direction = "y", nudge_x = 40, size = LAB_SIZE,
    min.segment.length = 0.2, segment.colour = "grey60", seed = 1) +
  scale_colour_manual(values = hl_cols) +
  scale_y_log10(labels = label_comma(), limits = c(Y_FLOOR_5, NA),
                breaks = c(50, 100, 1000, 10000, 50000)) +
  scale_x_date(breaks = unique(c(seq(x_rng[1], x_rng[2], by = "6 months"), x_rng[2])),
               date_labels = "%b %Y",
               limits = c(x_rng[1], x_rng[2] + PAD_DAYS),
               expand = expansion(mult = c(0.02, 0))) +
  labs(
    title = "\"Forward deployed engineer\" is now America's most-searched AI career title",
    x = NULL, y = "Searches per month", caption = CAPTION_SHORT) +
  theme_post()
save_chart(p2b, "02b_spaghetti_five_karpathy.png", 12, 8)

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
  # everything else on a linear axis. pseudo-log keeps them visible without
  # letting them own the scale.
  scale_y_continuous(labels = label_percent(),
                     trans = scales::pseudo_log_trans(sigma = 0.5),
                     breaks = c(0, 1, 5, 20, 50, 100)) +
  scale_fill_manual(values = c(`TRUE` = pal[["green"]], `FALSE` = pal[["red"]])) +
  scale_size_area(max_size = 13) +
  labs(title = "Small and exploding, or big and steady - with one exception",
       subtitle = glue(
         "Every AI career search term. Horizontal = how much it is searched; vertical = growth ",
         "from the first year to the last. Bubble size = searches per month gained. ",
         "<span style='color:{pal[['green']]}'>**Forward deployed engineer**</span> is the ",
         "biggest bubble on the chart: joint-largest by volume *and* the largest net gain of ",
         "any AI career term."),
       x = "Average searches per month (log scale)",
       y = "Growth, first 12 months vs last 12", caption = CAPTION) +
  theme_post()
save_chart(p3, "03_growth_vs_volume.png", 12, 8.5)

# =============================================================================
# 4. Net gain - who actually added the most searches
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
  labs(title = "Ranked by searches actually gained, one title dwarfs the rest",
       subtitle = paste("Absolute monthly searches added between the first and last year",
                        "of the window. Percentage growth flatters tiny terms; this does not."),
       x = "Searches per month gained", y = NULL, caption = CAPTION) +
  theme_post()
save_chart(p4, "04_net_gain.png", 10, 8)

# =============================================================================
# 5. Fastest growth rate - the other half of the picture
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

# v1's title was "Engineering is not where AI hiring curiosity is growing
# fastest", meaning growth *rate*. That still holds in v2: engineering grew
# +114% first year vs last, the slowest of the ten clusters. What FDE changes is
# the absolute gap - engineering's net gain goes from +39,159 to +48,958
# searches/month, more than three times the next cluster. Rate and level
# disagree here, so the title names the one the chart actually plots (level).
cluster_chart("function_",
              "Engineering dwarfs every other AI career cluster, and the gap just widened",
              paste("Total monthly searches for AI career terms, grouped by what the role does.",
                    "Career-intent terms only. The engineering line's 2025-26 lift is almost",
                    "entirely one title: forward deployed engineer. Note this is level, not",
                    "growth rate -- engineering is still the slowest-growing cluster in",
                    "percentage terms."),
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
# 12. The succession story, revised: prompt -> context -> forward deployed
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
  labs(
    title = "\"Prompt engineer\" has now been replaced twice",
    subtitle = glue(
      "<span style='color:{pal[['red']]}'>**Prompt engineer**</span> peaked mid-2023 and is down 77%. ",
      "<span style='color:{pal[['orange']]}'>**Context engineer**</span> - the successor v1 identified - ",
      "peaked in late 2025 and is already down 74%. ",
      "<span style='color:{pal[['green']]}'>**Forward deployed engineer**</span> passed both and is still ",
      "at its high, while <span style='color:{pal[['blue']]}'>**AI engineer**</span> just kept climbing. ",
      "Peak markers sit on the 3-month rolling average, so they lag the raw monthly high. Log scale."),
    x = NULL, y = "Searches per month (3-month rolling average)", caption = CAPTION) +
  theme_post()
save_chart(p12, "12_prompt_to_context.png", 11, 7.5)

# =============================================================================
# 13. NEW - the FDE step change on its own
# =============================================================================
# rolling$month is POSIXct; comparing it against as.Date() silently fails
# ("Incompatible methods Ops.POSIXt / Ops.Date") and returns every row, which
# put the takeoff marker on the first month of the window. Coerce once here.
fde_ts <- rolling |> filter(keyword == FDE) |> mutate(month = as.Date(month))
takeoff <- fde_ts |> filter(month == as.Date("2025-01-01"))
latest  <- fde_ts |> slice_max(month, n = 1)
stopifnot(nrow(takeoff) == 1, nrow(latest) == 1,
          format(takeoff$month, "%Y-%m") == "2025-01")

p13 <- ggplot(fde_ts, aes(month, searches)) +
  annotate("rect", xmin = as.Date("2022-08-01"), xmax = as.Date("2024-12-31"),
           ymin = -Inf, ymax = Inf, fill = "grey70", alpha = 0.16) +
  annotate("text", x = as.Date("2023-11-01"), y = 30000,
           label = "Palantir-era baseline:\nflat at ~400/month for 29 months",
           size = 3.4, colour = "grey35", lineheight = 1.05) +
  geom_line(colour = pal[["green"]], linewidth = 1.5) +
  geom_point(data = bind_rows(takeoff, latest), size = 3, colour = pal[["green"]]) +
  geom_text_repel(data = takeoff,
                  aes(label = glue("{format(month, '%b %Y')}\n{label_comma()(searches)}/mo")),
                  nudge_y = 6000, nudge_x = -200, size = 3.3, lineheight = 1,
                  colour = text_axes, segment.colour = "grey55", seed = 11) +
  geom_text_repel(data = latest,
                  aes(label = glue("{format(month, '%b %Y')}\n{label_comma()(searches)}/mo")),
                  nudge_y = -7000, nudge_x = -260, size = 3.3, lineheight = 1,
                  colour = text_axes, segment.colour = "grey55", seed = 12) +
  scale_y_continuous(labels = label_comma()) +
  labs(
    # Chart 2 now carries the "most-searched title" headline, so this one names
    # what only it shows: the shape of the break, not the ranking.
    title = "A title nobody searched for went 30x in eighteen months",
    subtitle = glue(
      "Monthly US searches for **forward deployed engineer**. A Palantir in-joke for years, ",
      "flat at a few hundred a month. ",
      "From <span style='color:{pal[['green']]}'>**January 2025**</span> it compounds roughly ",
      "**30x in eighteen months** - a step change, not a trend. Linear scale, because for once ",
      "the shape survives one."),
    x = NULL, y = "Searches per month", caption = CAPTION) +
  theme_post()
save_chart(p13, "13_fde_stepchange.png", 12, 7)

# =============================================================================
# 14. NEW - recent level vs the 12-month average that hides it
# =============================================================================
last3_lab <- {m <- sort(unique(as.Date(rolling$month))); m <- tail(m, 3)
  paste0(format(m[1], "%b"), "-", format(m[3], "%b %Y"))}

lead_order <- career |> slice_max(last3, n = 12) |> arrange(last3) |> pull(keyword)

lead_d <- career |> filter(keyword %in% lead_order) |>
  select(keyword, `Last 3 months` = last3, `12-month average` = avg_monthly_searches) |>
  pivot_longer(-keyword, names_to = "measure", values_to = "searches") |>
  mutate(keyword = factor(keyword, levels = lead_order),
         measure = factor(measure, c("12-month average", "Last 3 months")))

p14 <- ggplot(lead_d, aes(searches, keyword, fill = measure)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7) +
  scale_fill_manual(values = c(`12-month average` = "grey65",
                               `Last 3 months` = pal[["green"]])) +
  scale_x_continuous(labels = label_comma(), expand = expansion(mult = c(0, 0.12))) +
  labs(
    title = "Rank AI career titles by what they are doing now",
    subtitle = glue(
      "<span style='color:{pal[['green']]}'>**Last three months ({last3_lab})**</span> against the ",
      "<span style='color:grey45'>**trailing 12-month average**</span> Keyword Planner reports. ",
      "A title that stepped up mid-window looks half its real size in the average - which is ",
      "exactly what happened to forward deployed engineer."),
    x = "Searches per month", y = NULL, caption = CAPTION) +
  theme_post() +
  theme(legend.position = "none")
save_chart(p14, "14_recent_vs_average.png", 11, 7.5)

# =============================================================================
# 15. NEW - how far each big career title is off its own peak
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
                               `past its moment` = pal[["red"]])) +
  scale_x_continuous(labels = label_percent(),
                     expand = expansion(mult = c(0.12, 0.10))) +
  labs(
    title = "Most AI job titles are already past their peak",
    subtitle = glue(
      "Last three months against each title's own best month in the four-year window. ",
      "<span style='color:{pal[['green']]}'>**Green**</span> is still at its high; ",
      "<span style='color:{pal[['red']]}'>**red**</span> has lost more than half its search demand. ",
      "Career-intent terms averaging 800+/month recently."),
    x = "Current level vs own peak", y = NULL, caption = CAPTION) +
  theme_post()
save_chart(p15, "15_off_peak.png", 11, 8)

message("\nAll charts written to ", OUT_DIR, "/")
