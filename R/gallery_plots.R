# Presentation-only figures from the public, entirely synthetic workflow.
# Statistical calculations remain in workflow.R; these functions only draw them.

gallery_palette <- function() {
  c(paper = "#F7F5EF", white = "#FFFFFF", ink = "#183B40", teal = "#147D78",
    coral = "#DD795E", muted = "#607477", line = "#D9E2DC", pale = "#E7EEEA")
}

gallery_canvas <- function() {
  graphics::par(fig = c(0, 1, 0, 1), mar = rep(0, 4), new = TRUE,
                family = "sans", xpd = NA)
  graphics::plot.new()
  graphics::plot.window(xlim = c(0, 1000), ylim = c(0, 740), xaxs = "i", yaxs = "i")
}

gallery_text <- function(x, y, label, size = 15, color = gallery_palette()["ink"],
                         font = 1, adj = c(0, 0.5), ...) {
  graphics::text(x, y, label, cex = size / 12, col = color, font = font, adj = adj, ...)
}

gallery_frame <- function(title, subtitle, section) {
  p <- gallery_palette()
  graphics::par(mar = rep(0, 4), family = "sans", bg = p["paper"], xpd = NA)
  graphics::plot.new()
  graphics::plot.window(xlim = c(0, 1000), ylim = c(0, 740), xaxs = "i", yaxs = "i")
  graphics::rect(0, 0, 1000, 740, col = p["paper"], border = NA)
  gallery_text(48, 711, paste("CORAL TRAIT PHYLOGENETICS /", section), 12, p["teal"], 2)
  gallery_text(48, 674, title, 29, font = 2)
  gallery_text(48, 640, subtitle, 15, p["muted"])
  graphics::segments(48, 55, 952, 55, col = p["line"], lwd = 1)
  gallery_text(48, 30, "SYNTHETIC EXAMPLE", 12, p["teal"], 2)
  gallery_text(235, 30, "All data and displayed patterns are simulated; no study findings are shown.",
               12, p["muted"])
}

gallery_plot_area <- function(fig, xlim, ylim) {
  p <- gallery_palette()
  graphics::par(fig = fig, mar = rep(0, 4), new = TRUE, xpd = FALSE,
                col.axis = p["muted"], col.lab = p["ink"], cex.axis = 14 / 12,
                family = "sans", mgp = c(2.8, 0.85, 0), tck = -0.014)
  graphics::plot.new()
  graphics::plot.window(xlim = xlim, ylim = ylim, xaxs = "i", yaxs = "i")
}

plot_gallery_tree <- function(tree, traits) {
  p <- gallery_palette()
  aligned <- align_traits_to_tree(tree, traits)
  colors <- c(state_0 = unname(p["teal"]), state_1 = unname(p["coral"]))
  display_tree <- tree
  # Short, anonymous IDs keep circular labels readable and the SVG compact.
  display_tree$tip.label <- sub("Taxon_", "", tree$tip.label, fixed = TRUE)
  graphics::par(mar = rep(0, 4), family = "sans", bg = p["paper"], xpd = NA)
  graphics::plot.new()
  graphics::plot.window(xlim = c(0, 900), ylim = c(0, 900), xaxs = "i", yaxs = "i")
  graphics::rect(0, 0, 900, 900, col = p["paper"], border = NA)
  gallery_text(48, 868, "CORAL TRAIT PHYLOGENETICS / 01 / PHYLOGENY", 12, p["teal"], 2)
  gallery_text(48, 829, "A tree-informed view of traits", 29, font = 2)
  gallery_text(48, 794, "48 artificial taxa. Simulated relationships. Anonymous tip identifiers.",
               15, p["muted"])
  graphics::par(fig = c(0.045, 0.955, 0.112, 0.846), mar = rep(0, 4), new = TRUE,
                family = "sans", xpd = NA)
  ape::plot.phylo(display_tree, type = "fan", use.edge.length = TRUE, show.tip.label = FALSE,
                  tip.color = p["ink"], edge.color = p["muted"], edge.width = 1.8,
                  cex = 16 / 12, font = 1, label.offset = 0.047, no.margin = TRUE,
                  x.lim = c(-1.16, 1.16), y.lim = c(-1.16, 1.16),
                  open.angle = 5, rotate.tree = 92)
  ape::tiplabels(pch = 21, bg = colors[as.character(aligned$State_A)],
                 col = p["paper"], cex = 1.6, lwd = 1.2)
  # Upright short labels share glyphs and can be read without rotating the page.
  coordinates <- get("last_plot.phylo", envir = ape::.PlotPhyloEnv)
  tips <- seq_along(display_tree$tip.label)
  graphics::text(coordinates$xx[tips] * 1.09, coordinates$yy[tips] * 1.09,
                 display_tree$tip.label, cex = 16 / 12, col = p["ink"])
  graphics::par(fig = c(0, 1, 0, 1), mar = rep(0, 4), new = TRUE, xpd = NA)
  graphics::plot.new()
  graphics::plot.window(xlim = c(0, 900), ylim = c(0, 900), xaxs = "i", yaxs = "i")
  gallery_text(260, 85, "ARTIFICIAL STATE", 12, p["teal"], 2)
  graphics::points(c(425, 548), c(85, 85), pch = 21, bg = colors,
                   col = p["paper"], cex = 1.7)
  gallery_text(443, 85, "State 0", 15)
  gallery_text(566, 85, "State 1", 15)
  graphics::segments(48, 54, 852, 54, col = p["line"])
  gallery_text(48, 29, "SYNTHETIC EXAMPLE", 12, p["teal"], 2)
  gallery_text(235, 29, "Entirely simulated topology, branch lengths, traits and identifiers.",
               12, p["muted"])
}

plot_gallery_imputation <- function(scores) {
  p <- gallery_palette()
  gallery_frame("Testing missing-trait predictions", "Held-out synthetic observations compare two imputation strategies.",
                "02 / IMPUTATION")
  colors <- c(forest_only = unname(p["coral"]), forest_plus_tree_axes = unname(p["teal"]))
  graphics::points(c(625, 783), c(596, 596), pch = c(21, 22), bg = colors,
                   col = p["paper"], cex = 1.4)
  gallery_text(644, 596, "Forest", 14)
  gallery_text(802, 596, "Forest + tree axes", 14)
  gallery_text(48, 575, "Continuous traits", 20, font = 2)
  gallery_text(48, 548, "RMSE / training SD", 14, p["muted"])

  traits <- continuous_columns()
  values <- scores[scores$trait %in% traits, ]
  upper <- max(values$error) * 1.2
  limits <- c(0, max(pretty(c(0, upper), n = 5)))
  gallery_plot_area(c(0.28, 0.92, 0.48, 0.73), limits, c(0.55, 3.45))
  ticks <- pretty(limits, n = 5)
  for (tick in ticks) graphics::abline(v = tick, col = p["line"], lwd = 0.8)
  for (i in seq_along(traits)) {
    y <- 4 - i
    row <- values[values$trait == traits[i], ]
    graphics::segments(min(row$error), y, max(row$error), y, col = p["muted"], lwd = 2)
    for (j in seq_len(nrow(row))) {
      offset <- if (row$method[j] == "forest_only") -0.065 else 0.065
      graphics::points(row$error[j], y + offset, pch = if (j == 1L) 21 else 22,
                       bg = colors[row$method[j]], col = p["paper"], cex = 1.8, lwd = 1.5)
      graphics::text(row$error[j], y + if (j == 1L) -0.32 else 0.34,
                     sprintf("%.2f", row$error[j]), col = colors[row$method[j]], cex = 14 / 12)
    }
  }
  graphics::axis(1, at = ticks, col = NA, col.ticks = NA, line = 0.3)
  graphics::axis(2, at = 3:1, labels = gsub("_", " ", traits), tick = FALSE,
                 las = 1, line = 1.0, col.axis = p["ink"])
  gallery_canvas()
  gallery_text(920, 301, "Lower error is better", 14, p["muted"], adj = c(1, 0.5))
  graphics::segments(48, 279, 952, 279, col = p["line"])
  gallery_text(48, 246, "Binary trait / State A", 20, font = 2)
  gallery_text(48, 219, "Misclassification proportion", 14, p["muted"])
  binary <- scores[scores$trait == "State_A", ]
  gallery_plot_area(c(0.28, 0.92, 0.245, 0.34), c(0, 1), c(0.5, 1.5))
  for (tick in seq(0, 1, 0.2)) graphics::abline(v = tick, col = p["line"], lwd = 0.8)
  graphics::segments(min(binary$error), 1, max(binary$error), 1, col = p["muted"], lwd = 2)
  for (j in seq_len(nrow(binary))) {
    offset <- if (j == 1L) -0.08 else 0.08
    graphics::points(binary$error[j], 1 + offset, pch = if (j == 1L) 21 else 22,
                     bg = colors[binary$method[j]], col = p["paper"], cex = 1.8, lwd = 1.5)
    graphics::text(binary$error[j], 1 + if (j == 1L) -0.35 else 0.35,
                   sprintf("%.2f", binary$error[j]), col = colors[binary$method[j]], cex = 14 / 12)
  }
  graphics::axis(1, at = seq(0, 1, 0.2), col = NA, col.ticks = NA, line = 0.3)
  gallery_canvas()
  gallery_text(48, 100, "One synthetic masking run illustrates evaluation; it does not establish method superiority.",
               14, p["muted"])
}

plot_gallery_pca <- function(pca, traits) {
  p <- gallery_palette()
  variance <- 100 * pca$sdev^2 / sum(pca$sdev^2)
  colors <- c(state_0 = unname(p["teal"]), state_1 = unname(p["coral"]))
  gallery_frame("Exploring multivariate trait space", "Principal components of standardised, imputed synthetic continuous traits.",
                "03 / ORDINATION")
  xlim <- range(pretty(range(pca$x[, 1]) * 1.15, n = 5))
  ylim <- range(pretty(range(pca$x[, 2]) * 1.15, n = 5))
  gallery_plot_area(c(0.115, 0.70, 0.215, 0.795), xlim, ylim)
  xticks <- pretty(xlim, n = 5)
  yticks <- pretty(ylim, n = 5)
  for (tick in xticks) graphics::abline(v = tick, col = p["line"], lwd = 0.7)
  for (tick in yticks) graphics::abline(h = tick, col = p["line"], lwd = 0.7)
  graphics::abline(v = 0, h = 0, col = p["muted"], lty = 3)
  graphics::points(pca$x[, 1], pca$x[, 2], pch = 21,
                   bg = colors[as.character(traits$State_A)], col = p["paper"],
                   lwd = 1.5, cex = 1.55)
  graphics::axis(1, at = xticks, col = NA, col.ticks = NA, line = 0.3)
  graphics::axis(2, at = yticks, col = NA, col.ticks = NA, las = 1, line = 0.3)
  gallery_canvas()
  gallery_text(407, 109, sprintf("PC1 / %.1f%% of variance", variance[1]), 16, adj = c(0.5, 0.5))
  gallery_text(35, 375, sprintf("PC2 / %.1f%% of variance", variance[2]), 16,
               adj = c(0.5, 0.5), srt = 90)
  gallery_text(758, 551, "Each point is one", 18, font = 2)
  gallery_text(758, 526, "artificial taxon.", 18, font = 2)
  gallery_text(758, 477, "ARTIFICIAL STATE", 12, p["teal"], 2)
  graphics::points(c(767, 767), c(445, 414), pch = 21, bg = colors,
                   col = p["paper"], cex = 1.5)
  gallery_text(786, 445, "State 0", 16)
  gallery_text(786, 414, "State 1", 16)
  graphics::segments(758, 379, 950, 379, col = p["line"])
  gallery_text(758, 346, "VARIANCE EXPLAINED", 12, p["teal"], 2)
  for (i in 1:3) {
    y <- 307 - (i - 1) * 47
    gallery_text(758, y + 11, paste0("PC", i), 13, p["muted"])
    gallery_text(950, y + 11, sprintf("%.1f%%", variance[i]), 13, p["ink"], adj = c(1, 0.5))
    graphics::rect(758, y - 7, 950, y - 1, col = p["line"], border = NA)
    graphics::rect(758, y - 7, 758 + 192 * variance[i] / 100, y - 1,
                   col = p["teal"], border = NA)
  }
  gallery_text(758, 139, "Descriptive only; imputation", 13, p["muted"])
  gallery_text(758, 119, "uncertainty is not propagated.", 13, p["muted"])
}

plot_gallery_correlation <- function(correlation) {
  p <- gallery_palette()
  gallery_frame("Reading trait associations", "Spearman rank correlations among imputed synthetic continuous traits.",
                "04 / ASSOCIATION")
  ramp <- grDevices::colorRampPalette(c(p["coral"], p["paper"], p["teal"]))(201)
  size <- 136
  xs <- c(319, 471, 623)
  ys <- c(497, 345, 193)
  labels <- gsub("_", " ", rownames(correlation))
  for (i in seq_len(3)) {
    gallery_text(xs[i], 588, labels[i], 16, adj = c(0.5, 0.5))
    gallery_text(220, ys[i], labels[i], 16, adj = c(1, 0.5))
    for (j in seq_len(3)) {
      value <- correlation[j, i]
      fill <- ramp[round((value + 1) * 100) + 1L]
      graphics::rect(xs[i] - size / 2, ys[j] - size / 2,
                     xs[i] + size / 2, ys[j] + size / 2, col = fill, border = NA)
      gallery_text(xs[i], ys[j], sprintf("%.2f", value), 28,
                   if (abs(value) > 0.7) p["white"] else p["ink"],
                   font = 2, adj = c(0.5, 0.5))
    }
  }
  gallery_text(784, 568, "Spearman r", 16, font = 2)
  ly <- seq(195, 531, length.out = 202)
  for (i in 1:201) graphics::rect(785, ly[i], 805, ly[i + 1], col = ramp[i], border = NA)
  for (value in c(-1, 0, 1)) {
    gallery_text(820, 195 + (value + 1) / 2 * 336,
                 if (value > 0) "+1" else as.character(value), 15, p["muted"])
  }
  gallery_text(873, 521, "Positive", 14, p["teal"], srt = 90, adj = c(1, 0.5))
  gallery_text(873, 205, "Negative", 14, p["coral"], srt = 90, adj = c(0, 0.5))
  gallery_text(251, 91, "Associations describe this example; no significance tests or causal claims are made.",
               14, p["muted"])
}

plot_gallery_overview <- function() {
  p <- gallery_palette()
  gallery_frame("From phylogeny to trait patterns", "A reproducible methods workflow, illustrated entirely with synthetic inputs.",
                "RESEARCH WORKFLOW")
  labels <- c("Align", "Impute", "Evaluate", "Explore")
  subtitles <- c("Tree and trait IDs", "Missing observations", "Held-out predictions", "Multivariate patterns")
  descriptions <- list(c("Validate the schema", "and match every taxon."),
                       c("Compare forests with", "tree-informed predictors."),
                       c("Score artificial gaps", "against known values."),
                       c("Inspect ordination", "and trait associations."))
  for (i in 1:4) {
    x <- 50 + (i - 1) * 236
    graphics::rect(x, 257, x + 218, 526, col = p["white"], border = p["line"])
    graphics::symbols(x + 41, 482, circles = 21, inches = FALSE, add = TRUE,
                      bg = p["teal"], fg = NA)
    gallery_text(x + 41, 482, sprintf("%02d", i), 17, p["white"], 2, adj = c(0.5, 0.5))
    gallery_text(x + 21, 420, labels[i], 26, font = 2)
    gallery_text(x + 21, 379, subtitles[i], 14, p["teal"], 2)
    gallery_text(x + 21, 333, descriptions[[i]][1], 14, p["muted"])
    gallery_text(x + 21, 312, descriptions[[i]][2], 14, p["muted"])
    if (i < 4) graphics::arrows(x + 224, 442, x + 230, 442, length = 0.05,
                                col = p["teal"], lwd = 1.5)
  }
  gallery_text(50, 184, "METHODS, WITH RESEARCH FINDINGS WITHHELD", 13, p["teal"], 2)
  gallery_text(50, 148, "The same pipeline generates every example figure from a fixed synthetic seed.",
               17, p["ink"])
  gallery_text(50, 119, "Observed values, tree topology, identifiers and outputs are all artificial.",
               15, p["muted"])
}

compact_gallery_svg <- function(path) {
  # ape draws fan arcs as many short segments. Preserve every coordinate while
  # sharing identical consecutive stroke attributes in one SVG multi-subpath.
  # Only opaque, unfilled paths qualify; glyphs and all other markup are intact.
  lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
  eligible <- grepl('^<path fill="none"[^>]+ stroke-opacity="1"[^>]+ d="[^\"]*"/>$', lines)
  result <- character(length(lines))
  input <- 1L
  output <- 0L
  while (input <= length(lines)) {
    output <- output + 1L
    if (!eligible[input]) {
      result[output] <- lines[input]
      input <- input + 1L
      next
    }
    prefix <- sub(' d=".*$', '', lines[input])
    end <- input
    while (end < length(lines) && eligible[end + 1L] &&
           identical(sub(' d=".*$', '', lines[end + 1L]), prefix)) end <- end + 1L
    paths <- sub('^.* d="', '', lines[input:end])
    paths <- sub('"/>$', '', paths)
    result[output] <- paste0(prefix, ' d="', paste(paths, collapse = " "), '"/>')
    input <- end + 1L
  }
  connection <- file(path, open = "wb")
  on.exit(close(connection))
  writeLines(result[seq_len(output)], connection, useBytes = TRUE)
  invisible(path)
}

write_gallery_figures <- function(tree, traits, scores, summaries, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  figures <- list(
    synthetic_tree.svg = function() plot_gallery_tree(tree, traits),
    synthetic_imputation.svg = function() plot_gallery_imputation(scores),
    synthetic_pca.svg = function() plot_gallery_pca(summaries$pca, traits),
    synthetic_correlation.svg = function() plot_gallery_correlation(summaries$correlation),
    synthetic_workflow.svg = plot_gallery_overview
  )
  for (name in names(figures)) {
    dimensions <- if (name == "synthetic_tree.svg") c(900, 900) else c(1000, 740)
    grDevices::svg(file.path(output_dir, name), width = dimensions[1] / 72, height = dimensions[2] / 72,
                    pointsize = 12, family = "sans", bg = gallery_palette()["paper"])
    tryCatch(figures[[name]](), finally = grDevices::dev.off())
    compact_gallery_svg(file.path(output_dir, name))
  }
  invisible(names(figures))
}
