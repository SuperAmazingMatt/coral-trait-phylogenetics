#!/usr/bin/env Rscript
# Simulated trait distributions, coverage and categorical tree mapping.
# No input files or research estimates are read. Run from the repository root.
required <- c("ape", "phytools")
if (!all(vapply(required, requireNamespace, logical(1), quietly = TRUE))) {
  stop("Run scripts/install_dependencies.R first.")
}
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 1L) stop("Supply at most one output directory.")
output_dir <- if (length(args)) args[[1]] else file.path("artifacts", "synthetic-validation", "methods")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
ink <- "#223A3F"
muted <- "#596B70"
teal <- "#247D91"
coral <- "#D88165"
line <- "#DFE6E5"

# Use the same invented mixed-trait construction as the pairs-matrix example.
set.seed(61704L)
n <- 180L
u <- rnorm(n)
v <- rnorm(n)
traits <- data.frame(
  A = exp(.45 * u + rnorm(n, sd = .65)),
  B = .35 * u + rnorm(n),
  C = -.4 * v + rnorm(n),
  D = factor(sample(c("a", "b", "c"), n, replace = TRUE)),
  E = factor(sample(c("a", "b"), n, replace = TRUE)),
  F = factor(sample(c("a", "b", "c"), n, replace = TRUE))
)
names(traits) <- paste("Trait", LETTERS[1:6])
stopifnot(nrow(traits) == n, !anyNA(traits))

grDevices::png(file.path(output_dir, "method_distributions.png"),
               width = 2000, height = 1400, res = 170, type = "cairo", bg = "white")
par(mfrow = c(2, 3), oma = c(3.2, 1, 4.6, 1), mar = c(3.6, 3.8, 2.1, 1),
    family = "sans", mgp = c(2.3, .6, 0), tcl = -.2, las = 1,
    col.axis = muted, col.lab = ink, col.main = ink, cex = .95)
for (i in 1:3) {
  hist(traits[[i]], breaks = "FD", col = teal, border = "white",
       main = names(traits)[i], xlab = "Simulated value", ylab = "Frequency")
}
for (i in 4:6) {
  values <- table(traits[[i]])
  barplot(values, col = coral, border = NA, names.arg = paste("State", seq_along(values)),
          ylim = c(0, max(values) * 1.15), main = names(traits)[i],
          xlab = "Invented category", ylab = "Frequency")
}
mtext("Trait distributions", side = 3, outer = TRUE, line = 2.7, cex = 1.5, font = 2, col = ink)
mtext("Continuous values and categorical frequencies in a generated trait table",
      side = 3, outer = TRUE, line = 1.1, cex = .85, col = muted)
mtext("SIMULATED METHOD ILLUSTRATION", side = 1, outer = TRUE, line = 1.5, cex = .75, col = muted)
invisible(dev.off())

# These arbitrary masking rates illustrate coverage differences, not study gaps.
set.seed(61705L)
masking_rates <- c(.08, .25, .40, .18, .30, .50)
missing <- vapply(masking_rates, function(rate) runif(n) < rate, logical(n))
colnames(missing) <- names(traits)
coverage <- 100 * colMeans(!missing)
stopifnot(all(coverage > 0 & coverage < 100))
grDevices::png(file.path(output_dir, "method_coverage.png"),
               width = 2000, height = 1400, res = 170, type = "cairo", bg = "white")
layout(matrix(c(1, 2), nrow = 1), widths = c(1.1, 1))
par(oma = c(4, 1, 5, 1), mar = c(4.5, 4.5, 4, 1), family = "sans",
    mgp = c(2.5, .6, 0), tcl = -.2, col.axis = muted, col.lab = ink, col.main = ink)
shown <- 48L
image(x = seq_len(ncol(missing)), y = seq_len(shown),
      z = t(!missing[shown:1, , drop = FALSE]) * 1,
      col = c(line, teal), breaks = c(-.5, .5, 1.5), axes = FALSE,
      xlab = "", ylab = "Generated observations")
axis(1, at = 1:6, labels = names(traits), las = 2, tick = FALSE, cex.axis = .8)
abline(v = seq(.5, 6.5), col = "white", lwd = 1.7)
mtext("Where are the gaps?", side = 3, line = 2, cex = 1.1, font = 2, col = ink)
mtext("First 48 generated rows", side = 3, line = .5, cex = .76, col = muted)
par(mar = c(4.5, 4.5, 4, 1), las = 1)
positions <- barplot(rev(coverage), horiz = TRUE, xlim = c(0, 113),
                     names.arg = rev(names(traits)), col = teal, border = NA,
                     xlab = "Available entries (%)", axes = FALSE)
axis(1, at = c(0, 25, 50, 75, 100), col = line, col.ticks = line)
text(rev(coverage) + 3, positions, paste0(round(rev(coverage)), "%"),
     adj = 0, cex = .8, col = ink)
mtext("Coverage by trait", side = 3, line = 2, cex = 1.1, font = 2, col = ink)
mtext("All generated rows", side = 3, line = .5, cex = .76, col = muted)
mtext("Trait coverage and missingness", side = 3, outer = TRUE, line = 2.5, cex = 1.5, font = 2, col = ink)
mtext("Known entries are deliberately hidden to illustrate data inspection",
      side = 3, outer = TRUE, line = 1.3, cex = .85, col = muted)
mtext("Teal = available    |    Pale grey = deliberately hidden", side = 1,
      outer = TRUE, line = 1.1, cex = .8, col = muted)
mtext("SIMULATED METHOD ILLUSTRATION", side = 1, outer = TRUE, line = 2.5, cex = .75, col = muted)
invisible(dev.off())

# A new tree and thresholded Brownian trait illustrate discrete tip mapping.
# Internal branches are neutral: no discrete ancestral states are inferred.
set.seed(61706L)
tree <- phytools::pbtree(b = 1, d = 0, n = 180, scale = 1)
tree$tip.label <- sprintf("simulated_tip_%03d", seq_len(ape::Ntip(tree)))
latent <- phytools::fastBM(tree)
states <- cut(latent, breaks = c(-Inf, quantile(latent, c(1/3, 2/3)), Inf),
              labels = c("State 1", "State 2", "State 3"), include.lowest = TRUE)
names(states) <- names(latent)
state_colors <- c("State 1" = teal, "State 2" = coral, "State 3" = "#A594C3")
stopifnot(!anyNA(states), identical(names(states), tree$tip.label), ape::is.ultrametric(tree))
grDevices::png(file.path(output_dir, "method_categorical_tree.png"),
               width = 2400, height = 2400, res = 240, type = "cairo", bg = "white")
par(mar = c(3.8, 1, 4, 1), family = "sans", xpd = NA)
ape::plot.phylo(tree, type = "fan", show.tip.label = FALSE, edge.color = "#879A9D",
                 edge.width = 1.4, no.margin = FALSE,
                 x.lim = c(-1.13, 1.13), y.lim = c(-1.13, 1.13))
ape::tiplabels(pch = 21, bg = state_colors[as.character(states)],
               col = "white", lwd = .7, cex = .75)
title("Mapping categorical traits", line = 1.8, cex.main = 1.45, col.main = ink)
mtext("Invented tip states on an independently simulated phylogeny",
      side = 3, line = .4, cex = .84, col = muted)
legend("bottom", legend = names(state_colors), pt.bg = state_colors,
       pch = 21, col = "white", pt.cex = 1.4, bty = "n", horiz = TRUE,
       inset = c(0, -.07), text.col = ink, cex = .85)
mtext("SIMULATED METHOD ILLUSTRATION", side = 1, line = 2.4, cex = .7, col = muted)
invisible(dev.off())
cat("Rendered three simulated trait illustrations.\n")
cat("Trait construction seed: 61704; masking: 61705; categorical tree: 61706.\n")
cat("Coverage illustrates arbitrary artificial gaps; tip colours are thresholded simulated values.\n")
cat("R", as.character(getRversion()), "\n")
for (package in required) cat(package, as.character(utils::packageVersion(package)), "\n")
