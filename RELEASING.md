# Releasing falsifyr

1. Run `devtools::document()` and `devtools::test()` with current R.
2. Run `spelling::spell_check_package()` and add only legitimate package terms
   to `inst/WORDLIST`.
3. Run the GitHub-only corpus with `source("validation/run-validation.R")`.
4. Run `lintr::lint_package()` and build the pkgdown site.
5. Build the source tarball with `R CMD build .` and inspect its contents to
   confirm that development-only files are excluded.
6. Run `R CMD check --as-cran` on that tarball with a working LaTeX toolchain.
   Require zero errors and zero warnings; record every note.
7. Run the same manual-enabled check on R-devel, then check the tarball on the
   major CRAN platforms. Do not use `--no-manual` for a release candidate.
8. Update `cran-comments.md`, submit the source tarball through the CRAN form,
   and confirm the maintainer email.

Do not submit another build while a CRAN submission is pending.
