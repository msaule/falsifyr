# Attacking a Regression Claim

`falsifyr` attacks claims, not whole models. The core question is:

> What would it take to kill this result?

Start with an ordinary fitted model and a term.

``` r
library(falsifyr)

fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
res <- attack(
  fit,
  term = "treatment",
  attacks = c("row_deletion", "missingness", "noise"),
  intensity = "fast",
  seed = 1
)

res
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
#> COLLAPSES | survival score: 0/100
#> 
#> Smallest kill
#> Binary label flip: 50% kill rate after flipping 1.0% of treatment labels
#> Method: binary_flip
#> Variable: treatment
#> 
#> Weakest assumptions
#> 1. Measurement error: 50% kill rate after flipping 1.0% of treatment labels
#> 2. Row deletion / influence: remove 1 row -> p = 0.069
#> 3. Missing data: Median imputation -> p = 0.109
#> 
#> Died under
#> Binary label flip; Influential row deletion; Median imputation; Mean
#> imputation; Mode/explicit-missing imputation; Outcome noise
#> 
#> Survived
#> Missingness-indicator imputation; Predictor noise: age
#> 
#> A killed claim is fragile under an attack; that does not prove it is false.
#> Use plot(x) for survival map.
#> Use report(x, "attack.html") for full report.
```

The headline is the smallest kill. In the attack table,
`leaderboard_rank` orders perturbations by lethality and kill distance.

``` r
res$attacks[, c("leaderboard_rank", "attack_family", "attack_name", "status", "p_value", "explanation")]
#> # A tibble: 8 x 6
#>   leaderboard_rank attack_family     attack_name      status p_value explanation
#>              <int> <chr>             <chr>            <chr>    <dbl> <chr>      
#> 1                1 measurement_error Binary label fl~ killed  0.0559 50% kill r~
#> 2                2 row_deletion      Influential row~ killed  0.0694 remove 1 r~
#> 3                3 missingness       Median imputati~ killed  0.109  Median imp~
#> 4                4 missingness       Mean imputation  killed  0.0972 Mean imput~
#> 5                5 missingness       Mode/explicit-m~ killed  0.0972 Mode/expli~
#> 6                6 measurement_error Outcome noise    killed  0.0547 50% kill r~
#> 7                7 missingness       Missingness-ind~ survi~  0.0367 Missingnes~
#> 8                8 measurement_error Predictor noise~ survi~  0.0405 no 50% kil~
```

A killed claim is fragile under that attack. It does not prove that the
original claim is false, and it does not say the perturbed analysis is
preferable.

Reports are static HTML files and can be written to temporary paths in
scripted workflows.

``` r
report_file <- report(res, file = tempfile(fileext = ".html"))
basename(report_file)
#> [1] "file105542bc43599.html"
```
