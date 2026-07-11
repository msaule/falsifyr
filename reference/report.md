# Write an HTML attack report

Creates a standalone static HTML report for a `falsifyr_attack` object.

## Usage

``` r
report(result, file = "falsifyr_report.html")
```

## Arguments

- result:

  A `falsifyr_attack` object returned by
  [`attack()`](https://msaule.github.io/falsifyr/reference/attack.md).

- file:

  Output HTML file path.

## Value

The normalized output path, invisibly.

## Examples

``` r
fit <- lm(score ~ treatment + age, data = fragile_trial)
result <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")
out <- report(result, file = tempfile(fileext = ".html"))
file.exists(out)
#> [1] TRUE
```
