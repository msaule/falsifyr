# Extract the statistical claim from a model

Builds the claim card that falsifyr attacks: term, estimate,
uncertainty, p-value, confidence interval, and kill-rule metadata.

## Usage

``` r
extract_claim(model, term = NULL, ...)

# Default S3 method
extract_claim(model, term = NULL, ...)

# S3 method for class 'lm'
extract_claim(
  model,
  term = NULL,
  alpha = 0.05,
  alternative = c("two.sided", "less", "greater"),
  kill_rule = "p_over_alpha",
  effect_threshold = NULL,
  ...
)

# S3 method for class 'glm'
extract_claim(
  model,
  term = NULL,
  alpha = 0.05,
  alternative = c("two.sided", "less", "greater"),
  kill_rule = "p_over_alpha",
  effect_threshold = NULL,
  ...
)

# S3 method for class 'htest'
extract_claim(
  model,
  term = NULL,
  alpha = 0.05,
  alternative = c("two.sided", "less", "greater"),
  kill_rule = "p_over_alpha",
  effect_threshold = NULL,
  ...
)

# S3 method for class 'anova'
extract_claim(
  model,
  term = NULL,
  alpha = 0.05,
  alternative = c("two.sided", "less", "greater"),
  kill_rule = "p_over_alpha",
  effect_threshold = NULL,
  ...
)

# S3 method for class 'aov'
extract_claim(
  model,
  term = NULL,
  alpha = 0.05,
  alternative = c("two.sided", "less", "greater"),
  kill_rule = "p_over_alpha",
  effect_threshold = NULL,
  ...
)

# S3 method for class 'merMod'
extract_claim(
  model,
  term = NULL,
  alpha = 0.05,
  alternative = c("two.sided", "less", "greater"),
  kill_rule = "p_over_alpha",
  effect_threshold = NULL,
  ...
)

# S3 method for class 'coxph'
extract_claim(
  model,
  term = NULL,
  alpha = 0.05,
  alternative = c("two.sided", "less", "greater"),
  kill_rule = "p_over_alpha",
  effect_threshold = NULL,
  ...
)
```

## Arguments

- model:

  A fitted model or hypothesis-test object.

- term:

  Character scalar naming the coefficient or test term.

- ...:

  Additional arguments passed to methods.

- alpha:

  Significance level stored on the extracted claim.

- alternative:

  Character scalar defining the claim direction for coefficient tests:
  `"two.sided"`, `"less"`, or `"greater"`.

- kill_rule:

  Character scalar naming the kill rule to store on the extracted claim.

- effect_threshold:

  Numeric threshold stored on the claim for `"effect_below_threshold"`.

## Value

A list describing the extracted claim.
