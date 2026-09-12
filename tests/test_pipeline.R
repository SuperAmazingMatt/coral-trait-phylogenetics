#!/usr/bin/env Rscript
# Contract tests for consequential errors: ID mismatches, leakage, changed
# observations, invalid inputs, and reproducibility. No private inputs needed.
if (!file.exists(file.path("R", "workflow.R"))) {
  stop("Run tests from the repository root.", call. = FALSE)
}
source(file.path("R", "workflow.R"))
require_workflow_packages()

checks <- 0L
check <- function(condition, message) {
  if (!isTRUE(condition)) stop(message, call. = FALSE)
  checks <<- checks + 1L
}
fails <- function(expression, expected) {
  message <- tryCatch({force(expression); ""}, error = function(e) conditionMessage(e))
  check(nzchar(message) && grepl(expected, message, fixed = TRUE),
        paste("Expected validation failure:", expected))
}

fixture <- make_synthetic_fixture(n_taxa = 32L, seed = 41L)
repeated <- make_synthetic_fixture(n_taxa = 32L, seed = 41L)
check(identical(fixture, repeated), "The same seed must reproduce the entire fixture.")
check(!identical(fixture$tree$edge, make_synthetic_fixture(32L, 42L)$tree$edge),
      "Different seeds must not reuse the same tree topology.")
check(ape::is.ultrametric(fixture$tree), "The simulated example tree must be ultrametric.")

set.seed(43L)
shuffled <- fixture$traits[sample(seq_len(nrow(fixture$traits))), ]
aligned <- align_traits_to_tree(fixture$tree, shuffled)
check(identical(aligned, fixture$traits), "Row shuffling must not change taxon-to-trait alignment.")
invalid <- fixture$traits
invalid$taxon_id[1] <- invalid$taxon_id[2]
fails(validate_traits(invalid), "unique synthetic")
invalid <- fixture$traits
invalid$taxon_id[1] <- "Taxon_999"
fails(align_traits_to_tree(fixture$tree, invalid), "exactly the same taxa")
invalid <- fixture$traits
invalid$Trait_A[1] <- Inf
fails(validate_traits(invalid), "finite observations")
invalid <- fixture$traits
invalid$Trait_B <- rep(1, nrow(invalid))
fails(validate_traits(invalid), "nonzero variation")
invalid <- fixture$traits
invalid$State_A <- as.character(invalid$State_A)
fails(validate_traits(invalid), "must be a factor")
invalid_tree <- fixture$tree
invalid_tree$edge.length[1] <- 0
fails(validate_tree(invalid_tree), "positive branch lengths")
fails(mask_observed_cells(fixture$traits, fraction = 1), "at most 0.30")

masked <- mask_observed_cells(fixture$traits, seed = 44L)
check(identical(masked, mask_observed_cells(fixture$traits, seed = 44L)),
      "Mask sampling must be reproducible.")
check(identical(is.na(masked$traits[, trait_columns()]), masked$mask),
      "Every introduced missing cell must be identified in the hold-out mask.")
for (nm in trait_columns()) {
  observed <- !masked$mask[, nm]
  check(identical(masked$traits[[nm]][observed], fixture$traits[[nm]][observed]),
        paste("Masking modified an observed value in", nm))
}
already_missing <- fixture$traits
already_missing$Trait_A[1] <- NA_real_
second_mask <- mask_observed_cells(already_missing, seed = 45L)
check(!second_mask$mask[1, "Trait_A"] && is.na(second_mask$traits$Trait_A[1]),
      "Pre-existing missing values must never be scored as artificial hold-outs.")

axes <- phylogenetic_eigenvectors(fixture$tree)
check(identical(rownames(axes), fixture$tree$tip.label) &&
        identical(dim(axes), c(32L, 3L)) && all(is.finite(axes)),
      "Tree predictors must be finite and keyed to tip IDs.")

baseline <- impute_traits(fixture$tree, masked$traits, seed = 46L, ntree = 40L, maxiter = 3L)
informed <- impute_traits(fixture$tree, masked$traits, use_phylogeny = TRUE,
                          seed = 46L, ntree = 40L, maxiter = 3L)
repeat_informed <- impute_traits(fixture$tree, masked$traits, use_phylogeny = TRUE,
                                 seed = 46L, ntree = 40L, maxiter = 3L)
check(identical(informed$traits, repeat_informed$traits),
      "Imputation must reproduce with the same seed and package versions.")
for (result in list(baseline, informed)) {
  check(!anyNA(result$traits) && identical(result$traits$taxon_id, fixture$tree$tip.label),
        "Imputation must complete the table without reassigning IDs.")
  for (nm in trait_columns()) {
    observed <- !is.na(masked$traits[[nm]])
    check(identical(result$traits[[nm]][observed], fixture$traits[[nm]][observed]),
          paste("Imputation changed an observed value in", nm))
  }
}

score <- score_masked_cells(fixture$traits, informed$traits, masked$mask, informed$method)
check(nrow(score) == 4L && all(is.finite(score$error)) && all(score$error >= 0),
      "Each trait must have a finite held-out error.")
altered <- informed$traits
altered$Trait_A[!masked$mask[, "Trait_A"]] <-
  altered$Trait_A[!masked$mask[, "Trait_A"]] + 100
altered_score <- score_masked_cells(fixture$traits, altered, masked$mask, informed$method)
check(identical(score, altered_score),
      "Hold-out scores must not include predictions for unmasked cells.")
perfect <- score_masked_cells(fixture$traits, fixture$traits, masked$mask, "perfect")
check(all(perfect$error == 0), "Exact held-out predictions must have zero error.")
wrong_mask <- masked$mask
rownames(wrong_mask) <- rev(rownames(wrong_mask))
fails(score_masked_cells(fixture$traits, informed$traits, wrong_mask, "invalid"),
      "incompatible IDs")

signal <- estimate_observed_signal(fixture$tree, masked$traits, n_sim = 19L, seed = 47L)
expected_counts <- colSums(!is.na(masked$traits[, continuous_columns()]))
check(identical(as.numeric(signal$continuous$observed_taxa), as.numeric(expected_counts)),
      "Continuous signal must use only observed entries for each trait.")
check(signal$binary$observed_taxa == sum(!is.na(masked$traits$State_A)),
      "Binary signal must exclude missing states.")
check(all(is.finite(signal$continuous$lambda)) && all(is.finite(signal$continuous$K)) &&
        is.finite(signal$binary$D), "Signal estimates must be finite on the synthetic fixture.")

summaries <- describe_complete_traits(fixture$tree, informed$traits)
check(identical(dim(summaries$pca$x), c(32L, 3L)) &&
        all(diag(summaries$correlation) == 1) &&
        isTRUE(all.equal(summaries$correlation, t(summaries$correlation))),
      "Descriptive summaries must retain all taxa and a symmetric correlation matrix.")

cat(sprintf("PASS: %d workflow contract checks; synthetic data only.\n", checks))
