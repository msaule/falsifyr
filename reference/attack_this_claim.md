# Launch the Attack This Claim RStudio addin

Opens a Shiny gadget inside RStudio for selecting a supported model
object, choosing a target term, running falsifyr attacks, and viewing
the generated report. The result is assigned to `falsifyr_last_attack`
in the selected environment.

## Usage

``` r
attack_this_claim(envir = parent.frame())
```

## Arguments

- envir:

  Environment to scan for supported model objects.

## Value

Invisibly returns `NULL` when the addin cannot be launched; otherwise
launches the gadget for its side effects.
