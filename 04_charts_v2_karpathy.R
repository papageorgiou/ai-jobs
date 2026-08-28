# Karpathy-annotation variants of the career spaghetti, v2.
#
# A fourth chart script rather than more branches inside 04_charts_v2.R, which
# is what produces output_v2/charts/ and stays exactly as it is - the images it
# writes are already in use. Everything here lands in output_v2/charts_karpathy/
# and differs from those in four ways:
#
#   - no "38,033/mo" second line on the forward deployed engineer label
#   - context engineer moves from orange to a dark ochre, because at a glance
#     the orange read as a second red and competed with the subject line
#   - the Karpathy photo is larger, and the arrow lands on the dot rather than
#     near it
#   - four layouts instead of one, crossing two choices: spaghetti behind the
#     four lines or not, and the annotation inside the panel or out in the
#     right-hand gutter past Jul 2026
#
# The style block and the data prep are copied from 04_charts_v2.R rather than
# sourced - sourcing it would re-render all fifteen of its charts.

library(arrow)
library(dplyr)
library(ggplot2)
library(ggtext)
library(ggrepel)
library(scales)
library(stringr)

IN_DIR  <- "output_v2"
OUT_DIR <- file.path(IN_DIR, "charts_karpathy")
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
  if (!is.null(plot$labels$title))
    plot$labels$title <- wrap_md(plot$labels$title, floor(W * 6.5))
  ggsave(file.path(OUT_DIR, name), plot, width = W, height = H, dpi = 150)
  message("wrote ", name)
}

# --- Data ---------------------------------------------------------------------
clusters <- read_parquet(file.path(IN_DIR, "clusters.parquet"))
rolling  <- read_parquet(file.path(IN_DIR, "rolling.parquet")) |>
  left_join(clusters |> select(keyword, intent), by = "keyword")

win     <- range(as.Date(rolling$month))
CAPTION <- paste0(
  "Source: Google Data, US, ", format(win[1], "%b %Y"), " - ", format(win[2], "%b %Y"), ".",
  "\nAnalysis & code: github.com/papageorgiou/ai-jobs   |   @alex_papageo")

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
                          x_end = KARPATHY_MONTH + 10, y_end = CE_Y * 0.90) {
  list(
    geom_point(data = ce_anchor, aes(month, roll_avg),
               colour = CTX_COL, size = 3.4),
    # Head lands just short of the dot on the line joining the two, so the
    # arrow reads as touching it. Drawn before the end labels so that if the
    # curve ever runs long it passes under them, not over.
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

TITLE <- "\"Forward deployed engineer\" is now America's most-searched AI career title"

base_chart <- function(spaghetti, y_floor, y_breaks, pad = PAD_DAYS) {
  layers <- list()
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
    scale_y_log10(labels = label_comma(), limits = c(y_floor, NA), breaks = y_breaks) +
    scale_x_date(breaks = unique(c(seq(x_rng[1], x_rng[2], by = "6 months"), x_rng[2])),
                 date_labels = "%b %Y",
                 limits = c(x_rng[1], x_rng[2] + pad),
                 expand = expansion(mult = c(0.02, 0))) +
    labs(title = TITLE, x = NULL, y = "Searches per month", caption = CAPTION) +
    theme_post()
}

# --- 1. Four lines, annotation inside the panel -------------------------------
p1 <- base_chart(FALSE, 40, c(50, 100, 1000, 10000, 50000)) +
  karpathy_anno(x_img = as.Date("2026-01-20"), y_img = 205, y_txt = 60,
                x_start = as.Date("2025-09-25"), y_start = 300, curvature = 0.32) +
  end_labels
save_chart(p1, "01_four_lines_inline.png")

# --- 2. Full spaghetti, annotation inside the panel ---------------------------
p2 <- base_chart(TRUE, 10, c(10, 100, 1000, 10000, 50000)) +
  karpathy_anno(x_img = as.Date("2026-01-20"), y_img = 155, y_txt = 26,
                x_start = as.Date("2025-09-25"), y_start = 250, curvature = 0.32) +
  end_labels
save_chart(p2, "02_spaghetti_inline.png")

# --- 3 & 4. Annotation out in the gutter, past Jul 2026 -----------------------
# The right-hand pad already exists to hold the end labels and is empty below
# them, so the annotation costs no panel width. The arrow gets long, which is
# the trade: it has to cross a year of chart to reach Jun 2025.
GUT_X <- x_rng[2] + 300

p3 <- base_chart(FALSE, 40, c(50, 100, 1000, 10000, 50000)) +
  karpathy_anno(x_img = GUT_X, y_img = 330, y_txt = 82,
                x_start = GUT_X - 130, y_start = 620, curvature = 0.16) +
  end_labels
save_chart(p3, "03_four_lines_gutter.png")

p4 <- base_chart(TRUE, 10, c(10, 100, 1000, 10000, 50000)) +
  karpathy_anno(x_img = GUT_X, y_img = 200, y_txt = 34,
                x_start = GUT_X - 130, y_start = 500, curvature = 0.16) +
  end_labels
save_chart(p4, "04_spaghetti_gutter.png")

message("\nAll charts written to ", OUT_DIR, "/")
