## Test environments

- local Windows 11, R 4.6.1
- GitHub Actions: Ubuntu with R-devel and R release; macOS and Windows with R
  release

## R CMD check results

0 errors | 0 warnings | 1 note

## Notes

- This is a new submission.
- The package performs no network access in examples, tests, or vignettes.
- Optional `lme4`, `survival`, `sandwich`, `lmtest`, RStudio, and Shiny
  functionality is guarded with `requireNamespace()` or test skips.
- Parallel execution is opt-in and capped at two workers.

## Resubmission

This is a resubmission. In this version I have:

- added references for the package's methodological foundations to the
  `Description` field using CRAN's DOI format;
- documented the class, structure, and meaning of `fragile_trial` and
  `resilient_trial`, then regenerated their Rd files with `\value` tags;
- removed the default output path from `report()`, which now requires an
  explicit user-supplied file path; examples, vignettes, and tests use
  `tempfile()`; and
- replaced runtime data-generation functions and their fixed seeds with static
  package datasets.
