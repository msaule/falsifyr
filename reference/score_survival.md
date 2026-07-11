# Score claim survival

Computes falsifyr's heuristic 0-100 survival score from an attack
leaderboard.

## Usage

``` r
score_survival(attacks, smallest_kill = NULL)
```

## Arguments

- attacks:

  A data frame of attack results.

- smallest_kill:

  Optional row-like object describing the smallest kill.

## Value

Integer survival score from 0 to 100.

## Examples

``` r
fit <- lm(score ~ treatment + age, data = fragile_trial)
result <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")
score_survival(result$attacks, result$smallest_kill)
#> [1] 47
```
