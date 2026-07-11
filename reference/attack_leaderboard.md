# Extract the attack leaderboard

Returns the ranked attack table from a `falsifyr_attack` object. The
first row is the smallest kill when any attack killed the claim.

## Usage

``` r
attack_leaderboard(result)
```

## Arguments

- result:

  A `falsifyr_attack` object returned by
  [`attack()`](https://msaule.github.io/falsifyr/reference/attack.md).

## Value

A tibble of ranked attack results.

## Examples

``` r
fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
result <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")
attack_leaderboard(result)
#> # A tibble: 1 x 14
#>   attack_id     attack_family attack_name status killed estimate p_value delta_p
#>   <chr>         <chr>         <chr>       <chr>  <lgl>     <dbl>   <dbl>   <dbl>
#> 1 row_deletion~ row_deletion  Influentia~ killed TRUE      0.355  0.0694  0.0280
#> # i 6 more variables: delta_estimate <dbl>, kill_distance <dbl>,
#> #   severity <dbl>, explanation <chr>, payload <list>, leaderboard_rank <int>
```
