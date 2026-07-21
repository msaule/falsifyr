# falsifyr: Chaos Monkey for Statistical Claims

## Portfolio summary

I built `falsifyr`, a CRAN-native R package and RStudio addin that turns a fitted
statistical result into an adversarial robustness test. The user supplies one
model and one target term. The engine searches for the smallest plausible
perturbation that changes the conclusion, then returns a ranked attack
leaderboard, survival score, plot, and standalone report.

The memorable workflow is deliberately small:

```r
fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
attack(fit, term = "treatment")
```

## What I engineered

The engine coordinates row/influence deletion, grouped deletion, robust and
bootstrap uncertainty, covariate dependence, missing-data alternatives,
measurement noise, label permutation and fake-predictor placebos, bounded
specification changes, and split stability. Fast, normal, deep, and insane
profiles trade runtime for search breadth; expensive families can run on two
deterministic workers.

The package supports ordinary linear and generalized models, ANOVA fits, mixed
models, and Cox proportional-hazards models. It also extracts claims from
hypothesis tests and ANOVA tables while clearly reporting that those objects do
not retain enough source information for automatic perturbation refits.

## Validation evidence

The deterministic validation corpus currently records:

| Scenario | Score | Verdict | Expected behavior |
|---|---:|---|---|
| Known fragile linear claim | 29 | FRAGILE | Killed by influential-row deletion |
| Known resilient linear claim | 100 | RESILIENT | No tested attack kills the claim |
| Grouped-deletion workflow | 19 | COLLAPSES | Group-aware path executes and reports units |
| Factor coefficient | 100 | RESILIENT | Factor level maps back to its source variable |
| Binomial GLM | 100 | RESILIENT | Claim extraction and attacks execute |
| Linear mixed model | 100 | RESILIENT | Optional mixed-model refits execute |
| Cox model | 19 | COLLAPSES | Survival claim and row refits execute |

These scores are validation fixtures, not scientific calibration claims. The
package repeatedly states that a killed result is fragile under an attack, not
proven false.

## Product differentiation

Existing tools help define multiverses, diagnose fitted models, compute robust
covariances, or study a specific sensitivity mechanism. `falsifyr` starts from
one fitted claim, attacks it across multiple bounded families, and makes the
smallest kill the headline. That keeps the package out of generic diagnostics
and user-authored multiverse territory.

## Release engineering

The package uses optional dependencies conditionally, avoids network access and
external services at runtime, writes report examples only to temporary paths,
caps parallelism for CRAN, and ships deterministic examples/tests. The final
source package passed `R CMD check --as-cran` under R 4.6.1 with zero errors,
zero warnings, and the expected new-submission note. GitHub Actions also passed
on Windows release, macOS release, Ubuntu release, and Ubuntu R-devel. The test
suite reaches 82.3% measured coverage, and the release process builds the
vignettes, PDF manual, pkgdown site, and source tarball.

Version 1.0.0 entered CRAN review on July 11, 2026 UTC. CRAN requested method
references, explicit dataset value documentation, removal of a default report
path, and removal of fixed seeds from runtime dataset generation. Those items
were corrected at their source, the datasets were converted to standard static
package data, and the package again passed `R CMD check --as-cran` with zero
errors and zero warnings. The corrected 58,969-byte archive was resubmitted on
July 21, 2026 UTC and is awaiting maintainer email confirmation. Its SHA-256 is
`7FFA8F987E363FFF2D6408854C4F41FDB2107E05AFF545FF438A402DB6A84372`.
