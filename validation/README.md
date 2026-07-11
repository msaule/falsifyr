# falsifyr validation corpus

This GitHub-only corpus exercises known robust and fragile claims without
inflating the CRAN source package or its check time. It validates product-level
behavior rather than duplicating unit tests:

- known fragile and resilient synthetic claims;
- a grouped-deletion workflow;
- a factor-coefficient claim;
- a binomial GLM claim;
- optional mixed-model and Cox claims;
- careful interpretation language for covariate dependence.

Run from the package root with:

```r
source("validation/run-validation.R")
```

The script fails on a broken contract and writes `validation/results.csv` for
the portfolio/release evidence. The generated CSV is deterministic.
