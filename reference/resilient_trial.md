# Synthetic resilient trial data

A small trial-like data set with a stronger treatment effect intended to
survive simple falsifyr attack families such as row deletion, robust
uncertainty checks, and drop-one covariate attacks.

## Usage

``` r
resilient_trial
```

## Format

A data frame with 120 rows and 4 variables:

- score:

  Continuous outcome.

- treatment:

  Binary treatment indicator.

- age:

  Participant age.

- baseline_score:

  Baseline continuous score.
