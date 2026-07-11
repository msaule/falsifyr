# FALSIFYR

## Chaos Monkey for Statistical Claims

### CRAN / RStudio Addin Engineering Specification — v0.1 to v1.0

> **Working package name:** `falsifyr`  
> **Core action:** `attack(model, term = "treatment")`  
> **One-line pitch:** `falsifyr` takes a fitted R model or test result,
> automatically attacks the statistical claim with plausible alternative
> assumptions, and tells you the smallest reasonable change that would
> make the claim disappear.

------------------------------------------------------------------------

## 0. Why this exists

Most statistical tools help you confirm, diagnose, report, or visualize
a model.

`falsifyr` does the opposite.

It asks:

> **What would it take to kill this result?**

A normal R workflow often ends with something like:

``` r
model <- lm(score ~ treatment + age + baseline_score, data = df)
summary(model)
```

The analyst sees:

``` text
treatment estimate = 0.42
p = 0.018
```

That looks publishable, reportable, or at least exciting.

But the real question is not merely whether the p-value is below 0.05.
The real question is:

- Does the claim survive robust standard errors?
- Does it survive bootstrap resampling?
- Does it survive removing influential rows?
- Does it survive small measurement error?
- Does it survive reasonable missing-data alternatives?
- Does it survive plausible covariate changes?
- Does it survive placebo outcomes or fake treatment labels?
- Does it survive alternate train/test splits?
- What is the **smallest plausible perturbation** that makes it die?

`falsifyr` turns that into one command:

``` r
library(falsifyr)

fit <- lm(score ~ treatment + age + baseline_score, data = df)

attack(fit, term = "treatment")
```

Example output:

``` text
FALSIFYR CLAIM ATTACK REPORT

Claim:
  treatment -> score

Original:
  estimate = 0.42
  p = 0.018

Survival:
  38 / 100  (FRAGILE)

Smallest kill:
  Remove 3 influential rows -> p = 0.091

Most lethal assumption:
  Complete-case missingness.
  Median imputation changes p = 0.018 -> p = 0.073.

Attack summary:
  ✅ survives bootstrap resampling
  ✅ survives HC3 robust standard errors
  ⚠ dies when baseline_score is removed
  ⚠ dies under 2.5% outcome noise
  ❌ dies under median imputation
  ❌ placebo outcome produces similarly strong effects in 13% of simulations

Verdict:
  The claim exists only under a narrow analytical path.
```

This should feel less like a linter and more like a controlled
demolition system for statistical claims.

------------------------------------------------------------------------

## 1. Product identity

### 1.1 The phrase

`falsifyr` is:

> **Chaos Monkey for statistical claims.**

In software engineering, chaos testing deliberately breaks systems to
see whether they are resilient. `falsifyr` deliberately perturbs
assumptions, rows, covariates, standard errors, missing-data rules, and
labels to see whether an R claim survives.

### 1.2 What it is not

`falsifyr` is **not**:

- a general model diagnostics package;
- a multiverse analysis authoring framework;
- a p-hacking detector;
- a fraud detector;
- a replacement for subject-matter expertise;
- a causal-inference identification checker;
- an automatic referee that declares results true or false;
- a package that requires a user to hand-declare every robustness
  specification.

### 1.3 The wedge

The wedge is not “robustness checks.” That already exists conceptually.

The wedge is:

> **Given a fitted object and a term/claim, automatically search for the
> smallest plausible attack that makes the claim disappear.**

Existing tools usually ask the analyst to say:

``` text
Here are the alternative specs I want to run.
```

`falsifyr` says:

``` text
Give me the final model. I will attack it.
```

------------------------------------------------------------------------

## 2. Competitive landscape and differentiation

This package must be built with the adjacent ecosystem in mind. If it
becomes “a robustness analysis package,” it is not special enough. The
spec below deliberately positions `falsifyr` around automated
adversarial search over claims, not around user-authored multiverse
analysis or one narrow sensitivity method.

| Adjacent package / area | What it does | Why it does not kill `falsifyr` |
|----|----|----|
| `specr` | Conducts and visualizes specification curve / multiverse analyses. The CRAN page describes utilities to set up, run, evaluate, and plot all specifications. | User defines the specification grid. `falsifyr` should infer attack surfaces from a fitted object and search for the smallest kill. |
| `multiverse` | Lets users declare alternate analysis branches in R/R Notebooks to show robustness or fragility. | Strong conceptual neighbor, but user-authored. `falsifyr` is model-first and adversarial. |
| `sensemakr` | Sensitivity analysis for omitted-variable bias in regression models. | Very strong, but focused on omitted confounding in regression. `falsifyr` should include row, missingness, SE, placebo, specification, split, and outcome/treatment perturbation attacks. |
| `tipr` | Tipping-point analysis for how an unmeasured confounder may tip a result to insignificance. | Close philosophically, but narrower. `falsifyr` generalizes the “tipping point” idea across many assumption classes. |
| `influence.ME` | Detects influential cases in generalized mixed-effects models, including changing significance when units are omitted. | Important row/group influence precedent, but only one attack family and model class. |
| `performance` | Provides model-quality assessment and diagnostic functions across regression models. | Diagnostics are not the same as adversarial survival search. |
| `robustbase`, robust regression, sandwich/HC estimators | Provide robust estimators and standard errors. | `falsifyr` can call or implement some of these attacks, but its value is orchestration, kill-search, and claim-level reporting. |

### Key differentiation sentence

> `falsifyr` is not a place to declare every possible analysis. It is a
> tool that looks at the result you already believe and asks, “What is
> the weakest assumption holding this up?”

------------------------------------------------------------------------

## 3. The minimum viable magic

The MVP should not be huge.

The MVP must do one thing so well that a demo lands in 30 seconds:

``` r
fit <- lm(score ~ treatment + age + baseline_score, data = trial)
attack(fit, term = "treatment")
```

It should return:

1.  Original claim estimate, standard error, statistic, p-value,
    confidence interval.
2.  A set of attacks.
3.  A ranked list of attacks by “kill distance.”
4.  The smallest kill.
5.  A survival score.
6.  A concise console report.
7.  A plot.
8.  An optional RStudio Addin report.

If the MVP cannot produce a dramatic “smallest kill” on
[`lm()`](https://rdrr.io/r/stats/lm.html) and
[`glm()`](https://rdrr.io/r/stats/glm.html), nothing else matters.

------------------------------------------------------------------------

## 4. Core user stories

### 4.1 Student / analyst

> “I ran a regression for a class/project/report. I want to know if my
> significant result is fragile before I submit it.”

Workflow:

``` r
fit <- lm(outcome ~ treatment + x1 + x2, data = df)
attack(fit, term = "treatment")
```

Value:

- Learns which assumptions matter.
- Gets an intuitive robustness explanation.
- Does not need deep sensitivity-analysis knowledge.

### 4.2 Research assistant / biostatistics analyst

> “I need to stress-test an observational result before sending it to a
> PI.”

Workflow:

``` r
fit <- glm(readmission ~ intervention + age + sex + comorbidity,
           data = hospital,
           family = binomial())

attack(fit, term = "intervention", profile = "clinical")
```

Value:

- Shows omitted/covariate fragility.
- Tests missingness and robust SE choices.
- Finds influential hospitals/patients if grouped data are provided.

### 4.3 Reviewer / collaborator

> “Someone sent me a model result. I do not want to accuse them of
> anything; I want to know what would make the result fail.”

Workflow:

``` r
attack(fit, term = "exposure", intensity = "normal")
report(result, "claim_attack.html")
```

Value:

- Non-accusatory language.
- Evidence-linked claim fragility.
- Clear “survives/dies” table.

### 4.4 Portfolio/demo

> “Show an RStudio Addin that turns a boring regression into a dramatic
> claim survival report.”

Workflow:

- Fit model in RStudio.
- Highlight `fit` or select from environment.
- Addins → **Attack This Claim**
- Choose term.
- Viewer opens survival report.

------------------------------------------------------------------------

## 5. Main API

### 5.1 Core function

``` r
attack <- function(
  model,
  term = NULL,
  data = NULL,
  outcome = NULL,
  profile = c("default", "clinical", "social_science", "prediction", "strict", "fast"),
  attacks = NULL,
  intensity = c("fast", "normal", "deep", "insane"),
  alpha = 0.05,
  alternative = c("two.sided", "less", "greater"),
  kill_rule = c("p_over_alpha", "ci_crosses_zero", "sign_flip", "effect_below_threshold"),
  effect_threshold = NULL,
  seed = 1,
  parallel = FALSE,
  verbose = TRUE
)
```

### 5.2 Returned object

Return an S3 object of class:

``` r
class(result)
# c("falsifyr_attack", "list")
```

Structure:

``` r
result <- list(
  claim = list(
    model_class = "lm",
    formula = score ~ treatment + age + baseline_score,
    outcome = "score",
    term = "treatment",
    estimate = 0.42,
    std_error = 0.16,
    statistic = 2.56,
    p_value = 0.018,
    conf_low = 0.10,
    conf_high = 0.74,
    alpha = 0.05,
    kill_rule = "p_over_alpha"
  ),
  attacks = tibble::tibble(
    attack_id,
    attack_family,
    attack_name,
    status,
    killed,
    estimate,
    p_value,
    delta_p,
    delta_estimate,
    kill_distance,
    severity,
    explanation,
    payload
  ),
  smallest_kill = list(...),
  survival_score = 38,
  verdict = "FRAGILE",
  runtime = list(...),
  warnings = list(...)
)
```

### 5.3 Print method

``` r
print.falsifyr_attack <- function(x, ...) {
  # Use cli for attractive console output.
}
```

Example:

``` text
══ FALSIFYR ATTACK ═════════════════════════════════════

Claim
  term: treatment
  estimate: 0.42
  p-value: 0.018

Verdict
  FRAGILE  |  survival score: 38/100

Smallest kill
  Row deletion attack:
  remove 3 rows -> p = 0.091

Weakest assumptions
  1. Missing-data rule
  2. Dependence on baseline_score
  3. Influential observations

Use plot(x) for survival map.
Use report(x, "attack.html") for full report.
```

### 5.4 Plot method

``` r
plot(result)
```

Plot ideas:

- survival bar;
- attack family heatmap;
- p-value distribution across attacks;
- “smallest kill” staircase;
- perturbation curve for measurement error;
- covariate-dependency tornado plot;
- row-deletion fragility curve.

### 5.5 Report method

``` r
report(result, file = "falsifyr_report.html")
```

Report sections:

1.  Claim card.
2.  Survival score.
3.  Smallest kill.
4.  Attack leaderboard.
5.  Family-by-family details.
6.  Model/data limitations.
7.  Reproducibility appendix: package versions, seed, call, runtime,
    attack settings.

------------------------------------------------------------------------

## 6. Core concepts

### 6.1 Claim

A claim is not a whole model. A claim is a specific estimand/result
extracted from a model or test.

Examples:

- coefficient for `treatment` in `lm`;
- odds ratio for `intervention` in `glm(family = binomial)`;
- difference in means from `t.test`;
- hazard ratio term in `coxph`;
- AUC or RMSE difference for predictive model later.

Claim fields:

``` r
claim <- list(
  estimand_type = "coefficient",
  term = "treatment",
  direction = "positive",
  estimate = 0.42,
  uncertainty = "std_error",
  p_value = 0.018,
  alpha = 0.05,
  kill_rule = "p_over_alpha"
)
```

### 6.2 Attack

An attack is a controlled perturbation that changes one assumption, data
subset, estimator, SE method, or validation choice.

An attack must be:

- reproducible;
- labeled;
- explainable;
- bounded by plausibility settings;
- able to return a comparable claim.

### 6.3 Kill

A kill occurs when the perturbed claim fails the chosen rule.

Default kill rule:

``` r
p_value > alpha
```

Other kill rules:

- confidence interval crosses zero;
- sign flips;
- effect size below practical threshold;
- prediction metric falls below threshold;
- clinical/practical conclusion changes.

### 6.4 Kill distance

The smaller the perturbation needed to kill the claim, the more fragile
the claim.

Examples:

- row deletion kill distance = number/proportion of rows removed;
- noise kill distance = noise SD relative to outcome SD;
- missingness kill distance = imputation method severity;
- covariate kill distance = one-covariate removal/addition;
- placebo kill distance = frequency of placebo claims as strong as
  original.

### 6.5 Survival score

A rough 0–100 score summarizing claim robustness.

Do not pretend it is a universal scientific truth. It is a communication
device.

Possible formula:

``` text
survival_score =
  100
  - weighted_penalty(smallest_kill)
  - weighted_penalty(number_of_attack_families_that_kill)
  - weighted_penalty(placebo_rate)
  + bonus(consistency_across_robust_methods)
```

Verdicts:

|  Score | Verdict   |
|-------:|-----------|
| 80–100 | RESILIENT |
|  60–79 | STABLE    |
|  40–59 | MIXED     |
|  20–39 | FRAGILE   |
|   0–19 | COLLAPSES |

Every report must say:

> The survival score is a heuristic summary, not a formal probability
> that the claim is true.

------------------------------------------------------------------------

## 7. Attack families

### Family A — Standard-error attacks

Purpose: determine whether the claim depends on a fragile uncertainty
estimator.

Initial attacks for `lm`/`glm`:

1.  Classical SE vs HC0/HC1/HC2/HC3 robust SE.
2.  Cluster-robust SE later, if cluster variable supplied.
3.  Bootstrap CI/p-value approximation.
4.  Permutation test for simple treatment/exposure claims.

Example output:

``` text
HC3 robust SE:
  p = 0.018 -> 0.061
  killed: yes
  explanation: The claim depends on classical homoskedastic SEs.
```

Implementation options:

- base `stats`;
- optional `sandwich` and `lmtest` in Suggests or Imports;
- bootstrap can be implemented internally.

MVP: implement classical + bootstrap internally; optionally support
`sandwich` if installed.

### Family B — Row-deletion / influence attacks

Purpose: find the smallest set of observations whose removal kills the
claim.

Levels:

1.  Single-row deletion scan.
2.  Greedy k-row deletion.
3.  Influence-ranked deletion by Cook’s distance / leverage / DFBETAs.
4.  Group deletion if a cluster/group variable is supplied.

MVP algorithm:

``` text
1. Fit original model.
2. Compute influence measures where possible.
3. Rank rows by absolute influence on target term.
4. Iteratively remove top k rows.
5. Refit model and extract claim after each k.
6. Stop when kill rule triggers or max deletion reached.
```

Defaults:

``` r
max_remove_prop = 0.05
max_remove_n = min(20, floor(0.05 * n))
```

Output:

``` text
Smallest kill: remove 3 rows.
Rows: 18, 44, 102.
These rows have high leverage and all favor the claimed direction.
```

Important safety wording:

- “These rows are influential” not “these rows should be removed.”
- “Smallest kill under this attack” not “proof result is invalid.”

### Family C — Covariate-dependence attacks

Purpose: identify whether a claim exists only under a narrow covariate
set.

Attacks:

1.  Drop-one-covariate analysis.
2.  Add-one-covariate analysis from supplied candidate variables.
3.  Swap transformations: raw/log/standardized for numeric covariates.
4.  Interaction toggle for obvious treatment × subgroup interactions
    later.

MVP:

``` r
attack(fit, term = "treatment", covariates = "drop_one")
```

Output:

``` text
Claim dies when baseline_score is removed:
  p = 0.018 -> 0.142

Interpretation:
  The result is highly dependent on adjustment for baseline_score.
```

Need careful interpretation. Covariate dependence is not inherently bad.
In many causal designs, adjustment is correct. The package should say:

> This attack tests dependence, not correctness. A claim can
> legitimately depend on a theoretically necessary covariate.

### Family D — Missing-data attacks

Purpose: determine whether the claim depends on one missing-data
handling choice.

Attacks:

1.  Complete-case vs mean imputation.
2.  Complete-case vs median imputation.
3.  Missingness indicator for predictors.
4.  Simple regression imputation later.
5.  Multiple imputation later, likely out of MVP due complexity.

MVP constraints:

- numeric predictors only for mean/median impute;
- factors imputed with mode or explicit `"(Missing)"`;
- outcome missingness not imputed by default.

Output:

``` text
Missing-data attack:
  complete case p = 0.018
  median imputation p = 0.073
  killed: yes

Missingness imbalance:
  controls removed: 18%
  treated removed: 4%
```

### Family E — Measurement-error / noise attacks

Purpose: determine how small measurement perturbations can kill the
claim.

Attacks:

1.  Add Gaussian noise to outcome.
2.  Add Gaussian noise to key numeric covariates.
3.  Misclassification flip for binary treatment/exposure.
4.  Label noise for factor predictors later.

Method:

- For each noise level, simulate B replicates.
- Refit model.
- Estimate kill probability at each noise level.
- Find smallest noise level where kill probability exceeds threshold.

Example:

``` text
Outcome noise attack:
  Claim dies in 50% of simulations at noise SD = 0.13 * SD(outcome).
```

This can be dramatic and intuitive.

### Family F — Placebo attacks

Purpose: detect whether similarly strong claims appear where they should
not.

Attacks:

1.  Permute treatment labels.
2.  Use placebo outcomes supplied by user.
3.  Use future/past outcomes if supplied.
4.  Random fake predictor with same distribution.

Output:

``` text
Placebo attack:
  13% of permuted treatment labels produced p-values as small as original.
  interpretation: This weakens confidence in the claim.
```

Important: placebos are context-dependent. Default should include label
permutation when statistically appropriate, but placebo outcomes require
user input.

### Family G — Specification attacks

Purpose: generate plausible model variations and see how often the claim
survives.

This is the family closest to multiverse/specification-curve analysis,
so be careful. `falsifyr` should not become `specr`.

MVP:

- Only simple formula variations:
  - drop-one covariate;
  - add candidate covariates;
  - alternate transforms for numeric variables;
  - robust vs classical SE;
  - no huge combinatorial explosion by default.

Output:

``` text
Specification attack:
  Claim survives 8 / 47 plausible specifications.
  Median p-value across specifications: 0.064.
```

`specr`-style plot can be optional, but the headline should be
“survival” and “smallest kill.”

### Family H — Prediction split attacks

For predictive models later.

Attacks:

1.  random train/test split;
2.  stratified split;
3.  grouped split;
4.  temporal split;
5.  leakage suspicion if performance collapses under grouped/temporal
    split.

This family is not MVP unless supporting predictive/tidymodels
workflows.

------------------------------------------------------------------------

## 8. Model support plan

### v0.1 MVP

Support:

- `lm`
- `glm` with gaussian/binomial
- `htest` objects from:
  - `t.test`
  - `wilcox.test`
  - `cor.test`

Minimum feature set:

- Extract claim.
- Refit model after perturbations.
- Attack row deletion, robust/bootstrapped SE, covariate drop-one,
  missingness simple, noise, placebo permutation.
- Print and plot.

### v0.2

Support:

- `aov`
- `anova`
- more `glm` families
- grouped row deletion
- RStudio Addin
- static HTML report

### v0.3

Support:

- [`lme4::lmer`](https://rdrr.io/pkg/lme4/man/lmer.html) / `glmer` if
  installed
- [`survival::coxph`](https://rdrr.io/pkg/survival/man/coxph.html)
- `broom` integration if installed
- more polished report

### v1.0

Support:

- `lm`, `glm`, `htest`, `aov`, `lmerMod`, `glmerMod`, `coxph`
- claim extraction registry
- attack registry
- Shiny/RStudio report
- pkgdown site
- CRAN submission
- validation corpus

------------------------------------------------------------------------

## 9. Package architecture

### 9.1 Repository structure

``` text
falsifyr/
├── DESCRIPTION
├── NAMESPACE
├── LICENSE
├── R/
│   ├── attack.R                  # main attack() entry point
│   ├── claim.R                   # claim extraction generics
│   ├── refit.R                   # safe model refitting helpers
│   ├── kill-rules.R              # p/CI/sign/effect threshold kill rules
│   ├── scoring.R                 # survival score + verdicts
│   ├── print.R                   # S3 print methods
│   ├── plot.R                    # S3 plot methods
│   ├── report.R                  # HTML report
│   ├── registry.R                # attack registry and model support registry
│   ├── attacks/
│   │   ├── se-robust.R
│   │   ├── row-deletion.R
│   │   ├── covariate-drop.R
│   │   ├── missingness.R
│   │   ├── measurement-error.R
│   │   ├── placebo.R
│   │   └── specification.R
│   ├── extract/
│   │   ├── extract-lm.R
│   │   ├── extract-glm.R
│   │   ├── extract-htest.R
│   │   └── extract-default.R
│   ├── addin.R                   # RStudio Addin later
│   └── utils.R
├── inst/
│   ├── rstudio/addins.dcf
│   └── extdata/
│       ├── fragile_trial.csv
│       └── resilient_trial.csv
├── tests/
│   ├── testthat.R
│   └── testthat/
│       ├── test-claim-extraction.R
│       ├── test-row-deletion.R
│       ├── test-covariate-attacks.R
│       ├── test-missingness.R
│       ├── test-noise.R
│       ├── test-placebo.R
│       ├── test-scoring.R
│       └── test-report.R
├── vignettes/
│   ├── falsifyr.Rmd
│   ├── attacking-a-regression-claim.Rmd
│   └── interpreting-survival-scores.Rmd
├── man/
├── README.md
├── NEWS.md
└── .github/workflows/R-CMD-check.yaml
```

### 9.2 S3 generics

``` r
extract_claim <- function(model, term = NULL, ...) {
  UseMethod("extract_claim")
}

refit_model <- function(model, data, formula = NULL, ...) {
  UseMethod("refit_model")
}

run_attack <- function(attack, claim, model, data, ...) {
  UseMethod("run_attack")
}
```

### 9.3 Model refitting

A core challenge is robustly refitting the original model after
perturbing data.

For `lm` and `glm`, capture:

``` r
call <- model$call
formula <- formula(model)
family <- family(model) # for glm
model_frame <- model.frame(model)
```

Refit strategy:

``` r
stats::lm(formula, data = perturbed_data, weights = ..., offset = ...)
stats::glm(formula, data = perturbed_data, family = original_family, weights = ..., offset = ...)
```

Avoid dangerous eval hacks where possible. Handle offsets/weights
carefully.

### 9.4 Dependency philosophy

Keep CRAN lean.

Likely `Imports`:

- `cli`
- `rlang`
- `tibble`
- `vctrs`
- `ggplot2`
- `stats`
- `utils`

Potential `Suggests`:

- `sandwich`
- `lmtest`
- `broom`
- `testthat`
- `rmarkdown`
- `knitr`
- `rstudioapi`
- `shiny`
- `lme4`
- `survival`
- `performance`

Do not require Python, Julia, external APIs, internet, databases, or
hosted services.

------------------------------------------------------------------------

## 10. RStudio Addin

### 10.1 User flow

User has a model object in the environment:

``` r
fit <- lm(score ~ treatment + age + baseline_score, data = df)
```

They choose:

``` text
Addins → Attack This Claim
```

A small UI asks:

- model object: dropdown from environment;
- term: dropdown of coefficient names;
- intensity: fast / normal / deep;
- alpha: 0.05;
- attack families: checkboxes.

Then it runs:

``` r
result <- falsifyr::attack(fit, term = "treatment", intensity = "normal")
```

and opens the report in the Viewer.

### 10.2 Addin implementation

Use `rstudioapi` conditionally:

``` r
if (!requireNamespace("rstudioapi", quietly = TRUE)) {
  cli::cli_abort("The RStudio addin requires the {.pkg rstudioapi} package.")
}
```

Register in `inst/rstudio/addins.dcf`.

Do not make the addin necessary for the package to work.

------------------------------------------------------------------------

## 11. Reports

### 11.1 Console report

Fast, dramatic, readable.

### 11.2 HTML report

Self-contained static HTML via `htmltools` or `rmarkdown` if installed.

Sections:

1.  **Claim card**
    - formula
    - term
    - original estimate/p/CI
2.  **Survival verdict**
    - score
    - category
    - explanation
3.  **Smallest kill**
    - attack name
    - perturbation
    - before/after
4.  **Attack leaderboard**
    - sorted by kill distance
5.  **Family sections**
    - SE attacks
    - row deletion
    - covariate
    - missingness
    - measurement error
    - placebo
    - specification
6.  **Caveats**
    - what was not tested
    - model classes unsupported
    - required user judgment
7.  **Reproducibility**
    - seed
    - package version
    - session info
    - call

### 11.3 Visual language

The report should feel like a “claim survival card,” not an academic
diagnostic dump.

Use words like:

- Survives
- Dies
- Smallest kill
- Weakest assumption
- Most lethal attack
- Fragility curve
- Survival score

But keep caveats serious and non-sensational.

------------------------------------------------------------------------

## 12. Attack algorithms in more detail

### 12.1 Claim extraction for `lm`

``` r
extract_claim.lm <- function(model, term, alpha = 0.05, ...) {
  coefs <- summary(model)$coefficients
  if (is.null(term)) term <- choose_default_term(coefs)
  row <- coefs[term, , drop = FALSE]
  ci <- stats::confint(model, parm = term, level = 1 - alpha)
  list(
    term = term,
    estimate = unname(row[1, "Estimate"]),
    std_error = unname(row[1, "Std. Error"]),
    statistic = unname(row[1, "t value"]),
    p_value = unname(row[1, "Pr(>|t|)"]),
    conf_low = unname(ci[1]),
    conf_high = unname(ci[2])
  )
}
```

### 12.2 Claim extraction for `glm`

Handle coefficient table column names:

- `"z value"` and `"Pr(>|z|)"` for common GLM.
- Use `family(model)$family` and `family(model)$link`.

### 12.3 Claim extraction for `htest`

For `t.test`, `wilcox.test`, and `cor.test`, a claim may not have a
named coefficient.

Fields:

``` r
list(
  term = "test",
  estimate = if present,
  statistic = object$statistic,
  p_value = object$p.value,
  conf_low = object$conf.int[1],
  conf_high = object$conf.int[2],
  method = object$method
)
```

Attacks for `htest` can be more limited at first.

### 12.4 Row deletion attack

Pseudo-code:

``` r
attack_row_deletion <- function(model, claim, max_remove_n = 20, max_remove_prop = 0.05) {
  data <- model.frame(model)
  n <- nrow(data)
  max_k <- min(max_remove_n, floor(max_remove_prop * n))

  influence_rank <- rank_rows_by_target_influence(model, claim$term)

  results <- vector("list", max_k)

  for (k in seq_len(max_k)) {
    remove_idx <- influence_rank[seq_len(k)]
    data_k <- data[-remove_idx, , drop = FALSE]
    fit_k <- refit_model(model, data_k)
    claim_k <- extract_claim(fit_k, term = claim$term)
    results[[k]] <- summarize_attack(...)
    if (is_killed(claim_k)) break
  }

  bind_results(results)
}
```

Ranking options:

1.  DFBETAs for target term if available.
2.  Cook’s distance fallback.
3.  Absolute residual × leverage fallback.

### 12.5 Greedy adversarial row attack

More expensive but cooler:

``` text
At each step:
  for each remaining row candidate among top M influence rows:
    remove row temporarily
    refit
    measure movement toward kill
  permanently remove row that most increases p-value / moves CI toward null
Stop when killed.
```

This is more “adversarial” than simply removing top Cook’s distance
rows.

Default in normal/deep mode:

- fast: influence-ranked deletion
- normal: greedy among top 20 rows
- deep: greedy among top 50 rows
- insane: beam search over row subsets

### 12.6 Measurement-error attack

Pseudo-code:

``` r
for (level in noise_grid) {
  for (b in seq_len(B)) {
    data_b <- data
    data_b[[outcome]] <- data[[outcome]] + rnorm(n, 0, level * sd(data[[outcome]], na.rm = TRUE))
    fit_b <- refit_model(model, data_b)
    claim_b <- extract_claim(fit_b, term)
    killed[b] <- is_killed(claim_b)
  }
  kill_rate[level] <- mean(killed)
}
```

Report:

- kill probability curve;
- noise level at 50% kill rate;
- first level where median p \> alpha.

### 12.7 Missingness attack

Pseudo-code:

``` r
data_original <- recover_original_data(model)
data_complete <- model.frame(model)

methods <- c("complete_case", "mean_impute", "median_impute", "mode_factor", "missing_indicator")

for method in methods:
  data_m <- apply_missingness_strategy(data_original, method)
  fit_m <- refit_model(model, data_m)
  claim_m <- extract_claim(fit_m, term)
```

Need to preserve row alignment carefully.

### 12.8 Placebo label permutation

Pseudo-code:

``` r
for (b in seq_len(B)) {
  data_b <- data
  data_b[[term_variable]] <- sample(data_b[[term_variable]])
  fit_b <- refit_model(model, data_b)
  claim_b <- extract_claim(fit_b, term)
  placebo_stronger[b] <- claim_b$p_value <= original$p_value &&
                         abs(claim_b$estimate) >= abs(original$estimate)
}
placebo_rate <- mean(placebo_stronger)
```

This requires mapping `term` back to a variable, which is nontrivial for
factors/interactions. MVP can support simple non-factor numeric/binary
terms first.

------------------------------------------------------------------------

## 13. Intensity profiles

### fast

- row deletion: influence-ranked, max 5 rows
- bootstrap: B = 100
- noise: 5 levels × 50 reps
- placebo: 100 reps
- no specification explosion

### normal

- row deletion: greedy among top 20, max 5% rows
- bootstrap: B = 500
- noise: 8 levels × 100 reps
- placebo: 500 reps
- drop-one covariate

### deep

- row deletion: greedy among top 50
- bootstrap: B = 1000
- noise: 12 levels × 200 reps
- placebo: 1000 reps
- drop/add covariates and simple transformations

### insane

- row deletion: beam search
- bootstrap: B = 5000
- noise: 20 levels × 500 reps
- placebo: 5000 reps
- broader specification attack
- warning that runtime may be long

The user asked for “insane.” The package should have an
`intensity = "insane"` mode, but default should be `normal`.

------------------------------------------------------------------------

## 14. Profiles

### default

Balanced settings for general R users.

### clinical

- stricter language;
- focus on confidence intervals and practical effect thresholds;
- missingness attacks emphasized;
- no sensational language in report;
- optional equivalence/practical threshold.

### social_science

- specification attacks emphasized;
- p-value survival and researcher-degrees-of-freedom language allowed;
- omitted variable/covariate dependence emphasized.

### prediction

- split/leakage/performance attacks emphasized;
- p-values not central.

### strict

- lower tolerance for fragility;
- more attacks kill by CI/effect threshold.

### fast

- for interactive use.

------------------------------------------------------------------------

## 15. CRAN compliance notes

This is intended to become a real CRAN package.

Rules:

1.  No internet access in tests, examples, or vignettes.
2.  No calls to external APIs.
3.  No external runtimes.
4.  Keep examples fast.
5.  Large simulation tests should be skipped on CRAN or reduced with
    small seeds.
6.  Suggests packages must be used conditionally.
7.  All examples must be deterministic.
8.  No writing outside tempdir in tests.
9.  RStudio Addin must not break non-RStudio environments.
10. Shiny/report features should be optional if dependency weight
    becomes an issue.

Phase 0:

``` r
available::available("falsifyr")
```

If name is unavailable, alternatives:

- `fragilr`
- `attackr`
- `claimsurv`
- `stressr`
- `killclaimr`
- `robustclaimr`

------------------------------------------------------------------------

## 16. Testing strategy

### 16.1 Unit tests

- claim extraction for `lm`, `glm`, `htest`;
- kill rules;
- row-deletion attack returns expected kill on synthetic fragile data;
- row-deletion does not kill robust synthetic data;
- missingness attack handles numeric/factor;
- noise attack deterministic with seed;
- placebo attack deterministic with seed;
- survival score monotonicity.

### 16.2 Synthetic fragile datasets

Create two bundled datasets:

1.  `fragile_trial`
    - small but not tiny;
    - treatment effect driven by 2–4 influential rows;
    - p = 0.02 original;
    - dies under row deletion or robust SE.
2.  `resilient_trial`
    - strong stable treatment effect;
    - survives attacks.

The README demo should use `fragile_trial`.

### 16.3 Snapshot tests

Use
[`testthat::expect_snapshot()`](https://testthat.r-lib.org/reference/expect_snapshot.html)
for console output.

### 16.4 Validation corpus later

Create a separate GitHub-only validation corpus, not bundled in CRAN
package if too large.

Categories:

- known robust claims;
- known fragile claims;
- synthetic data with known kill mechanisms;
- legitimate covariate-dependence cases where the package must avoid
  over-interpreting.

------------------------------------------------------------------------

## 17. README demo

The README should open with drama.

``` r
library(falsifyr)

fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)

attack(fit, term = "treatment")
```

Console output:

``` text
FALSIFYR ATTACK REPORT

Claim:
  treatment -> score
  estimate = 0.42
  p = 0.018

Verdict:
  FRAGILE  (38/100)

Smallest kill:
  Remove 3 rows -> p = 0.091

Weakest assumption:
  Complete-case missingness.

Most lethal attack family:
  Row influence.

Interpretation:
  The claim is not necessarily false, but it is easy to make it disappear
  under plausible perturbations.
```

Plot:

``` r
plot(attack_result)
```

Report:

``` r
report(attack_result, "claim_attack.html")
```

------------------------------------------------------------------------

## 18. Build phases

### Phase 0 — Research and name

- Confirm package name availability.
- Read adjacent package docs:
  - `specr`
  - `multiverse`
  - `sensemakr`
  - `tipr`
  - `influence.ME`
  - `performance`
  - `sandwich`
  - `lmtest`
  - `robustbase`
- Write a “differentiation.md” that explicitly states what `falsifyr`
  does differently.
- Decide dependency strategy.

### Phase 1 — MVP core

Goal:

``` r
attack(lm_model, term = "x")
```

Works.

Implement:

- package skeleton;
- `extract_claim.lm`;
- `extract_claim.glm`;
- `extract_claim.htest`;
- `kill_rule`;
- row-deletion attack;
- bootstrap/SE attack;
- covariate drop-one attack;
- print method;
- survival score.

### Phase 2 — More attacks

Implement:

- missingness attack;
- measurement-error attack;
- placebo label permutation;
- plot method;
- HTML report.

### Phase 3 — RStudio Addin

Implement:

- model object selection;
- term dropdown;
- attack options;
- viewer report.

### Phase 4 — Polish for CRAN

- complete roxygen2 docs;
- vignettes;
- tests;
- R CMD check;
- CRAN-safe examples;
- pkgdown site.

### Phase 5 — Deep/insane mode

Implement:

- greedy/beam row deletion;
- specification attack;
- cluster/group deletion;
- optional robust SE packages;
- survival score calibration;
- validation corpus.

------------------------------------------------------------------------

## 19. Non-negotiable design principles

1.  **The package attacks claims, not models.**
2.  **The headline is the smallest kill.**
3.  **Every attack must be interpretable.**
4.  **Never overclaim that a killed result is false.**
5.  **Do not become a generic diagnostics package.**
6.  **Do not become a user-authored multiverse framework.**
7.  **Console output must be emotionally clear and statistically
    careful.**
8.  **CRAN viability matters.**
9.  **RStudio Addin polish matters.**
10. **The demo must make people say: “Wait, RStudio can do that?”**

------------------------------------------------------------------------

## 20. Example final API

``` r
library(falsifyr)

fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)

res <- attack(
  fit,
  term = "treatment",
  intensity = "normal",
  profile = "social_science"
)

res
plot(res)
report(res, "attack.html")
```

Advanced:

``` r
res <- attack(
  fit,
  term = "treatment",
  attacks = c("row_deletion", "robust_se", "missingness", "noise", "placebo"),
  kill_rule = "ci_crosses_zero",
  parallel = TRUE,
  seed = 42
)
```

Clinical threshold:

``` r
res <- attack(
  fit,
  term = "intervention",
  profile = "clinical",
  kill_rule = "effect_below_threshold",
  effect_threshold = log(1.10)
)
```

------------------------------------------------------------------------

## 21. Hard problems to solve honestly

### 21.1 Recovering original data

Many fitted R model objects only contain the model frame used, not
necessarily the full original data with unused columns.
Covariate-addition attacks may require `data =` supplied explicitly.

Policy:

- For attacks requiring extra data, ask for `data`.
- Do not silently use parent-frame evaluation unless safe.
- Report unavailable attacks clearly.

### 21.2 Tidy evaluation / transformed terms

Terms like:

``` r
lm(y ~ log(x) + poly(age, 2), data = df)
```

are harder to perturb.

Policy:

- MVP supports simple named terms.
- Later add transformed term support.
- If term cannot be mapped to raw variable, skip attacks that require
  raw variable perturbation.

### 21.3 Factors and contrasts

Factor coefficients need careful interpretation.

Policy:

- Extract factor-level claim.
- Covariate and placebo attacks support simple factor predictors later.
- Report limitations clearly.

### 21.4 Runtime

Deep attacks can be expensive.

Policy:

- Provide intensity profiles.
- Print progress.
- Allow parallel later.
- Keep CRAN examples tiny.

### 21.5 Statistical interpretation

A result dying under attack does not prove it is false.

Policy:

- Always phrase as fragility, not falsity.
- Use “survives/dies under this attack,” not “true/false.”
- Include caveat section.

------------------------------------------------------------------------

## 22. Possible future extensions

- `attack_tidymodels()`
- `attack_broom()` for tidy model outputs
- survival models (`coxph`)
- mixed models (`lmer`, `glmer`)
- Bayesian posterior claim attacks
- causal sensitivity integration with `sensemakr`
- integration with `targets` pipelines
- Quarto report chunk that embeds survival card
- GitHub Action for report generation
- “defend()” mode: recommend the robustness checks needed to strengthen
  a fragile claim
- “attack_report.qmd” template

------------------------------------------------------------------------

## 23. The portfolio story

A completed version lets the author truthfully say:

> I built a CRAN-native RStudio package that turns a fitted model into
> an adversarial robustness test. It does not merely diagnose a model;
> it searches for the smallest plausible perturbation that changes the
> conclusion, across influence, robust uncertainty, missing data,
> measurement error, placebo tests, and specification choices. It
> produces a claim survival report that makes statistical fragility
> visible to ordinary R users.

This is a stronger identity than:

- “I built another R assistant”;
- “I built a linter”;
- “I built a dashboard”;
- “I built a generic sensitivity package.”

The memorable command is:

``` r
attack(model, term = "treatment")
```

Everything else exists to make that command feel insane.

------------------------------------------------------------------------

## 24. Source/research notes for Codex

Current adjacent tools to inspect before implementing:

- `specr`: CRAN page says it provides utilities for specification curve
  and multiverse analyses, including setup, running, evaluation, and
  plotting of specifications. URL:
  <https://cran.r-project.org/package=specr>
- `multiverse`: CRAN page says it implements multiverse-style analyses
  where users declare alternative analysis branches in R and R
  Notebooks. URL: <https://cran.r-project.org/package=multiverse>
- `sensemakr`: CRAN page says it implements sensitivity analysis tools
  extending omitted-variable-bias frameworks for regression models. URL:
  <https://cran.r-project.org/package=sensemakr>
- `tipr`: CRAN page says it conducts tipping-point analyses around
  unmeasured confounding and how a result may tip to insignificance.
  URL: <https://cran.r-project.org/package=tipr>
- `influence.ME`: CRAN page says it detects influential cases in
  generalized mixed-effects models and includes a procedure to detect
  changing levels of significance. URL:
  <https://cran.r-project.org/package=influence.ME>
- `performance`: CRAN page says it provides model-quality utilities and
  diagnostic checks for a large variety of regression models. URL:
  <https://cran.r-project.org/package=performance>

Codex should keep researching this space during implementation and
update `docs/differentiation.md` whenever it finds a closer competitor.
