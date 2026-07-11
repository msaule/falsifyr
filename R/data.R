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
#' @export
fragile_trial <- local({
  set.seed(2)
  n <- 80
  treatment <- rep(c(0, 1), each = 40)
  age <- round(stats::rnorm(n, 50, 10))
  baseline_score <- stats::rnorm(n)
  score <- 0.45 * baseline_score + 0.01 * age + stats::rnorm(n, 0, 0.75)
  score[41:44] <- score[41:44] + 1.8
  baseline_score[45:50] <- NA_real_
  data.frame(
    score = score,
    treatment = treatment,
    age = age,
    baseline_score = baseline_score
  )
})

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
#' @export
resilient_trial <- local({
  set.seed(42)
  n <- 120
  treatment <- rep(c(0, 1), each = n / 2)
  age <- round(stats::rnorm(n, 52, 9))
  baseline_score <- stats::rnorm(n)
  score <- 1.2 * treatment + 0.5 * baseline_score + 0.01 * age +
    stats::rnorm(n, 0, 0.55)
  data.frame(
    score = score,
    treatment = treatment,
    age = age,
    baseline_score = baseline_score
  )
})
