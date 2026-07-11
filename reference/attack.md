# Attack a statistical claim

Runs a collection of adversarial robustness checks against a fitted
model claim. The returned object summarizes whether the claim survives
each attack, the smallest perturbation that kills it, and an overall
survival score.

## Usage

``` r
attack(
  model,
  term = NULL,
  data = NULL,
  outcome = NULL,
  cluster = NULL,
  profile = c("default", "clinical", "social_science", "prediction", "strict", "fast"),
  attacks = NULL,
  intensity = c("normal", "fast", "deep", "insane"),
  alpha = 0.05,
  alternative = c("two.sided", "less", "greater"),
  kill_rule = c("p_over_alpha", "ci_crosses_zero", "sign_flip", "effect_below_threshold"),
  effect_threshold = NULL,
  seed = 1,
  parallel = FALSE,
  verbose = TRUE
)
```

## Arguments

- model:

  A fitted `lm`, `glm`, `aov`,
  [`lme4::lmer`](https://rdrr.io/pkg/lme4/man/lmer.html),
  [`lme4::glmer`](https://rdrr.io/pkg/lme4/man/glmer.html), or
  [`survival::coxph`](https://rdrr.io/pkg/survival/man/coxph.html)
  model. `htest` objects return an explicit limited-support result.

- term:

  Character scalar naming the coefficient or test term to attack. If
  `NULL`, falsifyr attacks the first non-intercept coefficient.

- data:

  Optional data frame used to refit the model. When omitted, falsifyr
  attempts to recover the model data.

- outcome:

  Optional character vector of user-supplied placebo outcome names for
  the placebo attack family.

- cluster:

  Optional character scalar naming a grouping variable for a grouped
  row-deletion attack. Supply `data` when the grouping variable is not
  part of the fitted formula.

- profile:

  Character scalar choosing an attack profile. Profiles tune the default
  attack-family emphasis when `attacks = NULL`; `profile = "fast"` also
  defaults to `intensity = "fast"` when intensity is not supplied.

- attacks:

  Character vector of attack families. `NULL` runs the default families.

- intensity:

  Character scalar controlling attack breadth: `"fast"`, `"normal"`,
  `"deep"`, or `"insane"`.

- alpha:

  Significance level used by kill rules.

- alternative:

  Character scalar defining the claim direction for coefficient tests:
  `"two.sided"`, `"less"`, or `"greater"`.

- kill_rule:

  Character scalar defining what kills a claim. Supported rules are
  `"p_over_alpha"`, `"ci_crosses_zero"`, `"sign_flip"`, and
  `"effect_below_threshold"`.

- effect_threshold:

  Numeric threshold used by `"effect_below_threshold"`.

- seed:

  Integer seed for deterministic attack runs.

- parallel:

  Logical; if `TRUE`, independent attack families run on at most two
  local workers.

- verbose:

  Logical; if `TRUE`, prints progress messages for expensive `"insane"`
  attack runs.

## Value

A `falsifyr_attack` object with the extracted claim, attack leaderboard,
smallest kill, survival score, verdict, runtime metadata, and warnings.

## Examples

``` r
fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
result <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")
result
#> 
#> -- FALSIFYR ATTACK -------------------------------------------------------------
#> Claim
#> treatment -> score
#> formula: score ~ treatment + age + baseline_score
#> estimate: 0.443
#> p-value: 0.041
#> confidence interval: [0.0251, 0.861]
#> 
#> Verdict
#> MIXED | survival score: 47/100
#> 
#> Smallest kill
#> Influential row deletion: remove 1 row -> p = 0.069
#> Rows: 43
#> Method: ranked
#> 
#> Weakest assumptions
#> 1. Row deletion / influence: remove 1 row -> p = 0.069
#> 
#> Died under
#> Influential row deletion
#> 
#> Survived
#> none
#> 
#> A killed claim is fragile under an attack; that does not prove it is false.
#> Use plot(x) for survival map.
#> Use report(x, "attack.html") for full report.
```
