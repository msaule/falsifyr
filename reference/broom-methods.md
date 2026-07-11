# Convert an attack result to a tidy leaderboard

Optional `broom` methods expose falsifyr's two headline data products: a
row-per-attack leaderboard from
[`broom::tidy()`](https://generics.r-lib.org/reference/tidy.html) and a
one-row claim summary from
[`broom::glance()`](https://generics.r-lib.org/reference/glance.html).

## Arguments

- x:

  A `falsifyr_attack` object.

- ...:

  Additional arguments, currently ignored.

## Value

`tidy.falsifyr_attack()` returns the ranked attack tibble without
list-column payloads. `glance.falsifyr_attack()` returns a one-row
tibble summarizing the claim, verdict, score, and attack counts.
