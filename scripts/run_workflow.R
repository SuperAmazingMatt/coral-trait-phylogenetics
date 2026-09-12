#!/usr/bin/env Rscript
# Run from the repository root: Rscript scripts/run_workflow.R
# All data and tree inputs are generated in memory from a fixed seed.

if (!file.exists(file.path("R", "workflow.R"))) {
  stop("Run this command from the repository root.", call. = FALSE)
}
source(file.path("R", "workflow.R"))
packages <- require_workflow_packages()

cat("Coral trait phylogenetics: synthetic workflow validation\n")
cat("No study records, tree, or research results are used.\n")

fixture <- make_synthetic_fixture(n_taxa = 48L, seed = 2718L)
masked <- mask_observed_cells(fixture$traits, fraction = 0.15, seed = 2719L)
cat("[1/6] Generated synthetic tree and traits; validated IDs and masked observations.\n")

baseline <- impute_traits(fixture$tree, masked$traits, seed = 2720L)
informed <- impute_traits(fixture$tree, masked$traits, use_phylogeny = TRUE, seed = 2720L)
scores <- rbind(
  score_masked_cells(fixture$traits, baseline$traits, masked$mask, baseline$method),
  score_masked_cells(fixture$traits, informed$traits, masked$mask, informed$method)
)
cat("[2/6] Compared forest imputation with and without tree-derived predictors.\n")

# Signal is estimated from observed (unmasked) synthetic entries only.
# 99 simulations are a quick execution check, not a research-quality analysis.
signal <- estimate_observed_signal(fixture$tree, masked$traits, n_sim = 99L, seed = 2721L)
cat("[3/6] Estimated continuous lambda/K and binary D from observed entries.\n")

summaries <- describe_complete_traits(fixture$tree, informed$traits)
cat("[4/6] Computed descriptive PCA and Spearman correlations.\n")

output_dir <- file.path("artifacts", "synthetic-validation")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(scores, file.path(output_dir, "synthetic_imputation_metrics.csv"), row.names = FALSE)
utils::write.csv(signal$continuous, file.path(output_dir, "synthetic_continuous_signal.csv"), row.names = FALSE)
utils::write.csv(signal$binary, file.path(output_dir, "synthetic_binary_signal.csv"), row.names = FALSE)
variance <- summaries$pca$sdev^2 / sum(summaries$pca$sdev^2)
utils::write.csv(data.frame(component = paste0("PC", seq_along(variance)),
                            variance_fraction = variance,
                            provenance = "SYNTHETIC VALIDATION ONLY"),
                  file.path(output_dir, "synthetic_pca_variance.csv"), row.names = FALSE)
write_synthetic_figures(fixture$tree, informed$traits, masked$traits, scores, summaries, output_dir)
cat("[5/6] Wrote labelled synthetic figures and metrics.\n")

# A minimal environment record avoids usernames, hostnames, and local paths.
versions <- data.frame(package = packages,
                       version = vapply(packages, function(p) as.character(utils::packageVersion(p)),
                                        character(1)), row.names = NULL)
utils::write.csv(versions, file.path(output_dir, "package_versions.csv"), row.names = FALSE)
writeLines(c(
  "SYNTHETIC VALIDATION ONLY",
  "All input values, topology, branches, identifiers and displayed estimates are artificial.",
  "No complete input tables or tree files are exported by this workflow.",
  "Fixture seed: 2718; masking: 2719; imputation: 2720; signal: 2721.",
  "Continuous signal uses available observations for each trait; binary D excludes missing states.",
  "The comparison uses one random mask and is not evidence that either imputation method is better.",
  "Masking approximates missing completely at random; real missingness may be nonrandom.",
  "Lambda likelihood-ratio p-values are asymptotic; K and D use 99 simulations for execution checks.",
  "PCA/correlation describe imputed synthetic values without propagating imputation uncertainty.",
  paste("R version:", getRversion())
), file.path(output_dir, "PROVENANCE.txt"))
cat("[6/6] Complete. Outputs: artifacts/synthetic-validation/\n")
