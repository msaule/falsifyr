# falsifyr

`falsifyr` is Chaos Monkey for statistical claims. Give it one fitted result
and one term; it searches for the smallest plausible perturbation that changes
the conclusion.

> What would it take to kill this result?

```r
library(falsifyr)

fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
result <- attack(fit, term = "treatment")

result
plot(result)
smallest_kill(result)
```

The headline is the smallest kill, not a generic model-diagnostics dashboard.
A killed claim is fragile under the named attack; it is not proof that the
claim is false or that the perturbed analysis is preferable.

## Installation

The development release is available from GitHub:

```r
pak::pak("msaule/falsifyr")
```

## Attack engine

The 1.0 engine searches across:

- influence-ranked, greedy, beam, and grouped row deletion;
- bootstrap uncertainty and optional HC0-HC3 robust standard errors;
- drop-one covariate dependence and bounded specification changes;
- mean, median, factor/mode, and missingness-indicator alternatives;
- outcome/predictor noise and binary label flips;
- label permutation, fake predictors, and supplied placebo outcomes;
- random and stratified split stability.

`intensity = "fast"`, `"normal"`, `"deep"`, or `"insane"` controls search
breadth. `parallel = TRUE` runs independent attack families on at most two
workers. All stochastic attacks are deterministic for a fixed `seed`.

Grouped deletion is enabled when observations belong to meaningful units:

```r
attack(
  fit,
  term = "treatment",
  data = trial_data,
  cluster = "site",
  attacks = "row_deletion"
)
```

## Model support

| Model object | Claim extraction | Perturbation refits |
|---|---:|---:|
| `lm`, `glm`, `aov` | yes | yes |
| `lme4::lmer`, `lme4::glmer` | yes | yes, when `lme4` is installed |
| `survival::coxph` | yes | yes, when `survival` is installed |
| `t.test`, `wilcox.test`, `cor.test` (`htest`) | yes | limited: source data are not retained |
| `anova` tables | yes | limited: fitted model is not retained |

For `lmerMod` objects, coefficient p-values use an explicitly labeled Wald
normal approximation when the fitted model does not provide p-values.

When `broom` is installed, `broom::tidy(result)` returns the attack leaderboard
and `broom::glance(result)` returns a one-row claim and verdict summary.

## Reports and addin

```r
attack_leaderboard(result)
report(result, file = tempfile(fileext = ".html"))
```

The standalone HTML report contains the claim card, score, smallest kill,
ranked attacks, family details, fragility curves, limitations, and a
reproducibility appendix. In RStudio, **Addins -> Attack This Claim** provides
model, term, intensity, alpha, and attack-family controls and opens the report
in the Viewer.

## Validation

The CRAN package includes fast deterministic unit tests and vignettes. A larger
GitHub-only corpus in `validation/` checks known fragile/resilient claims,
grouped deletion, factor terms, GLMs, mixed models, Cox models, score ordering,
and interpretation language.

The survival score is a heuristic communication device, not a probability that
the claim is true. Read every verdict together with the attacks that were run
and the report's limitations.

## Design wedge

Existing tools help define, diagnose, or run robustness analyses. `falsifyr`
automatically attacks a fitted claim and searches for the smallest plausible
perturbation that changes the conclusion.
