# Workflow figure notes

The [repository landing page](../README.md) embeds ten figures covering trait preparation, mapping, comparative analysis, simulation, imputation and PCA. The [accompanying website](https://superamazingmatt.github.io/coral-trait-phylogenetics/) presents the same ten views in a navigable gallery.

Every displayed value, identifier, branching pattern, and branch length is synthetic. None is mapped to the study's species or findings.

## Main-page illustrations

Three exporters generate eight PNG illustrations without reading input files:

| Figure | Construction | Interpretation |
| --- | --- | --- |
| [Circular trait map](figures/method_tree.png) | A new pure-birth tree from `phytools::pbtree`, Brownian traits from `fastBM`, and continuous branch mapping with `contMap` | Illustrates a plotting method; the topology, colours, and model parameters are independently simulated. |
| [Mixed-trait matrix](figures/method_matrix.png) | Six toy variables generated from normal draws and category sampling, displayed using `GGally::ggpairs` | Demonstrates mixed-variable plotting; any associations are invented for illustration. |
| [Distributions](figures/method_distributions.png) | Histograms and category-frequency panels for the same toy variable construction | Illustrates distribution inspection rather than a research trait's distribution. |
| [Coverage](figures/method_coverage.png) | Deliberate random gaps with arbitrary per-trait rates; a row subset and full-table coverage bars | The masking pattern and percentages are generated examples. |
| [Categorical map](figures/method_categorical_tree.png) | Brownian values divided into three states on another new simulated tree | Tip states only; internal branches do not encode ancestral-state estimates. |
| [Signal comparison](figures/method_signal.png) | λ/K fits for generated continuous traits, D fits for thresholded two-state traits | Separate panels and references respect different metric scales; no study estimates. |
| [Tree sensitivity](figures/method_tree_sensitivity.png) | Refit λ/K for fixed traits across 14 sets of perturbed branch lengths | Arbitrary branch perturbations, not posterior samples; boxes are not posterior intervals. |
| [Brownian comparison](figures/method_brownian.png) | Repeated `fastBM` generation followed by λ/K fits | A small simulation experiment, with one as the Brownian reference, not a study-trait test. |

Tree seed: 613079. Matrix and distribution seed: 61704. Coverage masking: 61705. Categorical tree: 61706. Signal construction: 61821. Branch perturbations: 61822. Brownian replicates: 61823. Sizes, coefficients, and model parameters are arbitrary illustration settings. All eight PNGs visibly state “SIMULATED METHOD ILLUSTRATION.” Trait names are generic; the matrix replaces printed association estimates with method labels, while the fitted-method figures display computed synthetic statistics.

```sh
Rscript scripts/install_dependencies.R
Rscript scripts/export_methods.R
Rscript scripts/export_trait_figures.R
Rscript scripts/export_signal_figures.R
```

Each exporter writes PNGs under `artifacts/synthetic-validation/methods/` by default and accepts one optional output-directory argument. It prints R and package versions and leaves published copies untouched. A release review compares freshly rendered PNGs with the eight copies in `docs/figures/`, checks their file structure and metadata, and inspects the images and generators. PNG structure checks alone cannot distinguish research pixels from simulated pixels.

The committed PNGs were rendered with R 4.4.0, ape 5.8, phytools 2.3.0, caper 1.0.3, GGally 2.2.1, and ggplot2 3.5.1. Graphics devices and package versions can change pixels across environments.

## Additional synthetic gallery

The presentation plots are produced by `R/gallery_plots.R`, using the existing synthetic workflow objects. The plotting code changes the visual presentation without changing the fitted analyses. Circular positioning preserves the simulated tree relationships and uses branch lengths for radial distance; angular spacing is a layout choice.

| Figure | Content | Interpretation limit |
| --- | --- | --- |
| [Phylogeny](figures/synthetic_tree.svg) | Simulated tree and artificial state colours | No empirical tree or species mapping |
| [Imputation](figures/synthetic_imputation.svg) | Held-out errors from two random forest fits | One mask does not establish predictive superiority |
| [Trait space](figures/synthetic_pca.svg) | Centred, scaled PCA scores with trait-loading direction arrows | Arrows use a shared display multiplier; they are not correlation vectors. Imputation uncertainty is not propagated. |
| [Associations](figures/synthetic_correlation.svg) | Spearman correlations | No independent-species significance tests |
| [Overview](figures/synthetic_workflow.svg) | Compact summary of the workflow | Entirely synthetic outputs |

## Reproduce the figures

From the repository root:

```sh
Rscript scripts/install_dependencies.R
Rscript scripts/export_gallery.R
```

The exporter executes the complete synthetic workflow and renders the presentation figures. Generated working outputs stay under ignored `artifacts/`. Only the five named SVG illustrations are copied into `docs/figures/`, with accessible titles and synthetic provenance descriptions. Review regenerated drawings before publication.

Use `Rscript scripts/export_gallery.R --local-only` to exercise the complete workflow and SVG rendering without updating published copies; CI uses this option. Loading arrows are the first two columns of `pca$rotation` multiplied by one positive factor for display. The numerical PCA fit and its variance summaries are unchanged by this overlay.

The committed figures were generated with R 4.4.0, ape 5.8, phytools 2.3.0, missForest 1.5, and caper 1.0.3. Seeds are specified in the public workflow: fixture 2718, masking 2719, imputation 2720, and signal 2721. Software versions and graphics devices can change exact output; per-run package versions and provenance notes are saved locally.

The website is static, with a small local script for accessible figure tabs. It has no forms, analytics, external fonts, or data services. GitHub Pages serves the reviewed `docs/` folder. The README is the main research overview and entry point for running the software.

[Methods and assumptions](METHODS.md) · [Data policy](DATA_POLICY.md) · [Project README](../README.md)
