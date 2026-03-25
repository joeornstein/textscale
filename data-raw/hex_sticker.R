# textscale hex sticker
# Regenerate by running this script from the package root.
# Output: textscale_hex.png (320 dpi)

library(ggplot2)
library(hexSticker)
library(showtext)

font_add_google("Fira Sans", "fira")
showtext_auto()

# ── Colors ────────────────────────────────────────────────────────────────────
bg_col    <- "#0D2137"   # deep navy background
text_col  <- "#89CFF0"   # bright blue for lorem ipsum
white_col <- "#E8F4FD"   # near-white for package name, ruler, stick figure

# ── Lorem ipsum text ──────────────────────────────────────────────────────────
line1 <- "Lorem ipsum dolor sit amet, consectetur adipiscing"
line2 <- "elit, sed do eiusmod tempor incididunt ut labore"

# ── Layout parameters ─────────────────────────────────────────────────────────
tx    <- 0.42   # horizontal center of text block
txt_y1 <- 0.52  # y position of line 1
txt_y2 <- 0.46  # y position of line 2  (gap = 0.06)
r_lo  <- 0.13   # ruler left cap x
r_hi  <- 0.71   # ruler right cap x
r_y   <- 0.37   # ruler y (close below line 2)
xf    <- 0.85   # stick figure center x
fig_y <- (txt_y1 + txt_y2) / 2   # figure vertically centered on text block

# ── Inner illustration ────────────────────────────────────────────────────────
p <- ggplot() +
  # Two-line lorem ipsum
  annotate("text", x = tx, y = txt_y1, label = line1,
           size = 2.9, color = text_col, family = "fira", hjust = 0.5) +
  annotate("text", x = tx, y = txt_y2, label = line2,
           size = 2.9, color = text_col, family = "fira", hjust = 0.5) +

  # Ruler shaft
  annotate("segment", x = r_lo, xend = r_hi, y = r_y, yend = r_y,
           color = white_col, linewidth = 0.55) +
  # End caps
  annotate("segment", x = r_lo, xend = r_lo, y = r_y - .03, yend = r_y + .03,
           color = white_col, linewidth = 0.55) +
  annotate("segment", x = r_hi, xend = r_hi, y = r_y - .03, yend = r_y + .03,
           color = white_col, linewidth = 0.55) +
  # Major ticks at 1/4 intervals
  annotate("segment",
           x    = r_lo + (r_hi - r_lo) * c(.25, .50, .75),
           xend = r_lo + (r_hi - r_lo) * c(.25, .50, .75),
           y = r_y - .02, yend = r_y + .03, color = white_col, linewidth = 0.4) +
  # Minor ticks at 1/8 intervals
  annotate("segment",
           x    = r_lo + (r_hi - r_lo) * c(.125, .375, .625, .875),
           xend = r_lo + (r_hi - r_lo) * c(.125, .375, .625, .875),
           y = r_y - .01, yend = r_y + .025, color = white_col, linewidth = 0.3) +

  # Stick figure
  annotate("point",   x = xf, y = fig_y,       size = 2.0, color = white_col) +
  annotate("segment", x = xf, xend = xf,        y = fig_y - .02, yend = fig_y - .13,
           color = white_col, linewidth = 0.6) +
  # Left arm reaching to ruler right cap
  annotate("segment", x = xf, xend = r_hi + .01, y = fig_y - .055, yend = r_y + .01,
           color = white_col, linewidth = 0.5) +
  # Right arm raised
  annotate("segment", x = xf, xend = xf + .06,  y = fig_y - .055, yend = fig_y - .005,
           color = white_col, linewidth = 0.5) +
  # Legs
  annotate("segment", x = xf, xend = xf - .04,  y = fig_y - .13, yend = fig_y - .24,
           color = white_col, linewidth = 0.5) +
  annotate("segment", x = xf, xend = xf + .04,  y = fig_y - .13, yend = fig_y - .24,
           color = white_col, linewidth = 0.5) +

  xlim(0.0, 1.0) + ylim(0.08, 0.96) +
  theme_void() +
  theme(plot.background  = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA))

# ── Hex sticker ───────────────────────────────────────────────────────────────
sticker(
  p,
  package  = "textscale",
  p_size   = 20,
  p_color  = white_col,
  p_family = "fira",
  p_y      = 1.55,       # package name at top

  s_x      = 0.95,
  s_y      = 1.05,
  s_width  = 1.55,
  s_height = 1.30,

  h_fill   = bg_col,
  h_color  = "#2166AC",  # blue hex border
  h_size   = 1.5,

  filename = "textscale_hex.png",
  dpi      = 320
)

message("Saved: textscale_hex.png")
