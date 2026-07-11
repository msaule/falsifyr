# Changelog

## falsifyr 1.0.0

### First CRAN release

- Added the claim-first `attack(model, term)` engine and ranked
  smallest-kill output.
- Added row deletion (ranked, greedy, beam, and grouped), uncertainty,
  covariate, missingness, measurement-error, placebo, specification, and
  split attack families.
- Added support for `lm`, `glm`, `aov`, `lmerMod`, `glmerMod`, and
  `coxph` perturbation workflows, plus explicit limited support for
  `htest` and `anova` objects that do not retain refittable source data.
- Added deterministic fast/normal/deep/insane intensity profiles, claim
  and attack registries, and two-worker parallel family execution.
- Added survival scoring, verdicts, smallest-kill and leaderboard
  accessors, console/plot output, standalone HTML reports, and the
  RStudio addin.
- Added synthetic fragile/resilient data, vignettes, a GitHub-only
  validation corpus, and cross-platform R CMD check automation.
