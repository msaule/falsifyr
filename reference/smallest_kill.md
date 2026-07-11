# Extract the smallest kill from an attack result

Returns the headline perturbation that killed the claim, or `NULL` when
no attack killed the claim in the run.

## Usage

``` r
smallest_kill(result)
```

## Arguments

- result:

  A `falsifyr_attack` object returned by
  [`attack()`](https://msaule.github.io/falsifyr/reference/attack.md).

## Value

A list describing the smallest kill, or `NULL`.

## Examples

``` r
fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
result <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")
smallest_kill(result)
#> $attack_id
#> [1] "row_deletion_influential_row_deletion"
#> 
#> $attack_family
#> [1] "row_deletion"
#> 
#> $attack_name
#> [1] "Influential row deletion"
#> 
#> $status
#> [1] "killed"
#> 
#> $killed
#> [1] TRUE
#> 
#> $estimate
#> [1] 0.3553001
#> 
#> $p_value
#> [1] 0.06939223
#> 
#> $delta_p
#> [1] 0.02798691
#> 
#> $delta_estimate
#> [1] -0.08749806
#> 
#> $kill_distance
#> [1] 0.01351351
#> 
#> $severity
#> [1] 35
#> 
#> $explanation
#> [1] "remove 1 row -> p = 0.069"
#> 
#> $payload
#> $payload[[1]]
#> $payload[[1]]$rows
#> [1] 43
#> 
#> $payload[[1]]$rows_removed
#> [1] 1
#> 
#> $payload[[1]]$method
#> [1] "ranked"
#> 
#> $payload[[1]]$curve
#>   k rows_removed rows  estimate    p_value killed   progress
#> 1 1            1   43 0.3553001 0.06939223   TRUE 0.06939223
#> 
#> 
#> 
#> $leaderboard_rank
#> [1] 1
#> 
```
