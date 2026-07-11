## Test environments

- local Windows 11, R 4.6.1
- GitHub Actions: Ubuntu, macOS, and Windows with R release

## R CMD check results

0 errors | 0 warnings | 1 note

## Notes

- This is a new submission.
- The package performs no network access in examples, tests, or vignettes.
- Optional `lme4`, `survival`, `sandwich`, `lmtest`, RStudio, and Shiny
  functionality is guarded with `requireNamespace()` or test skips.
- Parallel execution is opt-in and capped at two workers.
