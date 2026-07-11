.onLoad <- function(libname, pkgname) {
  if (requireNamespace("broom", quietly = TRUE)) {
    vctrs::s3_register("broom::tidy", "falsifyr_attack")
    vctrs::s3_register("broom::glance", "falsifyr_attack")
  }
  invisible(NULL)
}

#' Convert an attack result to a tidy leaderboard
#'
#' Optional `broom` methods expose falsifyr's two headline data products: a
#' row-per-attack leaderboard from `broom::tidy()` and a one-row claim summary
#' from `broom::glance()`.
#'
#' @param x A `falsifyr_attack` object.
#' @param ... Additional arguments, currently ignored.
#'
#' @return `tidy.falsifyr_attack()` returns the ranked attack tibble without
#'   list-column payloads. `glance.falsifyr_attack()` returns a one-row tibble
#'   summarizing the claim, verdict, score, and attack counts.
#'
#' @name broom-methods
NULL

tidy.falsifyr_attack <- function(x, ...) {
  check_attack_result(x)
  columns <- c(
    "leaderboard_rank", "attack_id", "attack_family", "attack_name", "status",
    "killed", "estimate", "p_value", "delta_p", "delta_estimate",
    "kill_distance", "severity", "explanation"
  )
  x$attacks[, intersect(columns, names(x$attacks)), drop = FALSE]
}

glance.falsifyr_attack <- function(x, ...) {
  check_attack_result(x)
  tibble::tibble(
    model_class = x$claim$model_class,
    term = x$claim$term,
    estimate = x$claim$estimate,
    p_value = x$claim$p_value,
    survival_score = x$survival_score,
    verdict = x$verdict,
    attacks_run = nrow(x$attacks),
    attacks_killed = sum(x$attacks$killed %in% TRUE),
    smallest_kill = if (is.null(x$smallest_kill)) NA_character_ else x$smallest_kill$attack_name
  )
}
