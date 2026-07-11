# Decide whether a perturbed claim is killed

Applies the selected kill rule to a claim extracted from a perturbed
model.

## Usage

``` r
is_killed(
  claim,
  original_claim = NULL,
  alpha = claim$alpha %||% 0.05,
  kill_rule = claim$kill_rule %||% "p_over_alpha",
  effect_threshold = claim$effect_threshold
)
```

## Arguments

- claim:

  A claim list, typically produced by
  [`extract_claim()`](https://msaule.github.io/falsifyr/reference/extract_claim.md).

- original_claim:

  Optional original claim. Required for `"sign_flip"`.

- alpha:

  Significance level for `"p_over_alpha"`.

- kill_rule:

  Character scalar naming the kill rule.

- effect_threshold:

  Numeric threshold for `"effect_below_threshold"`.

## Value

`TRUE` if the claim is killed, otherwise `FALSE`.

## Examples

``` r
fit <- lm(score ~ treatment + age, data = fragile_trial)
claim <- extract_claim(fit, term = "treatment")
is_killed(claim)
#> [1] TRUE
```
