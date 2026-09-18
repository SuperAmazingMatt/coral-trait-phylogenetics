#!/usr/bin/env Rscript
# Regenerate the two synthetic documentation illustrations from public code.
# Run from the repository root; no external input paths are accepted.
if (!file.exists(file.path("scripts", "run_workflow.R"))) {
  stop("Run this command from the repository root.", call. = FALSE)
}
source(file.path("scripts", "run_workflow.R"))

gallery_dir <- file.path("docs", "figures")
dir.create(gallery_dir, recursive = TRUE, showWarnings = FALSE)
figures <- list(
  synthetic_tree.svg = c(
    "Synthetic phylogeny",
    paste("Entirely synthetic topology, branch lengths, traits and taxon identifiers.",
          "Two colours represent artificial states. No empirical inputs or study findings.")
  ),
  synthetic_workflow.svg = c(
    "Synthetic workflow outputs",
    paste("Entirely synthetic missingness, imputation evaluation, PCA and correlations.",
          "All traits and displayed estimates are simulated; no study findings are shown.")
  )
)
for (filename in names(figures)) {
  svg <- readLines(file.path(output_dir, filename), encoding = "UTF-8", warn = FALSE)
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
cat("Gallery refreshed: two synthetic SVGs in docs/figures/. Review before publication.\n")
