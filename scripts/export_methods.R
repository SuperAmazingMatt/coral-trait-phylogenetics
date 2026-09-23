#!/usr/bin/env Rscript
# Independent simulated illustrations. No empirical inputs are read.
# Run from the repository root. An optional argument selects the output folder.
required <- c("ape", "phytools", "GGally", "ggplot2")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Run scripts/install_dependencies.R first. Missing: ", paste(missing, collapse = ", "))
}
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 1L) stop("Supply at most one output directory.")
output_dir <- if (length(args)) args[[1]] else file.path("artifacts", "synthetic-validation", "methods")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# All seeds, dimensions and model settings are arbitrary illustration choices.
# Neither the tree nor the traits are calibrated against study data.
set.seed(613079L)
tree <- phytools::pbtree(b = 1, d = 0, n = 420, scale = 1)
tree$tip.label <- sprintf("simulated_tip_%03d", seq_len(ape::Ntip(tree)))
trait <- phytools::fastBM(tree, a = 0, sig2 = 1)
mapping <- phytools::contMap(tree, trait, plot = FALSE, res = 250)
mapping <- phytools::setMap(mapping, c(
  "#182D77", "#247D91", "#48A27D", "#D7BF48", "#ED932C", "#B32235"
))
tree_path <- file.path(output_dir, "method_tree.png")
grDevices::png(tree_path, width = 2400, height = 2400, res = 240,
              type = "cairo", bg = "white")
par(mar = c(1.9, 0.9, 0.65, 0.9), family = "sans", xpd = NA)
plot(mapping, type = "fan", legend = FALSE, ftype = "off", fsize = 0,
     lwd = 2.4, outline = FALSE, xlim = c(-1.05, 1.05), ylim = c(-1.05, 1.05))
par(fig = c(0, 1, 0, 1), mar = rep(0, 4), new = TRUE)
plot.new()
plot.window(xlim = c(0, 1), ylim = c(0, 1), xaxs = "i", yaxs = "i")
text(0.5, 0.024, "SIMULATED METHOD ILLUSTRATION", cex = 0.64, col = "#62696D")
invisible(dev.off())
stopifnot(ape::Ntip(tree) == 420L, ape::is.ultrametric(tree), file.exists(tree_path))

# Six mixed variables illustrate plotting operations and invented associations.
set.seed(61704L)
n <- 180L
u <- rnorm(n)
v <- rnorm(n)
example <- data.frame(
  A = exp(.45 * u + rnorm(n, sd = .65)),
  B = .35 * u + rnorm(n),
  C = -.4 * v + rnorm(n),
  D = factor(sample(c("a", "b", "c"), n, replace = TRUE)),
  E = factor(sample(c("a", "b"), n, replace = TRUE)),
  F = factor(sample(c("a", "b", "c"), n, replace = TRUE))
)
names(example) <- paste("Trait", LETTERS[1:6])
stopifnot(nrow(example) == n, !anyNA(example))
method_label <- function(data, mapping, ...) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = .5, y = .5, label = "Estimate\nassociation",
                      size = 3.1, colour = "#52616b") +
    ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1) + ggplot2::theme_void()
}
p <- GGally::ggpairs(example, title = "SIMULATED METHOD ILLUSTRATION",
  upper = list(continuous = method_label, combo = "box_no_facet", discrete = "count"),
  lower = list(continuous = "points", combo = GGally::wrap("facethist", bins = 20),
               discrete = "facetbar"), progress = FALSE
) + ggplot2::theme(
  axis.text = ggplot2::element_blank(), axis.title = ggplot2::element_blank(),
  axis.ticks = ggplot2::element_blank(), panel.grid.major = ggplot2::element_blank(),
  panel.grid.minor = ggplot2::element_blank(),
  strip.text = ggplot2::element_text(size = 10, colour = "#263d43"),
  legend.position = "none", plot.background = ggplot2::element_rect(fill = "white", colour = NA)
)
matrix_path <- file.path(output_dir, "method_matrix.png")
grDevices::png(matrix_path, width = 1800, height = 1680, res = 150,
              type = "cairo", bg = "white")
print(p, newpage = FALSE)
invisible(dev.off())
stopifnot(file.exists(matrix_path))
cat("Rendered independently simulated tree and trait matrix in ", output_dir, "\n", sep = "")
cat("R ", as.character(getRversion()), "\n", sep = "")
for (package in required) cat(package, as.character(utils::packageVersion(package)), "\n")
