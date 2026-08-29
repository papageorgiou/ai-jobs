# Slide deck for the ~60-second talking-head video.
#
# Different job from 04_charts_v2*.R. Those build one dense chart that has to
# answer every question on its own, because a reader meets it alone in a feed.
# These are shown for three to six seconds each while I talk over them, so each
# one carries a single claim and nothing else. That inverts two of the usual
# rules: the caption does not have to be readable, and a chart that would be
# under-annotated as a standalone is correct here, because the annotation is
# the narration.
#
# The four titles get individual LINEAR panels rather than sharing the log
# chart. On the shared log axis (slide 06, which is the one place the four are
# compared) context engineer's spike-and-give-back is squashed into a wiggle -
# log is the right choice when the point is that 300/mo and 38,000/mo belong on
# the same axis, and the wrong one when the point is the shape of a single
# series. Each panel therefore gets its own linear scale and its own peak.
#
# Style is Warm Ledger, matching output_v2/charts_* so the deck and the
# published article read as the same body of work.

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(ggplot2); library(ggtext)
  library(scales); library(ggimage); library(patchwork)
})

IN_DIR <- "output_v2"
OUT    <- file.path(IN_DIR, "slides_video")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

# --- Style --------------------------------------------------------------------
bg_plot   <- "#F6EFE8"
bg_figure <- "#FAF8F5"
gridlines <- "#E2D6CB"
text_axes <- "#2B2F33"
muted     <- "#B9AFA6"

pal <- c(blue = "#2B5FB8", red = "#B83A2F", yellow = "#8F6A00", green = "#13734A",
         purple = "#6B4FA3", teal = "#1F7A7A", orange = "#C05A1A",
         rose = "#B44A7A", slate = "#4E5A63")

FDE_COL <- pal[["red"]]; AIE_COL <- pal[["blue"]]
PE_COL  <- pal[["purple"]]; CE_COL <- pal[["yellow"]]

FONT <- "Helvetica Neue"
W <- 12.8; H <- 7.2; DPI <- 150          # 1920 x 1080

save_slide <- function(p, n, name) {
  f <- file.path(OUT, sprintf("%02d_%s.png", n, name))
  ggsave(f, p, width = W, height = H, dpi = DPI, bg = bg_figure)
  message("wrote ", basename(f))
}

# --- Type slides --------------------------------------------------------------
# ggplot as a typesetter: a unit square with no scales, and richtext placed on
# it. size is in mm, so a point size is size * 2.845 and a pixel at 150dpi is
# that * 2.083 - i.e. px = size * 5.93. The named sizes below are that sum done
# once, so the numbers in the slides read as pixel heights.
sz <- function(px) px / 5.93

blank <- function() {
  ggplot() +
    coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), expand = FALSE) +
    theme_void(base_family = FONT) +
    theme(plot.background = element_rect(fill = bg_figure, colour = NA),
          plot.margin = margin(0, 0, 0, 0))
}

txt <- function(p, label, x, y, px, colour = text_axes, hjust = 0, lineheight = 1.18) {
  p + annotate("richtext", x = x, y = y, label = label, size = sz(px), colour = colour,
               hjust = hjust, vjust = 0.5, family = FONT, lineheight = lineheight,
               fill = NA, label.colour = NA, label.padding = unit(0, "pt"))
}

rule <- function(p, x0, x1, y, colour = gridlines, lw = 1.1) {
  p + annotate("segment", x = x0, xend = x1, y = y, yend = y, colour = colour, linewidth = lw)
}

L <- 0.075          # left margin, all type slides

# --- Data ---------------------------------------------------------------------
rolling <- read_parquet(file.path(IN_DIR, "rolling.parquet")) |> mutate(month = as.Date(month))
x_rng   <- range(rolling$month)
CAP <- paste0("Google data, US, ", format(x_rng[1], "%b %Y"), " - ", format(x_rng[2], "%b %Y"),
              "   |   github.com/papageorgiou/ai-jobs   |   @alex_papageo")

FDE  <- "forward deployed engineer"
four <- c(FDE, "ai engineer", "prompt engineer", "context engineer")
cols <- setNames(c(FDE_COL, AIE_COL, PE_COL, CE_COL), four)
d4   <- filter(rolling, keyword %in% four)
stopifnot(all(four %in% d4$keyword))

val <- function(k, m) rolling$roll_avg[rolling$keyword == k & rolling$month == as.Date(m)]

# --- Chart theme --------------------------------------------------------------
theme_chart <- function() {
  theme_minimal(base_size = 13, base_family = FONT) +
    theme(
      plot.background  = element_rect(fill = bg_figure, colour = NA),
      panel.background = element_rect(fill = bg_plot, colour = NA),
      panel.grid.major = element_line(colour = gridlines, linewidth = 0.35),
      panel.grid.minor = element_blank(),
      axis.text        = element_text(size = rel(1.35), colour = "grey38"),
      axis.title       = element_blank(),
      plot.title       = element_markdown(size = rel(2.55), face = "bold", hjust = 0,
                                          margin = margin(b = 8), lineheight = 1.2),
      plot.subtitle    = element_markdown(size = rel(1.65), colour = "grey32", hjust = 0,
                                          margin = margin(b = 20), lineheight = 1.3),
      plot.caption     = element_text(size = rel(0.95), colour = "grey58", hjust = 0,
                                      margin = margin(t = 16)),
      legend.position  = "none",
      plot.margin      = margin(34, 44, 22, 40)
    )
}

x_scale <- function(pad = 0) {
  scale_x_date(breaks = seq(as.Date("2023-01-01"), x_rng[2], by = "12 months"),
               date_labels = "%Y",
               limits = c(x_rng[1], x_rng[2] + pad),
               expand = expansion(mult = c(0.02, 0)))
}

# --- Reusable single-series panel --------------------------------------------
panel_line <- function(k, col, title, subtitle = NULL, caption = CAP,
                       extra = list(), end_label = TRUE, pad = 340, base = NULL) {
  d <- filter(rolling, keyword == k)
  p <- ggplot(d, aes(month, roll_avg)) +
    geom_area(fill = col, alpha = 0.10) +
    geom_line(colour = col, linewidth = 2.1, lineend = "round") +
    x_scale(pad = pad) +
    scale_y_continuous(labels = label_comma(), expand = expansion(mult = c(0, 0.16))) +
    labs(title = title, subtitle = subtitle, caption = caption) +
    (if (is.null(base)) theme_chart() else base)
  if (end_label) {
    lastp <- slice_max(d, month, n = 1)
    p <- p +
      geom_point(data = lastp, colour = col, size = 4.4) +
      geom_richtext(data = lastp,
                    aes(label = paste0("**", comma(round(roll_avg)), "**/mo")),
                    hjust = 0, nudge_x = 34, size = sz(38), colour = col, family = FONT,
                    fill = NA, label.colour = NA, label.padding = unit(0, "pt"))
  }
  p + extra
}

# ============================== TYPE SLIDES ===================================

# 01 - the hook
s01 <- blank() |>
  txt("The most-searched<br>AI job title in America<br>is one almost nobody<br>was tracking.",
      L, 0.55, 92) |>
  rule(L, L + 0.09, 0.145, colour = FDE_COL, lw = 2.2)
save_slide(s01, 1, "hook")

# 02 - the reveal. The term alone, at the size the claim deserves.
s02 <- blank() |>
  txt("THE TITLE", L, 0.80, 30, colour = "grey55") |>
  txt("forward<br>deployed<br>engineer", L, 0.50, 132, colour = FDE_COL, lineheight = 1.06) |>
  rule(L, 0.62, 0.145) |>
  txt("38,033 US searches a month  -  more than any other AI career title",
      L, 0.10, 34, colour = "grey40")
save_slide(s02, 2, "reveal")

# 03 - where it came from
s03 <- blank() |>
  txt("Palantir coined it<br>more than a decade ago.", L, 0.66, 84) |>
  rule(L, L + 0.09, 0.44, colour = FDE_COL, lw = 2.2) |>
  txt("An engineer who works embedded with the customer.<br>It stayed a Palantir word for about ten years.",
      L, 0.28, 44, colour = "grey30", lineheight = 1.45)
save_slide(s03, 3, "palantir")

# 04 - the multiple. Figures are roll_avg, Jan 2025 -> Jul 2026.
mult <- val(FDE, "2026-07-01") / val(FDE, "2025-01-01")
stopifnot(abs(mult - 41.7) < 0.5)
s04 <- blank() |>
  txt("Then it went up", L, 0.83, 52, colour = "grey30") |>
  txt("40&times;", L, 0.52, 300, colour = FDE_COL) |>
  txt("in eighteen months", L, 0.22, 68) |>
  txt(sprintf("%s &rarr; %s searches a month  -  Jan 2025 to Jul 2026",
              comma(round(val(FDE, "2025-01-01"))), comma(round(val(FDE, "2026-07-01")))),
      L, 0.10, 32, colour = "grey45")
save_slide(s04, 4, "forty_x")

# 05 - method
s05 <- blank() |>
  txt("Four years of<br>US Google search volume.", L, 0.68, 84) |>
  rule(L, L + 0.09, 0.45, colour = pal[["slate"]], lw = 2.2) |>
  txt("Every AI job title I could assemble.<br>1,053 titles. 48 months.",
      L, 0.29, 44, colour = "grey30", lineheight = 1.45)
save_slide(s05, 5, "method")

# 06 - why the measure is worth anything
s06 <- blank() |>
  txt("Nobody types a job title<br>into Google to look good.", L, 0.60, 88) |>
  rule(L, L + 0.09, 0.30, colour = pal[["slate"]], lw = 2.2) |>
  txt("It is one of the few honest signals about AI work.", L, 0.18, 44, colour = "grey30")
save_slide(s06, 6, "honest_signal")

# ============================== CHART SLIDES ==================================
library(ggrepel)

# Titles are hand-wrapped rather than left to wrap: at 33pt bold across the
# 12.8in canvas a line holds about 46 characters, and element_markdown reserves
# height for <br> but not for wrapping it does itself - the same trap noted in
# CLAUDE.md under "ggtext heights". Every title below is inside that budget or
# broken explicitly.

# 07 - the one chart where the four are compared. Log, because 300/mo and
# 38,000/mo have to sit on the same axis; the individual shapes come later.
lab4 <- d4 |> group_by(keyword) |> slice_max(month, n = 1) |> ungroup()
s07 <- ggplot(d4, aes(month, roll_avg, colour = keyword)) +
  annotate("rect", xmin = x_rng[2], xmax = Inf, ymin = 50, ymax = Inf,
           fill = bg_figure, colour = NA) +
  annotate("segment", x = x_rng[2], xend = x_rng[2], y = 50, yend = 8e4,
           colour = gridlines, linewidth = 0.4) +
  geom_line(linewidth = 1.9, lineend = "round") +
  geom_point(data = lab4, size = 3.6) +
  geom_text_repel(data = lab4, aes(label = keyword), hjust = 0, direction = "y",
                  nudge_x = 45, size = sz(36), family = FONT, fontface = "bold",
                  min.segment.length = 0.25, segment.colour = "grey65", seed = 1) +
  scale_colour_manual(values = cols) +
  scale_y_log10(labels = label_comma(), breaks = 10^(2:4), limits = c(50, 8e4)) +
  x_scale(pad = 700) +
  labs(title = "Four titles carry the whole chart",
       subtitle = "Every AI career title, US searches per month, 3-month rolling average. Log scale.",
       caption = CAP) +
  theme_chart()
save_slide(s07, 7, "four_lines")

# 08 - forward deployed engineer
s08 <- panel_line(
  FDE, FDE_COL,
  paste0("<span style='color:", FDE_COL, "'>forward deployed engineer</span> went from an<br>in-joke to the top of the list"),
  "From 480 searches a month in 2022 to the most-searched AI career title.")
save_slide(s08, 8, "fde")

# 09 - prompt engineer. The plotted series is the 3-month mean, so its peak sits
# in May; the raw monthly peak is April 2023 (74,000). "Spring 2023" is the one
# phrase true of both, and is what the narration says.
pe    <- filter(rolling, keyword == "prompt engineer")
pe_pk <- slice_max(pe, roll_avg, n = 1)
s09 <- panel_line(
  "prompt engineer", PE_COL,
  paste0("<span style='color:", PE_COL, "'>prompt engineer</span> peaked in spring 2023<br>and has been sliding ever since"),
  "The first title to break out after ChatGPT. Down 74% from its peak.",
  extra = list(
    geom_point(data = pe_pk, colour = PE_COL, size = 4.4),
    geom_richtext(data = pe_pk, aes(label = "**peak**<br>65,000/mo"),
                  vjust = 0, nudge_y = 3400, size = sz(34), colour = PE_COL, family = FONT,
                  fill = NA, label.colour = NA, label.padding = unit(0, "pt"), lineheight = 1.2)))
save_slide(s09, 9, "prompt_engineer")

# 10 - the tweet. An editorial quote card, not a mock of the X interface: the
# quote is verbatim and attributed, and a rebuilt screenshot would be a worse
# claim about the same fact. Source: x.com/karpathy/status/1937902205765607626
s10 <- blank() +
  ggimage::geom_image(data = data.frame(x = 0.145, y = 0.70),
                      aes(x, y), image = "karpathy/karpathy_circle.png",
                      size = 0.20, asp = W / H)
s10 <- s10 |>
  txt(paste0("&ldquo;+1 for <b>&lsquo;context engineering&rsquo;</b><br>",
             "over &lsquo;prompt engineering&rsquo;&rdquo;"), L, 0.36, 78, colour = CE_COL) |>
  rule(L, 0.52, 0.175) |>
  txt("<b>Andrej Karpathy</b>  &middot;  25 June 2025", L, 0.115, 36, colour = "grey35")
save_slide(s10, 10, "karpathy")

# 11 - context engineer
ce    <- filter(rolling, keyword == "context engineer")
ce_pk <- slice_max(ce, roll_avg, n = 1)
KDATE <- as.Date("2025-06-25")
s11 <- panel_line(
  "context engineer", CE_COL,
  paste0("<span style='color:", CE_COL, "'>context engineer</span> spiked in the same<br>weeks - and gave most of it back"),
  "Flat for thirty-four months, then peaked three months after the post.",
  extra = list(
    annotate("segment", x = KDATE, xend = KDATE, y = 0, yend = 8300,
             colour = "grey45", linewidth = 0.7, linetype = "22"),
    annotate("richtext", x = KDATE - 40, y = 8600, label = "**Karpathy**<br>25 Jun 2025",
             hjust = 1, vjust = 0, size = sz(34), colour = "grey30", family = FONT,
             fill = NA, label.colour = NA, label.padding = unit(0, "pt"), lineheight = 1.2),
    geom_point(data = ce_pk, colour = CE_COL, size = 4.4),
    geom_richtext(data = ce_pk, aes(label = "**peak** 9,833/mo"),
                  hjust = 0, vjust = 0, nudge_x = 25, nudge_y = 250, size = sz(34),
                  colour = CE_COL, family = FONT,
                  fill = NA, label.colour = NA, label.padding = unit(0, "pt"))))
save_slide(s11, 11, "context_engineer")

# 12 - ai engineer
s12 <- panel_line(
  "ai engineer", AIE_COL,
  paste0("<span style='color:", AIE_COL, "'>ai engineer</span> just climbs"),
  "No spike, no collapse, nothing to explain. Never more than 24% off its peak.")
save_slide(s12, 12, "ai_engineer")

# 13 - the point of the whole thing. Two panels, each on its own linear scale,
# because the claim is about the shape of each rise and not about their relative
# size: on a shared axis context engineer's spike is a third of FDE's height and
# the eye reads "smaller", which is the wrong comparison.
dur_panel <- function(k, col, lab, note) {
  d <- filter(rolling, keyword == k)
  ggplot(d, aes(month, roll_avg)) +
    geom_area(fill = col, alpha = 0.10) +
    geom_line(colour = col, linewidth = 1.8, lineend = "round") +
    x_scale(pad = 0) +
    scale_y_continuous(labels = label_comma(), expand = expansion(mult = c(0, 0.20))) +
    labs(title = lab, subtitle = note) +
    theme_chart() +
    theme(plot.title    = element_markdown(size = rel(1.85), face = "bold",
                                           margin = margin(b = 4)),
          plot.subtitle = element_markdown(size = rel(1.35), colour = "grey35",
                                           margin = margin(b = 12)),
          axis.text     = element_text(size = rel(1.1), colour = "grey42"),
          plot.margin   = margin(12, 18, 4, 8))
}

s13 <- (dur_panel(FDE, FDE_COL,
                  paste0("<span style='color:", FDE_COL, "'>forward deployed engineer</span>"),
                  "Eighteen months up - and still rising") |
        dur_panel("context engineer", CE_COL,
                  paste0("<span style='color:", CE_COL, "'>context engineer</span>"),
                  "Three months up, ten months down")) +
  plot_annotation(
    title = "The difference is duration, not slope",
    subtitle = "Only one of these was still climbing twelve months in.",
    caption = CAP,
    theme = theme_chart() +
      theme(panel.background = element_rect(fill = bg_figure, colour = NA),
            plot.margin = margin(34, 30, 22, 34))) &
  theme(plot.background = element_rect(fill = bg_figure, colour = NA))
save_slide(s13, 13, "duration")

# 14 - the line to end on
s14 <- blank() |>
  txt("Standing inside the spike,<br>the two look identical.", L, 0.55, 96) |>
  rule(L, L + 0.09, 0.20, colour = FDE_COL, lw = 2.2)
save_slide(s14, 14, "kicker")

message("\n", length(list.files(OUT, "\\.png$")), " slides in ", OUT)
