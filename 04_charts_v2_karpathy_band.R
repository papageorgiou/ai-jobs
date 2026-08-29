# Karpathy in a stated right-hand band, with a two-part title.
#
# Fifth Karpathy script, writing to output_v2/charts_karpathy_band/. The other
# four folders are untouched. It starts from 04_charts_v2_karpathy_log100k.R -
# same full-decade log axis to 100,000, same plain grid - and changes two things.
#
# The band. Every layout so far has used the 650-day pad past Jul 2026 to park
# the end labels, and the gutter layouts put the Karpathy note there too, but
# the pad was still drawn as chart: decade gridlines ran across it, so it read
# as plotting area that happened to be empty. Filling it in the figure colour
# and ruling its left edge states it instead. The panel now ends where the data
# ends and everything right of the rule is labelling. That collapses the four
# layouts to two - inline versus gutter was the choice the band settles - so
# this folder holds the four-line and spaghetti versions only.
#
# The title. It now names both terms the chart is actually about, because they
# are the answer to two different questions and the old title only answered one:
#
#   forward deployed engineer  #1 by net change (+17,581/mo) and by momentum
#   context engineer           #1 by pct_change (+7,656%), ahead of ai sre
#                              (+6,967%) and FDE itself (+5,656%)
#
# Both are computed in 02_stats.py over career-intent terms; see CLAUDE.md,
# "Growth is measured three ways". The two names carry their series' colours, so
# a reader can find each line without reading the labels first.

library(arrow)
library(dplyr)
library(ggplot2)
library(ggtext)
library(ggrepel)
library(scales)
library(stringr)

IN_DIR  <- "output_v2"
OUT_DIR <- file.path(IN_DIR, "charts_karpathy_band")
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
      plot.title        = element_markdown(size = rel(1.45), face = "bold", hjust = 0,
                                           margin = margin(b = 16), lineheight = 1.25),
      plot.caption      = element_text(size = rel(0.75), colour = "grey45", hjust = 0),
      legend.position   = "none",
      plot.margin       = margin(16, 18, 12, 16)
    )
}

W <- 12; H <- 8
save_chart <- function(plot, name) {
  # wrap_md runs strwrap, which happily splits a <span> mid-tag. A title that
  # is already hand-wrapped and carries colour markup is left alone.
  if (!is.null(plot$labels$title) && !grepl("<br>|<span", plot$labels$title))
    plot$labels$title <- wrap_md(plot$labels$title, floor(W * 6.5))
  ggsave(file.path(OUT_DIR, name), plot, width = W, height = H, dpi = 150)
  message("wrote ", name)
}

# --- Data ---------------------------------------------------------------------
clusters <- read_parquet(file.path(IN_DIR, "clusters.parquet"))
rolling  <- read_parquet(file.path(IN_DIR, "rolling.parquet")) |>
  left_join(clusters |> select(keyword, intent), by = "keyword")

win     <- range(as.Date(rolling$month))
# One line, not two. At 9.75pt across 12 inches the whole credit fits on a
# single row with room to spare, and a two-line caption under a chart this tall
# reads as a second block of content rather than a footer.
CAPTION <- paste0(
  "Source: Google Data, US, ", format(win[1], "%b %Y"), " - ", format(win[2], "%b %Y"), ".",
  "   Analysis & code: github.com/papageorgiou/ai-jobs   |   @alex_papageo")

FDE        <- "forward deployed engineer"
highlights <- c(FDE, "prompt engineer", "context engineer", "ai engineer")

# Context engineer was pal orange (#C05A1A). Next to the subject's red at 2.3
# linewidth that reads as a second red, and the two lines cross in Aug 2025 at
# exactly the moment the chart is about. Dark ochre keeps it warm - the Karpathy
# annotation is still visibly the same series - without competing for "this is
# the line that matters".
CTX_COL <- pal[["yellow"]]
FDE_COL <- pal[["red"]]
hl_cols <- c("prompt engineer"  = pal[["purple"]],
             "context engineer" = CTX_COL,
             "ai engineer"      = pal[["blue"]])
hl_cols[[FDE]] <- FDE_COL
stopifnot(setequal(names(hl_cols), highlights))

LAB_SIZE <- 5.3
PAD_DAYS <- 650

spag <- rolling |>
  filter(intent == "career") |>
  mutate(highlight = keyword %in% highlights,
         is_fde    = keyword == FDE)
stopifnot(all(highlights %in% spag$keyword))

labels   <- spag |> filter(highlight) |> group_by(keyword) |>
  slice_max(month, n = 1) |> ungroup()
fde_line <- filter(spag, is_fde)
spag5    <- filter(spag, highlight)
x_rng    <- range(as.Date(spag$month))

KARPATHY_IMG   <- "karpathy/karpathy_circle.png"
KARPATHY_MONTH <- as.Date("2025-06-01")
ce_anchor <- spag |> filter(keyword == "context engineer",
                            as.Date(month) == KARPATHY_MONTH)
CE_Y <- ce_anchor$roll_avg

# --- Layer builders -----------------------------------------------------------
# The four charts differ only in which of these go in and where, so each is a
# function of position rather than four copies of the same twenty lines.

IMG_SIZE <- 0.135   # was 0.10; the face is the thing people stop scrolling for

karpathy_anno <- function(x_img, y_img, y_txt, x_start, y_start, curvature,
                          x_end = KARPATHY_MONTH + 24, y_end = CE_Y) {
  list(
    geom_point(data = ce_anchor, aes(month, roll_avg),
               colour = CTX_COL, size = 3.4),
    # Head lands on the dot's centre height with a gap in front of it: y_end is
    # CE_Y exactly, x_end far enough right to clear the dot's edge by about two
    # millimetres. Two earlier versions were wrong in opposite directions - CE_Y
    # * 0.90 aimed the head at the empty space below the anchor, then +12 days
    # put the tip hard against the dot with nothing between them.
    # Drawn before the end labels so that if the curve ever runs long it passes
    # under them, not over.
    geom_curve(aes(x = x_start, y = y_start, xend = x_end, yend = y_end),
               curvature = curvature, angle = 100, ncp = 16,
               arrow = arrow(length = unit(0.020, "npc"), type = "closed"),
               colour = CTX_COL, linewidth = 0.6),
    ggimage::geom_image(data = data.frame(x = x_img, y = y_img),
                        aes(x, y), image = KARPATHY_IMG,
                        size = IMG_SIZE, asp = W / H),
    ggtext::geom_richtext(
      data = data.frame(x = x_img, y = y_txt),
      aes(x, y, label = paste0(
        "**Karpathy tweets<br>\"context engineering\"**<br>",
        "<span style='font-size:8pt'>25 Jun 2025</span>")),
      # A near-opaque plate in the panel colour rather than fill = NA: on the
      # spaghetti variants the caption otherwise sits on 255 grey lines. It is
      # invisible on the variants with nothing behind it.
      size = 3.5, lineheight = 1.25, colour = CTX_COL,
      fill = alpha(bg_plot, 0.9), label.colour = NA,
      label.padding = unit(4, "pt"), label.r = unit(3, "pt"))
  )
}

fde_layers <- list(
  geom_line(data = fde_line, aes(month, roll_avg),
            colour = bg_plot, linewidth = 4.4, lineend = "round"),
  geom_line(data = fde_line, aes(month, roll_avg),
            colour = FDE_COL, linewidth = 2.3, lineend = "round"),
  geom_point(data = filter(labels, is_fde), aes(month, roll_avg),
             colour = FDE_COL, size = 3.6)
)

# The volume that used to sit under the FDE name is dropped: the chart's claim
# is the crossing, not the level, and the number was the only thing forcing the
# label to two lines.
end_labels <- list(
  ggtext::geom_richtext(
    data = filter(labels, is_fde),
    aes(month, roll_avg, label = paste0("**", keyword, "**")),
    hjust = 0, nudge_x = 40, size = LAB_SIZE,
    colour = FDE_COL, fill = NA, label.colour = NA,
    label.padding = unit(1.5, "pt")),
  geom_text_repel(
    data = filter(labels, !is_fde),
    aes(month, roll_avg, label = keyword, colour = keyword),
    hjust = 0, direction = "y", nudge_x = 40, size = LAB_SIZE,
    min.segment.length = 0.2, segment.colour = "grey60", seed = 1)
)

# --- The right-hand band ------------------------------------------------------
BAND_X0 <- x_rng[2]           # Jul 2026, where the data stops
GUT_X   <- x_rng[2] + 300     # roughly the band's centre line

# Drawn first, so the FDE line's round cap and its end dot - both of which
# overhang the last month by a couple of millimetres - sit on top of the band
# rather than being clipped by it.
band <- list(
  annotate("rect", xmin = BAND_X0, xmax = Inf, ymin = -Inf, ymax = Inf,
           fill = bg_figure, colour = NA),
  annotate("segment", x = BAND_X0, xend = BAND_X0, y = -Inf, yend = Inf,
           colour = gridlines, linewidth = 0.4)
)

# Hand-wrapped rather than left to wrap_md, because the term names carry colour
# and strwrap would break the tags.
TITLE <- paste0(
  "<span style='color:", FDE_COL, "'>\"Forward deployed engineer\"</span>",
  " is now America's most-searched AI career title<br>",
  "and <span style='color:", CTX_COL, "'>\"context engineer\"</span>",
  " the one with the steepest rise")

# Every power of ten in range, and nothing between them.
Y_TOP   <- 1e5
DECADES <- 10^(1:5)

base_chart <- function(spaghetti, y_floor, pad = PAD_DAYS) {
  layers <- band   # band first: see its definition above
  if (spaghetti)
    layers <- c(layers, list(
      geom_line(data = filter(spag, !highlight),
                aes(month, roll_avg, group = keyword),
                colour = "grey78", linewidth = 0.28, alpha = 0.45)))
  layers <- c(layers, list(
    geom_line(data = filter(spag5, !is_fde),
              aes(month, roll_avg, colour = keyword),
              linewidth = if (spaghetti) 1.1 else 1.2)))

  ggplot() + layers + fde_layers +
    scale_colour_manual(values = hl_cols) +
    scale_y_log10(labels = label_comma(), limits = c(y_floor, Y_TOP),
                  breaks = DECADES) +
    scale_x_date(breaks = unique(c(seq(x_rng[1], x_rng[2], by = "6 months"), x_rng[2])),
                 date_labels = "%b %Y",
                 limits = c(x_rng[1], x_rng[2] + pad),
                 expand = expansion(mult = c(0.02, 0))) +
    labs(title = TITLE, x = NULL, y = "Searches per month", caption = CAPTION) +
    theme_post()
}

# --- 1. Four lines ------------------------------------------------------------
# Coordinates carried over from the gutter layouts, which already placed the
# photo and its caption in this space; the band only states what was there.
p1 <- base_chart(FALSE, 40) +
  karpathy_anno(x_img = GUT_X, y_img = 330, y_txt = 82,
                x_start = GUT_X - 130, y_start = 620, curvature = 0.16) +
  end_labels
save_chart(p1, "01_four_lines_band.png")

# --- 2. Full spaghetti --------------------------------------------------------
p2 <- base_chart(TRUE, 10) +
  karpathy_anno(x_img = GUT_X, y_img = 200, y_txt = 34,
                x_start = GUT_X - 130, y_start = 500, curvature = 0.16) +
  end_labels
save_chart(p2, "02_spaghetti_band.png")

message("\nAll charts written to ", OUT_DIR, "/")
