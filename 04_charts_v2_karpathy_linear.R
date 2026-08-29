# Karpathy-annotation variants of the career spaghetti, v2, on a LINEAR y axis.
#
# A copy of 04_charts_v2_karpathy.R with scale_y_log10 replaced by a plain
# linear scale, writing to output_v2/charts_karpathy_linear/. The log-scale
# script and its output_v2/charts_karpathy/ folder are untouched.
#
# What changes, and it is not only the scale call:
#
#   - the axis is set by "prompt engineer"'s May 2023 spike at 65,000/mo, so
#     four fifths of the panel height is spent on one term's one month and the
#     whole rest of the career universe is squashed into the bottom fifth
#   - "context engineer" sits at 600/mo in Jun 2025, the month the annotation is
#     about. On this axis that is 0.9% of panel height - the anchor dot lands
#     effectively on the x axis, so the callout can no longer sit beside it
#   - the annotation therefore moves up into the empty band above 40,000 and the
#     curved arrow becomes a dashed leader running the height of the panel. A
#     curve that long, in the "context engineer" ochre, reads as a fifth series
#   - the spaghetti variants lose their y floor: on a log scale the floor at 10
#     or 40 hid nothing, here every quiet term is already flat on the baseline
#
# See CLAUDE.md, "Log scales are usually required". This script exists because
# the linear rendering was asked for explicitly; it is the honest version of a
# chart whose subject spans three orders of magnitude.

library(arrow)
library(dplyr)
library(ggplot2)
library(ggtext)
library(ggrepel)
library(scales)
library(stringr)

IN_DIR  <- "output_v2"
OUT_DIR <- file.path(IN_DIR, "charts_karpathy_linear")
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
# One line, not two. At 9.75pt across 12 inches the whole credit fits on a
# single row with room to spare, and a two-line caption under a chart this tall
# reads as a second block of content rather than a footer.
CAPTION <- paste0(
  "Source: Google Data, US, ", format(win[1], "%b %Y"), " - ", format(win[2], "%b %Y"), ".",
  "   Analysis & code: github.com/papageorgiou/ai-jobs   |   @alex_papageo")

FDE        <- "forward deployed engineer"
highlights <- c(FDE, "prompt engineer", "context engineer", "ai engineer")

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

# The linear ceiling. Taken from the data rather than written in, so that a
# re-pull cannot silently push a series off the top of the panel.
Y_MAX <- max(spag$roll_avg)

# --- Layer builders -----------------------------------------------------------
IMG_SIZE <- 0.135

# The leader, not an arrow-curve. On the log axis a short curved arrow reached
# from the caption to the dot inside a couple of thousand pixels of panel. Here
# the caption is at 44,000 and the dot at 600, so any curve joining them sweeps
# most of the panel in the same ochre as "context engineer" and reads as a fifth
# series - the first render of this script did exactly that. A dashed leader,
# vertical at the event date inline and L-shaped from the gutter, reads as
# annotation furniture instead. Same information, no phantom line.
LEADER <- list(colour = CTX_COL, linewidth = 0.5, linetype = "22")

leader_seg <- function(x, y, xend, yend, arrow_head = FALSE) {
  geom_segment(aes(x = x, y = y, xend = xend, yend = yend),
               colour = LEADER$colour, linewidth = LEADER$linewidth,
               linetype = LEADER$linetype,
               arrow = if (arrow_head)
                 arrow(length = unit(0.018, "npc"), type = "closed") else NULL)
}

karpathy_head <- function(x_img, y_img, y_txt) {
  list(
    geom_point(data = ce_anchor, aes(month, roll_avg),
               colour = CTX_COL, size = 3.4),
    ggimage::geom_image(data = data.frame(x = x_img, y = y_img),
                        aes(x, y), image = KARPATHY_IMG,
                        size = IMG_SIZE, asp = W / H),
    ggtext::geom_richtext(
      data = data.frame(x = x_img, y = y_txt),
      aes(x, y, label = paste0(
        "**Karpathy tweets<br>\"context engineering\"**<br>",
        "<span style='font-size:8pt'>25 Jun 2025</span>")),
      size = 3.5, lineheight = 1.25, colour = CTX_COL,
      fill = alpha(bg_plot, 0.9), label.colour = NA,
      label.padding = unit(4, "pt"), label.r = unit(3, "pt"))
  )
}

# Inline: the caption sits directly above the event month, so the leader is a
# plain vertical dropped down that date. It crosses "prompt engineer" and
# "ai engineer", which a dashed rule at a fixed x is allowed to do - that is how
# an event marker looks.
anno_inline <- function(y_img = 56000, y_txt = 44000, y_drop = 39000) {
  c(list(leader_seg(KARPATHY_MONTH, y_drop, KARPATHY_MONTH, CE_Y + 1000,
                    arrow_head = TRUE)),
    karpathy_head(KARPATHY_MONTH, y_img, y_txt))
}

# Gutter: down the empty gutter first, then left along the baseline to the dot.
# The corner is what keeps it legible - a single diagonal across the panel would
# be the phantom line again.
anno_gutter <- function(x_img, y_img = 57500, y_txt = 45500, y_drop = 43000) {
  c(list(leader_seg(x_img, y_drop, x_img, CE_Y),
         leader_seg(x_img, CE_Y, KARPATHY_MONTH + 25, CE_Y, arrow_head = TRUE)),
    karpathy_head(x_img, y_img, y_txt))
}

fde_layers <- list(
  geom_line(data = fde_line, aes(month, roll_avg),
            colour = bg_plot, linewidth = 4.4, lineend = "round"),
  geom_line(data = fde_line, aes(month, roll_avg),
            colour = FDE_COL, linewidth = 2.3, lineend = "round"),
  geom_point(data = filter(labels, is_fde), aes(month, roll_avg),
             colour = FDE_COL, size = 3.6)
)

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

base_chart <- function(spaghetti, pad = PAD_DAYS) {
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
    scale_y_continuous(labels = label_comma(), limits = c(0, NA),
                       breaks = seq(0, 60000, by = 10000),
                       expand = expansion(mult = c(0, 0.06))) +
    scale_x_date(breaks = unique(c(seq(x_rng[1], x_rng[2], by = "6 months"), x_rng[2])),
                 date_labels = "%b %Y",
                 limits = c(x_rng[1], x_rng[2] + pad),
                 expand = expansion(mult = c(0.02, 0))) +
    labs(title = TITLE, x = NULL, y = "Searches per month", caption = CAPTION) +
    theme_post()
}

# --- 1. Four lines, annotation inside the panel -------------------------------
# Top-right: empty above 40,000 from mid-2023 on, and the only region tall
# enough to hold the photo. The arrow drops the height of the panel.
p1 <- base_chart(FALSE) + anno_inline() + end_labels
save_chart(p1, "01_four_lines_inline.png")

# --- 2. Full spaghetti, annotation inside the panel ---------------------------
# Same coordinates: the spaghetti all sits under 13,000, so it changes nothing
# about where there is room up top.
p2 <- base_chart(TRUE) + anno_inline() + end_labels
save_chart(p2, "02_spaghetti_inline.png")

# --- 3 & 4. Annotation out in the gutter, past Jul 2026 -----------------------
# The gutter's usable band is above the "forward deployed engineer" end label at
# 38,033 - below it the three other end labels take the space the photo needs.
GUT_X <- x_rng[2] + 300

p3 <- base_chart(FALSE) + anno_gutter(GUT_X) + end_labels
save_chart(p3, "03_four_lines_gutter.png")

p4 <- base_chart(TRUE) + anno_gutter(GUT_X) + end_labels
save_chart(p4, "04_spaghetti_gutter.png")

message("\nAll charts written to ", OUT_DIR, "/")
