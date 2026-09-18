# Workflow figure notes

**[Explore the research website](https://superamazingmatt.github.io/coral-trait-phylogenetics/)** for the redesigned figures and interactive gallery.

The website presents four individual views: a circular phylogeny, an imputation comparison, a PCA plot, and a Spearman correlation matrix. A compact overview is retained as an additional downloadable illustration. Every displayed value, identifier, branching pattern, and branch length is synthetic. None is mapped to the study's species or findings.

## Figure provenance

The presentation plots are produced by `R/gallery_plots.R`, using the existing synthetic workflow objects. The plotting code changes the visual presentation without changing the fitted analyses. Circular positioning preserves the simulated tree relationships and uses branch lengths for radial distance; angular spacing is a layout choice.

| Figure | Content | Interpretation limit |
| --- | --- | --- |
| [Phylogeny](figures/synthetic_tree.svg) | Simulated tree and artificial state colours | No empirical tree or species mapping |
| [Imputation](figures/synthetic_imputation.svg) | Held-out errors from two random forest fits | One mask does not establish predictive superiority |
| [Trait space](figures/synthetic_pca.svg) | Centred, scaled PCA of imputed continuous traits | Descriptive; imputation uncertainty is not propagated |
| [Associations](figures/synthetic_correlation.svg) | Spearman correlations | No independent-species significance tests |
| [Overview](figures/synthetic_workflow.svg) | Compact summary of the workflow | Entirely synthetic outputs |

## Reproduce the figures

From the repository root:

```sh
Rscript scripts/install_dependencies.R
Rscript scripts/export_gallery.R
```

The exporter executes the complete synthetic workflow and renders the presentation figures. Generated working outputs stay under ignored `artifacts/`. Only the five named SVG illustrations are copied into `docs/figures/`, with accessible titles and synthetic provenance descriptions. Review regenerated drawings before publication.

The committed figures were generated with R 4.4.0, ape 5.8, phytools 2.3.0, missForest 1.5, and caper 1.0.3. Seeds are specified in the public workflow: fixture 2718, masking 2719, imputation 2720, and signal 2721. Software versions and graphics devices can change exact output; per-run package versions and provenance notes are saved locally.

The website is static, with a small local script for accessible figure tabs. It has no forms, analytics, external fonts, or data services. GitHub Pages serves the reviewed `docs/` folder. The README remains the entry point for running the software.

[Methods and assumptions](METHODS.md) · [Data policy](DATA_POLICY.md) · [Project README](../README.md)
