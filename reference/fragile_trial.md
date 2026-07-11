# Synthetic fragile trial data

A small trial-like data set where the treatment claim starts below
`p = 0.05` but is sensitive to row deletion, missing-data alternatives,
and measurement-error attacks. It includes deterministic missingness in
`baseline_score` to exercise missing-data attacks.

## Usage

``` r
fragile_trial
```

## Format

A data frame with 80 rows and 4 variables:

- score:

  Continuous outcome.

- treatment:

  Binary treatment indicator.

- age:

  Participant age.

- baseline_score:

  Baseline continuous score with some missing values.
