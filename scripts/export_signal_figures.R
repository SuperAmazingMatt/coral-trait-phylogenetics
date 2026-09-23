#!/usr/bin/env Rscript
# Fit and illustrate comparative methods using newly generated inputs only.
# Run from the repository root. The optional argument selects an output folder.
# No trait tables, saved trees, fitted objects, or study results are read.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 1L) stop("Supply at most one output directory.", call. = FALSE)
if (!file.exists(file.path("R", "workflow.R"))) {
  stop("Run this command from the repository root.", call. = FALSE)
}
output_dir <- if (length(args)) args[[1L]] else {
  file.path("artifacts", "synthetic-validation", "methods")
}
required <- c("ape", "phytools", "caper", "ggplot2")
for (pkg in required) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Install the required package: ", pkg, call. = FALSE)
  }
}
if (!capabilities("cairo")) stop("Cairo graphics support is required.", call. = FALSE)
started <- proc.time()[["elapsed"]]
cat("SIMULATED METHOD ILLUSTRATIONS; no empirical inputs.\n")
cat(R.version.string, "\n")
for (pkg in required) cat(pkg, as.character(utils::packageVersion(pkg)), "\n")
cat("Seeds: signal 61821; branch perturbations 61822; Brownian replicates 61823.\n")
cat("One generated 36-tip coalescent tree is scaled to unit height.\n")
cat("Signal: four continuous toy traits; three median-thresholded two-state traits; D uses 99 permutations.\n")
cat("Sensitivity: 14 lognormal branch-length perturbations (log SD 0.30), fixed topology and tip values.\n")
cat("Brownian comparison: 36 independent fastBM replicates, sig2 = 1; theoretical reference = 1.\n")
cat("Counts and parameters are demonstration choices, not study sample sizes or estimates.\n")

# Fitting warnings are errors rather than silently discarded. A failed fit
# stops the export; no substitute estimate is supplied.
checked <- function(expr, context) {
  withCallingHandlers(
    tryCatch(expr, error = function(e) {
      stop(context, ": ", conditionMessage(e), call. = FALSE)
    }),
    warning = function(w) stop(context, ": ", conditionMessage(w), call. = FALSE)
  )
}
signal_fit <- function(tree, values, context) {
  stopifnot(identical(names(values), tree$tip.label), all(is.finite(values)))
  lambda <- checked(
    phytools::phylosig(tree, values, method = "lambda", test = FALSE),
    paste(context, "lambda")
  )$lambda
  k <- as.numeric(checked(
    phytools::phylosig(tree, values, method = "K", test = FALSE),
    paste(context, "K")
  ))
  estimates <- c(Lambda = unname(lambda), K = k)
  if (length(estimates) != 2L || any(!is.finite(estimates))) {
    stop(context, ": nonfinite signal estimate.", call. = FALSE)
  }
  estimates
}

set.seed(61821L)
tree <- ape::rcoal(36L, tip.label = sprintf("Taxon_%03d", seq_len(36L)))
tree$edge.length <- tree$edge.length / max(ape::node.depth.edgelength(tree))
trait_names <- paste("Trait", LETTERS[1:4])
continuous <- lapply(seq_along(trait_names), function(i) {
  bm <- phytools::fastBM(tree, sig2 = 1)
  # Varying added Gaussian noise illustrates more than one fitted value.
  # The parameters are chosen in advance and are not fitted to study data.
  values <- bm + stats::rnorm(length(bm), sd = c(0, 0.20, 0.55, 0.90)[i])
  values[tree$tip.label]
})
names(continuous) <- trait_names
continuous_fits <- lapply(seq_along(continuous), function(i) {
  fit <- signal_fit(tree, continuous[[i]], paste("Signal trait", i))
  data.frame(trait = trait_names[i], metric = names(fit), value = unname(fit))
})
signal_continuous <- do.call(rbind, continuous_fits)
binary_rows <- lapply(seq_len(3L), function(i) {
  latent <- phytools::fastBM(tree, sig2 = 1) +
    stats::rnorm(length(tree$tip.label), sd = c(0, 0.45, 1)[i])
  binary <- data.frame(taxon_id = tree$tip.label,
                       state = as.integer(latent[tree$tip.label] > stats::median(latent)))
  fitted <- checked(
    caper::phylo.d(data = binary, phy = tree, names.col = taxon_id,
                  binvar = state, permut = 99L),
    paste("Binary signal trait", i)
  )
  if (!is.finite(fitted$DEstimate)) stop("Nonfinite D estimate.", call. = FALSE)
  data.frame(trait = paste("State", LETTERS[i]), metric = "D", value = fitted$DEstimate)
})
signal_binary <- do.call(rbind, binary_rows)

# These are deliberately perturbed branches, not posterior-tree samples.
set.seed(61822L)
sensitivity_rows <- vector("list", 14L * 3L)
row <- 0L
for (replicate in seq_len(14L)) {
  altered <- tree
  altered$edge.length <- tree$edge.length * exp(stats::rnorm(length(tree$edge.length), sd = 0.30))
  for (i in seq_len(3L)) {
    row <- row + 1L
    fit <- signal_fit(altered, continuous[[i]], paste("Perturbation", replicate, "trait", i))
    sensitivity_rows[[row]] <- data.frame(
      trait = trait_names[i], metric = names(fit), value = unname(fit), replicate = replicate
    )
  }
}
sensitivity <- do.call(rbind, sensitivity_rows)
baseline <- signal_continuous[signal_continuous$trait %in% trait_names[1:3], ]

set.seed(61823L)
brownian_rows <- lapply(seq_len(36L), function(replicate) {
  values <- phytools::fastBM(tree, a = 0, sig2 = 1)[tree$tip.label]
  fit <- signal_fit(tree, values, paste("Brownian replicate", replicate))
  data.frame(metric = names(fit), value = unname(fit), replicate = replicate)
})
brownian <- do.call(rbind, brownian_rows)
cat("Fits completed: 4 continuous signal traits, 3 two-state traits, 42 sensitivity fits, 36 Brownian replicates.\n")

palette <- c("Trait A" = "#1B7977", "Trait B" = "#5484AB", "Trait C" = "#BC8741", "Trait D" = "#857198")
ink <- "#203E4A"
muted <- "#647983"
paper_grid <- "#E5ECEE"
theme_figure <- function() {
  ggplot2::theme_minimal(base_size = 15, base_family = "sans") +
    ggplot2::theme(
      text = ggplot2::element_text(colour = ink),
      axis.text = ggplot2::element_text(colour = muted),
      axis.title = ggplot2::element_text(size = 13, colour = muted),
      panel.grid.major = ggplot2::element_line(colour = paper_grid, linewidth = 0.45),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_blank(),
      legend.position = "none",
      plot.title = ggplot2::element_text(face = "bold", size = 20, margin = ggplot2::margin(b = 10)),
      plot.subtitle = ggplot2::element_text(size = 12, colour = muted, margin = ggplot2::margin(b = 16)),
      plot.margin = ggplot2::margin(12, 22, 12, 8),
      strip.text = ggplot2::element_text(size = 18, face = "bold", colour = ink),
      strip.background = ggplot2::element_rect(fill = "#F1F6F6", colour = NA),
      panel.spacing = grid::unit(1.2, "lines")
    )
}
draw_figure <- function(filename, title, subtitle, plots, footer) {
  grDevices::png(file.path(output_dir, filename), width = 2000, height = 1400,
                 res = 160, type = "cairo", bg = "white")
  on.exit(grDevices::dev.off(), add = TRUE)
  grid::grid.newpage()
  grid::grid.text("COMPARATIVE METHODS", x = 0.05, y = 0.955, just = "left",
                  gp = grid::gpar(col = "#1B7977", fontsize = 11, fontface = "bold"))
  grid::grid.text(title, x = 0.05, y = 0.902, just = "left",
                  gp = grid::gpar(col = ink, fontsize = 29, fontface = "bold"))
  grid::grid.text(subtitle, x = 0.05, y = 0.846, just = "left",
                  gp = grid::gpar(col = muted, fontsize = 14))
  n <- length(plots)
  for (i in seq_along(plots)) {
    print(plots[[i]], newpage = FALSE,
          vp = grid::viewport(x = 0.045 + (i - 0.5) * 0.91 / n,
                              y = 0.465, width = 0.91 / n, height = 0.66))
  }
  grid::grid.text(footer, x = 0.05, y = 0.096, just = "left",
                  gp = grid::gpar(col = muted, fontsize = 11))
  grid::grid.lines(x = c(0.05, 0.95), y = c(0.063, 0.063),
                   gp = grid::gpar(col = paper_grid, lwd = 1))
  grid::grid.text("SIMULATED METHOD ILLUSTRATION", x = 0.05, y = 0.034, just = "left",
                  gp = grid::gpar(col = "#1B7977", fontsize = 10, fontface = "bold"))
  grid::grid.text("Generated inputs  /  Reproducible fits", x = 0.95, y = 0.034, just = "right",
                  gp = grid::gpar(col = muted, fontsize = 10))
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
metric_plots <- lapply(c("Lambda", "K", "D"), function(metric) {
  data <- if (metric == "D") signal_binary else signal_continuous[signal_continuous$metric == metric, ]
  data$trait <- factor(data$trait, levels = rev(unique(data$trait)))
  refs <- if (metric == "K") 1 else c(0, 1)
  title <- switch(metric, Lambda = expression("Pagel's " * lambda), K = expression("Blomberg's " * K), D = expression("Fritz-Purvis " * D))
  subtitle <- if (metric == "D") "Two-state traits" else "Continuous traits"
  colours <- if (metric == "D") rep("#1B7977", nrow(data)) else palette[as.character(data$trait)]
  ggplot2::ggplot(data, ggplot2::aes(x = value, y = trait)) +
    ggplot2::geom_vline(xintercept = refs, linetype = "dashed", colour = "#ABBCC3", linewidth = 0.65) +
    ggplot2::geom_segment(ggplot2::aes(x = 0, xend = value, yend = trait), colour = "#DAE7E9", linewidth = 2.5) +
    ggplot2::geom_point(colour = colours, size = 5) +
    ggplot2::scale_x_continuous(limits = range(c(data$value, refs)) + c(-0.14, 0.14),
                               breaks = function(limits) pretty(limits, n = 4)) +
    ggplot2::scale_y_discrete(expand = ggplot2::expansion(add = 0.6)) +
    ggplot2::labs(title = title, subtitle = subtitle, x = "Fitted statistic", y = NULL) + theme_figure()
})
draw_figure("method_signal.png", "Measuring phylogenetic signal",
            "Three statistics describe different aspects of trait resemblance across a tree.", metric_plots,
            "Reference lines: lambda = 0, 1; K = 1.  D = 0: Brownian threshold expectation; D = 1: random tip distribution.\nPoints are fitted to generated traits. Estimates use different scales and are not directly interchangeable.")

for (object in c("sensitivity", "baseline")) {
  values <- get(object)
  values$trait <- factor(values$trait, levels = rev(trait_names[1:3]))
  values$metric <- factor(values$metric, levels = c("Lambda", "K"),
                          labels = c("Pagel's lambda", "Blomberg's K"))
  assign(object, values)
}
sensitivity_plot <- ggplot2::ggplot(sensitivity, ggplot2::aes(value, trait, colour = trait)) +
  ggplot2::geom_boxplot(width = 0.43, outlier.shape = NA, fill = "#F3F7F7", linewidth = 0.75, orientation = "y") +
  ggplot2::geom_point(position = ggplot2::position_jitter(width = 0, height = 0.12, seed = 12),
                       size = 2.3, alpha = 0.68) +
  ggplot2::geom_point(data = baseline, shape = 23, fill = "white", colour = ink, size = 4, stroke = 1.2) +
  ggplot2::facet_wrap(~metric, nrow = 1, scales = "free_x") +
  ggplot2::scale_colour_manual(values = palette) +
  ggplot2::scale_y_discrete(expand = ggplot2::expansion(add = 0.6)) +
  ggplot2::labs(x = "Fitted statistic", y = NULL) + theme_figure()
draw_figure("method_tree_sensitivity.png", "Checking branch-length sensitivity",
            "Hold the topology and tip values fixed, perturb branch lengths, and refit each statistic.", list(sensitivity_plot),
            "Points: generated branch-length perturbations. Outlined diamonds: fits on the unchanged tree.\nBoxes summarise the toy perturbation distribution; they are not posterior credible intervals.")

brownian$metric <- factor(brownian$metric, levels = c("Lambda", "K"),
                          labels = c("Pagel's lambda", "Blomberg's K"))
brownian_plot <- ggplot2::ggplot(brownian, ggplot2::aes(value)) +
  ggplot2::geom_histogram(bins = 12, fill = "#5484AB", colour = "white", linewidth = 0.7) +
  ggplot2::geom_vline(xintercept = 1, colour = "#BC8741", linewidth = 1, linetype = "dashed") +
  ggplot2::geom_rug(colour = ink, alpha = 0.45, linewidth = 0.6) +
  ggplot2::facet_wrap(~metric, nrow = 1, scales = "free_x") +
  ggplot2::labs(x = "Fitted statistic", y = "Simulation count") + theme_figure() +
  ggplot2::theme(panel.grid.major.y = ggplot2::element_line(colour = paper_grid, linewidth = 0.45),
                 panel.grid.major.x = ggplot2::element_blank())
draw_figure("method_brownian.png", "Building a Brownian-motion reference",
            "Simulate fresh trait values on the same generated tree, then refit lambda and K for every replicate.", list(brownian_plot),
            "Dashed line: the Brownian model reference of 1. Bars and rugs: fitted values across independent simulations.\nFinite-sample estimates vary around the model reference. These are method illustrations, not tests of a study trait.")
cat("Wrote method_signal.png, method_tree_sensitivity.png, method_brownian.png\n")
cat(sprintf("Elapsed time: %.2f seconds\n", proc.time()[["elapsed"]] - started))
