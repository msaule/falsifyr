# Interpreting Survival Scores

The survival score is a communication device, not a formal probability
that a claim is true. It summarizes how easily the named claim died
under the attacks that were run.

``` r
library(falsifyr)

fragile_fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
resilient_fit <- lm(score ~ treatment + age + baseline_score, data = resilient_trial)

fragile <- attack(
  fragile_fit,
  term = "treatment",
  attacks = "row_deletion",
  intensity = "fast",
  seed = 1
)
resilient <- attack(
  resilient_fit,
  term = "treatment",
  attacks = "row_deletion",
  intensity = "fast",
  seed = 1
)

data.frame(
  dataset = c("fragile_trial", "resilient_trial"),
  score = c(fragile$survival_score, resilient$survival_score),
  verdict = c(fragile$verdict, resilient$verdict)
)
#>           dataset score   verdict
#> 1   fragile_trial    47     MIXED
#> 2 resilient_trial   100 RESILIENT
```

Use the verdict as a guide for reading the report:

- `RESILIENT`: the claim survived the attacks that were run.
- `STABLE`: the claim looks mostly steady, with some movement.
- `MIXED`: some attacks matter, but the claim is not collapsing
  everywhere.
- `FRAGILE`: a small or plausible perturbation can kill the claim.
- `COLLAPSES`: the claim dies under multiple or very small
  perturbations.
- `UNTESTED`: the object supports claim extraction, but not enough
  retained data are available for perturbation attacks.

The safest interpretation is always attack-specific: a row-deletion
kill, missing-data kill, or measurement-error kill tells you which
assumption the claim depends on. It does not prove the result is false.
