# Public research workflow utilities. All bundled inputs are generated examples.
# This file contains no study records, study trees, or study estimates.

trait_columns <- function() c("Trait_A", "Trait_B", "Trait_C", "State_A")
continuous_columns <- function() c("Trait_A", "Trait_B", "Trait_C")

require_workflow_packages <- function() {
  required <- c("ape", "phytools", "missForest", "caper")
  absent <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(absent)) {
    stop("Missing R packages: ", paste(absent, collapse = ", "),
         ". Run Rscript scripts/install_dependencies.R.", call. = FALSE)
  }
  invisible(required)
}

validate_traits <- function(traits, allow_missing = TRUE) {
  expected <- c("taxon_id", trait_columns())
  if (!is.data.frame(traits) || !setequal(names(traits), expected) ||
      anyDuplicated(names(traits))) {
    stop("Trait table must contain exactly: ", paste(expected, collapse = ", "),
         call. = FALSE)
  }
  if (nrow(traits) < 12L) stop("At least 12 taxa are required.", call. = FALSE)
  ids <- traits$taxon_id
  if (!is.character(ids) || anyNA(ids) || anyDuplicated(ids) ||
      any(!grepl("^Taxon_[0-9]{3}$", ids))) {
    stop("Taxon IDs must be unique synthetic Taxon_000 identifiers.", call. = FALSE)
  }
  for (nm in continuous_columns()) {
    x <- traits[[nm]]
    if (!is.numeric(x) || any(!is.finite(x) & !is.na(x)) ||
        sum(!is.na(x)) < 4L || length(unique(x[!is.na(x)])) < 2L) {
      stop(nm, " must have at least four finite observations and nonzero variation.",
           call. = FALSE)
    }
  }
  state <- traits$State_A
  if (!is.factor(state) || !identical(levels(state), c("state_0", "state_1")) ||
      any(table(state) < 2L)) {
    stop("State_A must be a factor with both state_0/state_1 represented at least twice.",
         call. = FALSE)
  }
  if (!allow_missing && anyNA(traits)) {
    stop("This operation requires complete traits.", call. = FALSE)
  }
  invisible(TRUE)
}

validate_tree <- function(tree) {
  if (!inherits(tree, "phylo") || is.null(tree$edge.length) ||
      anyNA(tree$edge.length) || any(!is.finite(tree$edge.length)) ||
      any(tree$edge.length <= 0) || !ape::is.rooted(tree) ||
      !ape::is.binary(tree) || anyNA(tree$tip.label) ||
      anyDuplicated(tree$tip.label) || any(!grepl("^Taxon_[0-9]{3}$", tree$tip.label))) {
    stop("Tree must be rooted and binary, with positive branch lengths and unique synthetic IDs.",
         call. = FALSE)
  }
  invisible(TRUE)
}

align_traits_to_tree <- function(tree, traits) {
  validate_tree(tree)
  validate_traits(traits)
  if (!setequal(tree$tip.label, traits$taxon_id)) {
    stop("Tree and trait table must contain exactly the same taxa; no silent dropping.",
         call. = FALSE)
  }
  aligned <- traits[match(tree$tip.label, traits$taxon_id),
                    c("taxon_id", trait_columns()), drop = FALSE]
  rownames(aligned) <- aligned$taxon_id
  stopifnot(identical(aligned$taxon_id, tree$tip.label))
  aligned
}

make_synthetic_fixture <- function(n_taxa = 48L, seed = 2718L) {
  if (length(n_taxa) != 1L || !is.finite(n_taxa) || n_taxa < 24L ||
      n_taxa > 999L || n_taxa != as.integer(n_taxa)) {
    stop("n_taxa must be an integer between 24 and 999.", call. = FALSE)
  }
  set.seed(seed)
  ids <- sprintf("Taxon_%03d", seq_len(n_taxa))
  # A newly simulated coalescent tree, never a relabelled study tree.
  tree <- ape::rcoal(n_taxa, tip.label = ids)
  tree$edge.length <- tree$edge.length / max(ape::node.depth.edgelength(tree))
  a <- as.numeric(phytools::fastBM(tree))
  b <- 0.55 * a + as.numeric(phytools::fastBM(tree, sig2 = 0.8))
  c <- stats::rnorm(n_taxa)
  # This artificial binary split is deliberately balanced for the example.
  state <- as.numeric(a + stats::rnorm(n_taxa, sd = 0.6) > stats::median(a))
  if (min(tabulate(state + 1L, nbins = 2L)) < 4L) {
    state <- as.numeric(rank(a) > n_taxa / 2)
  }
  traits <- data.frame(
    taxon_id = tree$tip.label,
    Trait_A = as.numeric(scale(a)),
    Trait_B = as.numeric(scale(b)),
    Trait_C = as.numeric(scale(c)),
    State_A = factor(state, levels = c(0, 1), labels = c("state_0", "state_1")),
    stringsAsFactors = FALSE
  )
  validate_traits(traits, allow_missing = FALSE)
  validate_tree(tree)
  list(tree = tree, traits = align_traits_to_tree(tree, traits), seed = seed,
       provenance = "Entirely synthetic fixture; no study data or study tree used.")
}

mask_observed_cells <- function(traits, fraction = 0.15, seed = 2719L) {
  validate_traits(traits)
  if (length(fraction) != 1L || !is.finite(fraction) ||
      fraction <= 0 || fraction > 0.30) {
    stop("fraction must be greater than zero and at most 0.30.", call. = FALSE)
  }
  set.seed(seed)
  masked <- traits
  mask <- matrix(FALSE, nrow(traits), length(trait_columns()),
                 dimnames = list(traits$taxon_id, trait_columns()))
  for (nm in trait_columns()) {
    candidates <- which(!is.na(traits[[nm]]))
    # Keep each binary class observed after masking; no value is invented here.
    if (is.factor(traits[[nm]])) {
      chosen <- unlist(lapply(levels(traits[[nm]]), function(level) {
        pool <- candidates[as.character(traits[[nm]][candidates]) == level]
        count <- min(floor(length(pool) * fraction), length(pool) - 2L)
        if (count > 0L) sample(pool, count) else integer(0)
      }), use.names = FALSE)
    } else {
      count <- max(1L, floor(length(candidates) * fraction))
      chosen <- sample(candidates, count)
    }
    mask[chosen, nm] <- TRUE
    masked[[nm]][chosen] <- NA
  }
  validate_traits(masked)
  list(traits = masked, mask = mask, seed = seed)
}

phylogenetic_eigenvectors <- function(tree, n_axes = 3L) {
  validate_tree(tree)
  if (length(n_axes) != 1L || !is.finite(n_axes) || n_axes < 1L ||
      n_axes != as.integer(n_axes) || n_axes >= length(tree$tip.label)) {
    stop("n_axes must be a positive integer smaller than the number of taxa.",
         call. = FALSE)
  }
  # Leading eigenvectors of centred shared-branch covariance, using tree only.
  # No complete or held-out trait values enter this predictor construction.
  covariance <- ape::vcv.phylo(tree, corr = TRUE)[tree$tip.label, tree$tip.label]
  n <- nrow(covariance)
  centring <- diag(n) - matrix(1 / n, n, n)
  decomposition <- eigen(centring %*% covariance %*% centring, symmetric = TRUE)
  positive <- which(decomposition$values > max(decomposition$values) * 1e-10)
  if (length(positive) < n_axes) stop("Insufficient positive tree eigenvalues.", call. = FALSE)
  selected <- positive[seq_len(n_axes)]
  axes <- sweep(decomposition$vectors[, selected, drop = FALSE], 2,
                sqrt(decomposition$values[selected]), `*`)
  # Resolve arbitrary eigenvector signs for reproducible presentation.
  for (j in seq_len(ncol(axes))) {
    if (axes[which.max(abs(axes[, j])), j] < 0) axes[, j] <- -axes[, j]
  }
  rownames(axes) <- tree$tip.label
  colnames(axes) <- paste0("PhyloAxis_", seq_len(n_axes))
  axes
}

impute_traits <- function(tree, traits, use_phylogeny = FALSE,
                          seed = 2720L, ntree = 100L, maxiter = 5L) {
  aligned <- align_traits_to_tree(tree, traits)
  inputs <- aligned[, trait_columns(), drop = FALSE]
  if (!anyNA(inputs)) stop("Imputation requires at least one missing trait cell.", call. = FALSE)
  if (use_phylogeny) {
    axes <- phylogenetic_eigenvectors(tree)
    stopifnot(identical(rownames(inputs), rownames(axes)))
    inputs <- cbind(inputs, as.data.frame(axes))
  }
  set.seed(seed)
  fitted <- missForest::missForest(
    inputs, ntree = ntree, maxiter = maxiter, verbose = FALSE,
    parallelize = "no"
  )
  completed <- aligned
  completed[, trait_columns()] <- fitted$ximp[, trait_columns(), drop = FALSE]
  validate_traits(completed, allow_missing = FALSE)
  for (nm in trait_columns()) {
    observed <- !is.na(aligned[[nm]])
    if (!identical(completed[[nm]][observed], aligned[[nm]][observed])) {
      stop("Imputation altered observed values in ", nm, ".", call. = FALSE)
    }
  }
  list(traits = completed, oob_error = fitted$OOBerror, seed = seed,
       method = if (use_phylogeny) "forest_plus_tree_axes" else "forest_only")
}

score_masked_cells <- function(truth, completed, mask, method) {
  validate_traits(truth, allow_missing = FALSE)
  validate_traits(completed, allow_missing = FALSE)
  if (!setequal(truth$taxon_id, completed$taxon_id) || !is.logical(mask) ||
      !identical(rownames(mask), truth$taxon_id) ||
      !identical(colnames(mask), trait_columns()) || anyNA(mask)) {
    stop("Scoring inputs have incompatible IDs or mask dimensions.", call. = FALSE)
  }
  completed <- completed[match(truth$taxon_id, completed$taxon_id), , drop = FALSE]
  rows <- lapply(trait_columns(), function(nm) {
    held_out <- mask[, nm]
    if (!any(held_out)) return(NULL)
    target <- truth[[nm]][held_out]
    prediction <- completed[[nm]][held_out]
    if (is.numeric(target)) {
      # Scale is calculated only from the training observations.
      training_sd <- stats::sd(truth[[nm]][!held_out])
      error <- sqrt(mean((prediction - target)^2)) / training_sd
      metric <- "RMSE / training SD"
    } else {
      error <- mean(as.character(prediction) != as.character(target))
      metric <- "Misclassification proportion"
    }
    data.frame(method = method, trait = nm, metric = metric,
               masked_cells = sum(held_out), error = unname(error),
               provenance = "SYNTHETIC VALIDATION ONLY", stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

estimate_observed_signal <- function(tree, traits, n_sim = 99L, seed = 2721L) {
  aligned <- align_traits_to_tree(tree, traits)
  continuous <- lapply(seq_along(continuous_columns()), function(i) {
    nm <- continuous_columns()[i]
    keep <- !is.na(aligned[[nm]])
    reduced_tree <- ape::keep.tip(tree, aligned$taxon_id[keep])
    values <- setNames(aligned[[nm]][keep], aligned$taxon_id[keep])
    values <- values[reduced_tree$tip.label]
    set.seed(seed + i)
    lambda <- phytools::phylosig(reduced_tree, values, method = "lambda", test = TRUE)
    k <- phytools::phylosig(reduced_tree, values, method = "K", test = TRUE, nsim = n_sim)
    data.frame(trait = nm, observed_taxa = sum(keep),
               lambda = unname(lambda$lambda), lambda_lrt_p = unname(lambda$P),
               K = unname(k$K), K_randomization_p = unname(k$P),
               K_simulations = n_sim, provenance = "SYNTHETIC VALIDATION ONLY")
  })
  keep <- !is.na(aligned$State_A)
  reduced_tree <- ape::keep.tip(tree, aligned$taxon_id[keep])
  binary <- data.frame(taxon_id = aligned$taxon_id[keep],
                       state = as.integer(aligned$State_A[keep]) - 1L)
  set.seed(seed + 100L)
  d <- caper::phylo.d(data = binary, phy = reduced_tree, names.col = taxon_id,
                     binvar = state, permut = n_sim)
  d_summary <- data.frame(
    trait = "State_A", observed_taxa = sum(keep), D = unname(d$DEstimate),
    p_against_random = unname(d$Pval1), p_against_brownian = unname(d$Pval0),
    simulations = n_sim, provenance = "SYNTHETIC VALIDATION ONLY"
  )
  list(continuous = do.call(rbind, continuous), binary = d_summary)
}

describe_complete_traits <- function(tree, traits) {
  aligned <- align_traits_to_tree(tree, traits)
  validate_traits(aligned, allow_missing = FALSE)
  matrix <- as.matrix(aligned[, continuous_columns(), drop = FALSE])
  pca <- stats::prcomp(matrix, center = TRUE, scale. = TRUE)
  # These are descriptive summaries; no independent-species inference is made.
  list(pca = pca, correlation = stats::cor(matrix, method = "spearman"))
}

write_synthetic_figures <- function(tree, complete_traits, masked_traits,
                                    scores, summaries, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  complete <- align_traits_to_tree(tree, complete_traits)
  masked <- align_traits_to_tree(tree, masked_traits)
  colors <- c(state_0 = "#2A6F97", state_1 = "#C77D37")

  grDevices::svg(file.path(output_dir, "synthetic_tree.svg"), width = 9, height = 11)
  graphics::par(mar = c(3, 2, 5, 3), family = "sans", bg = "white")
  ape::plot.phylo(tree, tip.color = colors[as.character(complete$State_A)],
                 cex = 0.68, label.offset = 0.015, edge.color = "#51626D")
  graphics::title(main = "Synthetic phylogeny", line = 2.8, col.main = "#183B4E")
  graphics::mtext("Random topology, simulated branches, artificial taxon IDs", side = 3,
                  line = 1.3, cex = 0.83, col = "#526570")
  graphics::legend("topleft", legend = names(colors), pch = 19, col = colors,
                   bty = "n", cex = 0.8)
  ape::add.scale.bar(length = 0.2, lwd = 1, cex = 0.7)
  graphics::mtext("SYNTHETIC VALIDATION ONLY - NO STUDY DATA OR RESULTS", side = 1,
                  line = 1, cex = 0.77, col = "#526570")
  grDevices::dev.off()

  grDevices::svg(file.path(output_dir, "synthetic_workflow.svg"), width = 12, height = 9)
  graphics::par(mfrow = c(2, 2), mar = c(5, 4.5, 3, 1), oma = c(2, 0, 4, 0),
                family = "sans", bg = "white")
  missing <- 100 * colMeans(is.na(masked[, trait_columns(), drop = FALSE]))
  graphics::barplot(missing, col = "#2A6F97", border = NA,
                    ylim = c(0, max(25, max(missing) + 5)), ylab = "Missing cells (%)",
                    main = "1. Mask synthetic observations", las = 1, cex.names = 0.9)
  graphics::abline(h = 0, col = "#51626D")

  numeric_scores <- scores[scores$trait %in% continuous_columns(), ]
  comparison <- matrix(NA_real_, nrow = length(continuous_columns()), ncol = 2L)
  # Build explicitly by IDs rather than relying on a particular output row order.
  for (j in seq_len(ncol(comparison))) {
    for (i in seq_along(continuous_columns())) {
      comparison[i, j] <- numeric_scores$error[
        numeric_scores$trait == continuous_columns()[i] &
          numeric_scores$method == c("forest_only", "forest_plus_tree_axes")[j]]
    }
  }
  colnames(comparison) <- c("Forest", "Forest + tree axes")
  rownames(comparison) <- continuous_columns()
  graphics::barplot(t(comparison), beside = TRUE,
                    col = c("#2A6F97", "#C77D37"), border = NA,
                    ylim = c(0, max(comparison) * 1.3),
                    ylab = "Held-out RMSE / training SD",
                    main = "2. Check masked-cell prediction", cex.names = 0.9,
                    legend.text = colnames(comparison),
                    args.legend = list(bty = "n", cex = 0.75, x = "topright"))

  explained <- 100 * summaries$pca$sdev^2 / sum(summaries$pca$sdev^2)
  graphics::plot(summaries$pca$x[, 1:2], pch = 21, bg = "#2A6F97", col = "white",
                 cex = 1.3, xlab = sprintf("PC1 (%.1f%%)", explained[1]),
                 ylab = sprintf("PC2 (%.1f%%)", explained[2]),
                 main = "3. Explore imputed synthetic traits")
  graphics::abline(h = 0, v = 0, lty = 3, col = "#C7D1D6")
  graphics::mtext("PCA is descriptive; imputation uncertainty is not propagated", side = 1,
                  line = 3.7, cex = 0.65)

  r <- summaries$correlation
  graphics::image(seq_len(nrow(r)), seq_len(ncol(r)), r, zlim = c(-1, 1),
                  col = grDevices::colorRampPalette(c("#C77D37", "#FAFAF5", "#2A6F97"))(101),
                  axes = FALSE, xlab = "", ylab = "", main = "4. Inspect descriptive associations")
  graphics::axis(1, at = seq_len(nrow(r)), labels = rownames(r), tick = FALSE, cex.axis = 0.9)
  graphics::axis(2, at = seq_len(ncol(r)), labels = colnames(r), tick = FALSE,
                 las = 1, cex.axis = 0.9)
  for (i in seq_len(nrow(r))) for (j in seq_len(ncol(r))) {
    graphics::text(i, j, sprintf("%.2f", r[i, j]),
                   col = if (abs(r[i, j]) > 0.7) "white" else "#183B4E")
  }
  graphics::mtext("Spearman correlation; no significance tests", side = 1, line = 3,
                  cex = 0.75)
  graphics::mtext("Coral trait phylogenetics | Synthetic workflow validation", outer = TRUE,
                  side = 3, line = 1.7, font = 2, cex = 1.3, col = "#183B4E")
  graphics::mtext("SYNTHETIC VALIDATION ONLY - NO STUDY DATA OR RESULTS", outer = TRUE,
                  side = 1, line = 0.4, cex = 0.85, col = "#526570")
  grDevices::dev.off()
  invisible(NULL)
}
