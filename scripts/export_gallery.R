#!/usr/bin/env Rscript
# Regenerate the synthetic documentation illustrations from public code.
# Run from the repository root; no external input paths are accepted.
if (!file.exists(file.path("scripts", "run_workflow.R"))) {
  stop("Run this command from the repository root.", call. = FALSE)
}
source(file.path("scripts", "run_workflow.R"))
source(file.path("R", "gallery_plots.R"))

# The original synthetic workflow output is kept separate from this presentation.
gallery_output_dir <- file.path(output_dir, "gallery")
write_gallery_figures(fixture$tree, informed$traits, scores, summaries, gallery_output_dir)

gallery_dir <- file.path("docs", "figures")
dir.create(gallery_dir, recursive = TRUE, showWarnings = FALSE)
figures <- list(
  synthetic_tree.svg = c(
    "Synthetic circular phylogeny",
    paste("Entirely synthetic topology, branch lengths, traits and taxon identifiers.",
          "Two colours represent artificial states. No empirical inputs or study findings.")
  ),
  synthetic_imputation.svg = c(
    "Synthetic imputation comparison",
    paste("Entirely synthetic imputation errors for forest and forest plus tree axes.",
          "Continuous traits use RMSE divided by training SD; the binary trait uses",
          "misclassification proportion. One masking run does not establish superiority.")
  ),
  synthetic_pca.svg = c(
    "Synthetic principal component analysis",
    paste("PCA scores and variance explained for standardised imputed synthetic traits.",
          "Colours indicate artificial states. This is descriptive and does not",
          "propagate imputation uncertainty. No study findings are shown.")
  ),
  synthetic_correlation.svg = c(
    "Synthetic Spearman correlation matrix",
    paste("Pairwise Spearman correlations among imputed synthetic continuous traits.",
          "Cell colours and values show descriptive associations, not significance",
          "or causation. No study findings are shown.")
  ),
  synthetic_workflow.svg = c(
    "Synthetic research workflow overview",
    paste("Four methods stages: align tree and traits, impute missing observations,",
          "evaluate held-out predictions and explore multivariate patterns.",
          "Every example input and output is entirely synthetic.")
  )
)
for (filename in names(figures)) {
  svg <- readLines(file.path(gallery_output_dir, filename), encoding = "UTF-8", warn = FALSE)
  root <- grep("^<svg ", svg)
  if (length(root) != 1L || !endsWith(svg[root], ">")) {
    stop("Unexpected SVG root in generated figure.", call. = FALSE)
  }
  svg[root] <- sub("<svg ",
                   '<svg role="img" aria-labelledby="figure-title figure-description" ',
                   svg[root], fixed = TRUE)
  metadata <- c(
    paste0('<title id="figure-title">', figures[[filename]][1], "</title>"),
    paste0('<desc id="figure-description">', figures[[filename]][2], "</desc>")
  )
  # Preserve the generated drawing exactly; add only accessibility/provenance.
  svg <- append(svg, metadata, after = root)
  destination <- file(file.path(gallery_dir, filename), open = "wb")
  writeLines(svg, destination, useBytes = TRUE)
  close(destination)
}
cat("Gallery refreshed: five synthetic SVGs in docs/figures/. Review before publication.\n")
