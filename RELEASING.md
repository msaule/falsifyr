# Releasing falsifyr

1.  Run
    [`devtools::document()`](https://devtools.r-lib.org/reference/document.html)
    and
    [`devtools::test()`](https://devtools.r-lib.org/reference/test.html)
    with current R.
2.  Run the GitHub-only corpus with
    `source("validation/run-validation.R")`.
3.  Run
    [`lintr::lint_package()`](https://lintr.r-lib.org/reference/lint.html)
    and build the pkgdown site.
4.  Build the source tarball with `R CMD build .`.
5.  Run `R CMD check --as-cran` on that tarball with a working LaTeX
    toolchain.
6.  Check the tarball on R-devel and the major CRAN platforms.
7.  Update `cran-comments.md`, submit the source tarball through the
    CRAN form, and confirm the maintainer email.

Do not submit another build while a CRAN submission is pending.
