#' Synthetic fragile trial data
#'
#' A small trial-like data set where the treatment claim starts below
#' `p = 0.05` but is sensitive to row deletion, missing-data alternatives, and
#' measurement-error attacks. It includes deterministic missingness in
#' `baseline_score` to exercise missing-data attacks.
#'
#' @format A data frame with 80 rows and 4 variables:
#' \describe{
#'   \item{score}{Continuous outcome.}
#'   \item{treatment}{Binary treatment indicator.}
#'   \item{age}{Participant age.}
#'   \item{baseline_score}{Baseline continuous score with some missing values.}
#' }
#' @return A data frame with one row per simulated participant. The columns
#'   contain the outcome, treatment assignment, age, and baseline score used to
#'   demonstrate a statistically significant but perturbation-sensitive claim.
#' @source Simulated data created for the `falsifyr` package.
"fragile_trial"

#' Synthetic resilient trial data
#'
#' A small trial-like data set with a stronger treatment effect intended to
#' survive simple falsifyr attack families such as row deletion, robust
#' uncertainty checks, and drop-one covariate attacks.
#'
#' @format A data frame with 120 rows and 4 variables:
#' \describe{
#'   \item{score}{Continuous outcome.}
#'   \item{treatment}{Binary treatment indicator.}
#'   \item{age}{Participant age.}
#'   \item{baseline_score}{Baseline continuous score.}
#' }
#' @return A data frame with one row per simulated participant. The columns
#'   contain the outcome, treatment assignment, age, and baseline score used to
#'   demonstrate a strong claim that survives the package's basic attacks.
#' @source Simulated data created for the `falsifyr` package.
"resilient_trial"
