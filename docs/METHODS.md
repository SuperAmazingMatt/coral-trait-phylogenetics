# Methods and assumptions

The distributed workflow is a compact implementation of the research methods. Its defaults are for automated execution checks and reproducible examples. They are not the settings or findings of the withheld empirical analysis.

## Inputs and alignment

A fixed seed generates a coalescent tree using `ape::rcoal`. Branch lengths are scaled to unit tree height. Continuous examples combine Brownian simulations and independent noise; a binary example uses artificial states. The generator does not read a research table or tree.

The table contains a unique `taxon_id`, three numeric variables (`Trait_A`, `Trait_B`, `Trait_C`), and one two-level factor (`State_A`). Validation rejects duplicate IDs, invalid types, inadequate observations, non-finite values, and unsuitable branch lengths. The tree must be rooted and binary. Tree and table must have exactly the same taxon set; the table is explicitly reordered to the tip order. No mismatch is silently discarded.

## Missing-data evaluation

Known synthetic cells are masked before fitting. Binary masking is stratified to retain observations in both classes. The example uses a single random mask and cannot establish which imputation strategy is preferable in real data. Real missingness can depend on traits or sampling history, which random masking does not reproduce.

Two `missForest` fits use the same masked traits and random seed:

1. Random forest imputation using the trait columns alone.
2. Random forest imputation with three additional tree-derived predictors.

The tree predictors are scaled eigenvectors of centred shared-branch correlation. They are constructed from the tree alone, without access to held-out trait values. This is an explicit phylogenetic eigenvector construction; it is not a claim to reproduce every setting of a historical PVR analysis.

Observed cells must remain unchanged. Evaluation uses only deliberately masked cells: continuous error is RMSE divided by the standard deviation of training observations, and binary error is the misclassification proportion. These held-out errors are separate from the package's internal out-of-bag estimates. The current example imputes missing cells among known taxa; it does not validate prediction for entirely unseen species. See the [missForest manual](https://cran.r-project.org/web/packages/missForest/missForest.pdf) for its mixed-variable imputation algorithm.

## Phylogenetic signal

Signal is estimated from the remaining observed entries, separately for each trait. Each analysis prunes the synthetic tree to the available observations and realigns names. Imputed values do not enter these tests.

- Continuous traits: `phytools::phylosig` estimates Pagel's lambda with a likelihood-ratio test and Blomberg's K with randomization. Lambda describes covariance structure under the fitted model; K compares trait variation with Brownian expectations. Neither statistic is an effect of a specific biological mechanism. See the [phytools manual](https://cran.r-project.org/web/packages/phytools/phytools.pdf).
- Binary state: `caper::phylo.d` estimates D and compares it with random and Brownian-threshold reference distributions. D is scaled around these reference models rather than restricted to a probability interval. See the [caper manual](https://cran.r-project.org/web/packages/caper/caper.pdf).

The default uses 99 simulations to keep execution checks short. Monte Carlo probabilities are consequently coarse, and lambda test probabilities use an asymptotic approximation. Empirical inference requires justified simulation effort, model checks, consideration of multiple testing, and sensitivity to tree and data uncertainty. No probability or estimate generated here is a research finding.

## Multivariate exploration

The workflow applies centred, scaled PCA and Spearman correlations to the continuous columns completed by the model that includes tree predictors. These summaries are descriptive. Ordinary PCA does not adjust for phylogenetic covariance, and the workflow does not conduct independent-species significance tests on the correlations. A single imputed table does not propagate imputation uncertainty.

## Outputs and reproducibility

The example produces two SVG figures, synthetic evaluation and signal summaries, PCA variance fractions, package versions, and a provenance note under ignored `artifacts/synthetic-validation/`. It does not export the complete input table or tree. Every figure states that it is synthetic, including its topology and branch lengths.

The [workflow gallery](workflow-outputs.md) publishes reviewed copies of the two synthetic figures. `scripts/export_gallery.R` regenerates them from the workflow and adds accessible provenance descriptions. Empirical figures and generated numerical tables are excluded from publication.

The automated checks exercise fixture reproducibility, name alignment, rejected invalid inputs, preservation of observed data, and downstream analysis. The end-to-end run additionally exercises plotting and output writing. Package and R versions are recorded without local paths, usernames, or machine details. Seeds do not guarantee identical results across package or platform changes.

The core packages are [ape](https://cran.r-project.org/package=ape), [phytools](https://cran.r-project.org/package=phytools), [missForest](https://cran.r-project.org/package=missForest), and [caper](https://cran.r-project.org/package=caper). Use `citation("package-name")` in the environment used for an analysis to retrieve its software citation.
