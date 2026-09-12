# Install only the dependencies used by this workflow, from CRAN.
required <- c("ape", "phytools", "missForest", "caper")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  install.packages(missing, repos = "https://cloud.r-project.org")
}
stopifnot(all(vapply(required, requireNamespace, logical(1), quietly = TRUE)))
cat("Workflow dependencies are available.\n")
