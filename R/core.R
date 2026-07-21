#' Attack a statistical claim
#'
#' Runs a collection of adversarial robustness checks against a fitted model
#' claim. The returned object summarizes whether the claim survives each attack,
#' the smallest perturbation that kills it, and an overall survival score.
#'
#' @param model A fitted `lm`, `glm`, `aov`, `lme4::lmer`, `lme4::glmer`, or
#'   `survival::coxph` model. `htest` objects return an explicit limited-support
#'   result.
#' @param term Character scalar naming the coefficient or test term to attack.
#'   If `NULL`, falsifyr attacks the first non-intercept coefficient.
#' @param data Optional data frame used to refit the model. When omitted,
#'   falsifyr attempts to recover the model data.
#' @param outcome Optional character vector of user-supplied placebo outcome
#'   names for the placebo attack family.
#' @param cluster Optional character scalar naming a grouping variable for a
#'   grouped row-deletion attack. Supply `data` when the grouping variable is
#'   not part of the fitted formula.
#' @param profile Character scalar choosing an attack profile. Profiles tune the
#'   default attack-family emphasis when `attacks = NULL`; `profile = "fast"`
#'   also defaults to `intensity = "fast"` when intensity is not supplied.
#' @param attacks Character vector of attack families. `NULL` runs the default
#'   families.
#' @param intensity Character scalar controlling attack breadth: `"fast"`,
#'   `"normal"`, `"deep"`, or `"insane"`.
#' @param alpha Significance level used by kill rules.
#' @param alternative Character scalar defining the claim direction for
#'   coefficient tests: `"two.sided"`, `"less"`, or `"greater"`.
#' @param kill_rule Character scalar defining what kills a claim. Supported
#'   rules are `"p_over_alpha"`, `"ci_crosses_zero"`, `"sign_flip"`, and
#'   `"effect_below_threshold"`.
#' @param effect_threshold Numeric threshold used by
#'   `"effect_below_threshold"`.
#' @param seed Integer seed for deterministic attack runs.
#' @param parallel Logical; if `TRUE`, independent attack families run on at
#'   most two local workers.
#' @param verbose Logical; if `TRUE`, prints progress messages for expensive
#'   `"insane"` attack runs.
#'
#' @return A `falsifyr_attack` object with the extracted claim, attack
#'   leaderboard, smallest kill, survival score, verdict, runtime metadata, and
#'   warnings.
#' @examples
#' fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
#' result <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")
#' result
#' @export
attack <- function(model,
                   term = NULL,
                   data = NULL,
                   outcome = NULL,
                   cluster = NULL,
                   profile = c("default", "clinical", "social_science", "prediction", "strict", "fast"),
                   attacks = NULL,
                   intensity = c("normal", "fast", "deep", "insane"),
                   alpha = 0.05,
                   alternative = c("two.sided", "less", "greater"),
                   kill_rule = c("p_over_alpha", "ci_crosses_zero", "sign_flip", "effect_below_threshold"),
                   effect_threshold = NULL,
                   seed = 1,
                   parallel = FALSE,
                   verbose = TRUE) {
  started_at <- Sys.time()
  attack_call <- match.call(expand.dots = TRUE)
  intensity_missing <- missing(intensity)
  profile <- match.arg(profile)
  if (isTRUE(intensity_missing) && identical(profile, "fast")) {
    intensity <- "fast"
  }
  intensity <- match.arg(intensity)
  alternative <- match.arg(alternative)
  kill_rule <- match.arg(kill_rule)
  cluster <- normalize_cluster(cluster)
  attack_progress(verbose, intensity, "Insane mode: running broader adversarial searches.")
  family_selection <- normalize_attack_families(attacks, profile = profile)

  set.seed(seed)
  caller <- parent.frame()
  claim <- extract_claim(
    model,
    term = term,
    alpha = alpha,
    alternative = alternative,
    kill_rule = kill_rule,
    effect_threshold = effect_threshold
  )
  if (inherits(model, c("htest", "anova"))) {
    attacks_tbl <- attack_htest_limitations(claim, family_selection$families)
    if (nrow(attacks_tbl)) {
      attacks_tbl$delta_p <- attacks_tbl$p_value - claim$p_value
      attacks_tbl$delta_estimate <- attacks_tbl$estimate - claim$estimate
    }
    attacks_tbl <- rank_attack_leaderboard(attacks_tbl)
    smallest_kill <- pick_smallest_kill(attacks_tbl)
    result <- list(
      claim = claim,
      attacks = attacks_tbl,
      smallest_kill = smallest_kill,
      survival_score = NA_real_,
      verdict = "UNTESTED",
      runtime = attack_runtime(
        attack_call, started_at, model, seed, intensity, profile, alpha,
        alternative, kill_rule, effect_threshold, family_selection$families,
        family_selection$unknown, parallel
      ),
      warnings = list(
        unknown_attacks = family_selection$unknown,
        limited_model_class = class(model)[1]
      )
    )
    class(result) <- c("falsifyr_attack", "list")
    return(result)
  }
  placebo_outcomes <- normalize_placebo_outcomes(outcome)
  model_data <- recover_model_data(model, data = data, caller = caller)
  original_data <- recover_original_data(
    model,
    data = data,
    caller = caller,
    extra_vars = c(placebo_outcomes, cluster)
  )
  row_data <- attach_cluster_data(model_data, original_data, cluster)
  families <- family_selection$families

  family_runner <- function(family) {
    run_attack_family(
      family = family,
      model = model,
      claim = claim,
      model_data = model_data,
      original_data = original_data,
      row_data = row_data,
      cluster = cluster,
      intensity = intensity,
      alpha = alpha,
      kill_rule = kill_rule,
      seed = seed,
      placebo_outcomes = placebo_outcomes,
      verbose = verbose
    )
  }
  attack_rows <- parallel_attack_map(families, family_runner, isTRUE(parallel))

  attacks_tbl <- bind_attack_rows(attack_rows)
  if (nrow(attacks_tbl)) {
    attacks_tbl$delta_p <- attacks_tbl$p_value - claim$p_value
    attacks_tbl$delta_estimate <- attacks_tbl$estimate - claim$estimate
  }
  attacks_tbl <- rank_attack_leaderboard(attacks_tbl)
  smallest_kill <- pick_smallest_kill(attacks_tbl)
  score <- score_survival(attacks_tbl, smallest_kill = smallest_kill)
  result <- list(
    claim = claim,
    attacks = attacks_tbl,
    smallest_kill = smallest_kill,
    survival_score = score,
    verdict = verdict_from_score(score),
    runtime = attack_runtime(
      attack_call, started_at, model, seed, intensity, profile, alpha,
      alternative, kill_rule, effect_threshold, family_selection$families,
      family_selection$unknown, parallel
    ),
    warnings = list(unknown_attacks = family_selection$unknown)
  )
  class(result) <- c("falsifyr_attack", "list")
  result
}

#' Extract the smallest kill from an attack result
#'
#' Returns the headline perturbation that killed the claim, or `NULL` when no
#' attack killed the claim in the run.
#'
#' @param result A `falsifyr_attack` object returned by [attack()].
#'
#' @return A list describing the smallest kill, or `NULL`.
#' @examples
#' fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
#' result <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")
#' smallest_kill(result)
#' @export
smallest_kill <- function(result) {
  check_attack_result(result)
  result$smallest_kill
}

#' Extract the attack leaderboard
#'
#' Returns the ranked attack table from a `falsifyr_attack` object. The first row
#' is the smallest kill when any attack killed the claim.
#'
#' @param result A `falsifyr_attack` object returned by [attack()].
#'
#' @return A tibble of ranked attack results.
#' @examples
#' fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
#' result <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")
#' attack_leaderboard(result)
#' @export
attack_leaderboard <- function(result) {
  check_attack_result(result)
  result$attacks
}

#' Extract the statistical claim from a model
#'
#' Builds the claim card that falsifyr attacks: term, estimate, uncertainty,
#' p-value, confidence interval, and kill-rule metadata.
#'
#' @param model A fitted model or hypothesis-test object.
#' @param term Character scalar naming the coefficient or test term.
#' @param alpha Significance level stored on the extracted claim.
#' @param alternative Character scalar defining the claim direction for
#'   coefficient tests: `"two.sided"`, `"less"`, or `"greater"`.
#' @param kill_rule Character scalar naming the kill rule to store on the
#'   extracted claim.
#' @param effect_threshold Numeric threshold stored on the claim for
#'   `"effect_below_threshold"`.
#' @param ... Additional arguments passed to methods.
#'
#' @return A list describing the extracted claim.
#' @export
extract_claim <- function(model, term = NULL, ...) {
  UseMethod("extract_claim")
}

#' @rdname extract_claim
#' @export
extract_claim.default <- function(model, term = NULL, ...) {
  stop("falsifyr does not yet know how to extract a claim from objects of class: ",
       paste(class(model), collapse = ", "), call. = FALSE)
}

#' @rdname extract_claim
#' @export
extract_claim.lm <- function(model,
                             term = NULL,
                             alpha = 0.05,
                             alternative = c("two.sided", "less", "greater"),
                             kill_rule = "p_over_alpha",
                             effect_threshold = NULL,
                             ...) {
  alternative <- match.arg(alternative)
  coefs <- summary(model)$coefficients
  term <- choose_term(coefs, term)
  p_col <- grep("^Pr\\(", colnames(coefs), value = TRUE)
  if (!length(p_col)) {
    stop("Could not find a p-value column for the requested claim.", call. = FALSE)
  }
  ci <- safe_confint(model, term, alpha)
  statistic <- unname(coefs[term, grep("value$", colnames(coefs), value = TRUE)[1]])
  p_value <- coefficient_p_value(model, statistic, unname(coefs[term, p_col[1]]), alternative)
  list(
    model_class = class(model)[1],
    formula = stats::formula(model),
    outcome = all.vars(stats::formula(model))[1],
    term = term,
    estimate = unname(coefs[term, "Estimate"]),
    std_error = unname(coefs[term, "Std. Error"]),
    statistic = statistic,
    p_value = p_value,
    conf_low = ci[1],
    conf_high = ci[2],
    alpha = alpha,
    alternative = alternative,
    kill_rule = kill_rule,
    effect_threshold = effect_threshold
  )
}

#' @rdname extract_claim
#' @export
extract_claim.glm <- function(model,
                              term = NULL,
                              alpha = 0.05,
                              alternative = c("two.sided", "less", "greater"),
                              kill_rule = "p_over_alpha",
                              effect_threshold = NULL,
                              ...) {
  claim <- NextMethod()
  claim$model_class <- "glm"
  claim$family <- stats::family(model)$family
  claim$link <- stats::family(model)$link
  claim
}

#' @rdname extract_claim
#' @export
extract_claim.htest <- function(model,
                                term = NULL,
                                alpha = 0.05,
                                alternative = c("two.sided", "less", "greater"),
                                kill_rule = "p_over_alpha",
                                effect_threshold = NULL,
                                ...) {
  alternative <- model$alternative %||% match.arg(alternative)
  estimate <- if (!is.null(model$estimate)) unname(model$estimate[1]) else NA_real_
  ci <- if (!is.null(model$conf.int)) unname(model$conf.int[1:2]) else c(NA_real_, NA_real_)
  list(
    model_class = "htest",
    formula = NULL,
    outcome = NA_character_,
    term = term %||% "test",
    estimate = estimate,
    std_error = NA_real_,
    statistic = if (!is.null(model$statistic)) unname(model$statistic[1]) else NA_real_,
    p_value = model$p.value,
    conf_low = ci[1],
    conf_high = ci[2],
    alpha = alpha,
    alternative = alternative,
    kill_rule = kill_rule,
    effect_threshold = effect_threshold,
    method = model$method
  )
}

#' @rdname extract_claim
#' @export
extract_claim.anova <- function(model,
                                term = NULL,
                                alpha = 0.05,
                                alternative = c("two.sided", "less", "greater"),
                                kill_rule = "p_over_alpha",
                                effect_threshold = NULL,
                                ...) {
  alternative <- match.arg(alternative)
  rows <- rownames(model)
  available <- rows[!grepl("Residual", rows, ignore.case = TRUE)]
  if (is.null(term)) term <- available[1]
  if (!term %in% rows) {
    stop(
      "Term `", term, "` was not found. Available terms: ",
      paste(available, collapse = ", "),
      call. = FALSE
    )
  }
  p_col <- grep("^Pr\\(", colnames(model), value = TRUE)[1]
  statistic_col <- intersect(c("F value", "Chisq", "Deviance"), colnames(model))[1]
  list(
    model_class = "anova",
    formula = NULL,
    outcome = NA_character_,
    term = term,
    estimate = if (length(statistic_col)) unname(model[term, statistic_col]) else NA_real_,
    std_error = NA_real_,
    statistic = if (length(statistic_col)) unname(model[term, statistic_col]) else NA_real_,
    p_value = if (length(p_col)) unname(model[term, p_col]) else NA_real_,
    conf_low = NA_real_,
    conf_high = NA_real_,
    alpha = alpha,
    alternative = alternative,
    kill_rule = kill_rule,
    effect_threshold = effect_threshold,
    method = "Analysis of variance table"
  )
}

coefficient_p_value <- function(model, statistic, two_sided_p, alternative) {
  if (identical(alternative, "two.sided")) return(two_sided_p)
  if (!is.finite(statistic)) return(NA_real_)
  if (inherits(model, "glm")) {
    return(stats::pnorm(statistic, lower.tail = identical(alternative, "less")))
  }
  df <- stats::df.residual(model)
  if (!is.finite(df) || df <= 0) {
    return(stats::pnorm(statistic, lower.tail = identical(alternative, "less")))
  }
  stats::pt(statistic, df = df, lower.tail = identical(alternative, "less"))
}

robust_p_value <- function(model, statistic, two_sided_p, alternative) {
  if (identical(alternative, "two.sided")) return(two_sided_p)
  if (!is.finite(statistic)) return(NA_real_)
  if (inherits(model, "glm")) {
    return(stats::pnorm(statistic, lower.tail = identical(alternative, "less")))
  }
  df <- stats::df.residual(model)
  if (!is.finite(df) || df <= 0) {
    return(stats::pnorm(statistic, lower.tail = identical(alternative, "less")))
  }
  stats::pt(statistic, df = df, lower.tail = identical(alternative, "less"))
}

#' Refit a model on perturbed data
#'
#' Refits a supported model class with a replacement data frame and optional
#' formula. Attack families use this generic internally, and it is exported for
#' users who want reproducible perturbation workflows. For `lm` and `glm`
#' model frames, evaluated weights and offsets are preserved where possible.
#'
#' @param model A fitted model object.
#' @param data A data frame for the refit.
#' @param formula Optional replacement formula. Defaults to the model formula.
#' @param ... Additional arguments passed to the model-fitting function.
#'
#' @return A refitted model object of the same broad class as `model`.
#' @examples
#' fit <- lm(score ~ treatment + age, data = fragile_trial)
#' refit_model(fit, data = fragile_trial)
#' @export
refit_model <- function(model, data, formula = NULL, ...) {
  UseMethod("refit_model")
}

#' @rdname refit_model
#' @export
refit_model.lm <- function(model, data, formula = NULL, ...) {
  formula <- formula %||% stats::formula(model)
  args <- refit_call_args(formula = formula, data = data, ...)
  do.call(stats::lm, args)
}

#' @rdname refit_model
#' @export
refit_model.glm <- function(model, data, formula = NULL, ...) {
  formula <- formula %||% stats::formula(model)
  args <- refit_call_args(formula = formula, data = data, family = stats::family(model), ...)
  do.call(stats::glm, args)
}

#' Decide whether a perturbed claim is killed
#'
#' Applies the selected kill rule to a claim extracted from a perturbed model.
#'
#' @param claim A claim list, typically produced by [extract_claim()].
#' @param original_claim Optional original claim. Required for `"sign_flip"`.
#' @param alpha Significance level for `"p_over_alpha"`.
#' @param kill_rule Character scalar naming the kill rule.
#' @param effect_threshold Numeric threshold for `"effect_below_threshold"`.
#'
#' @return `TRUE` if the claim is killed, otherwise `FALSE`.
#' @examples
#' fit <- lm(score ~ treatment + age, data = fragile_trial)
#' claim <- extract_claim(fit, term = "treatment")
#' is_killed(claim)
#' @export
is_killed <- function(claim,
                      original_claim = NULL,
                      alpha = claim$alpha %||% 0.05,
                      kill_rule = claim$kill_rule %||% "p_over_alpha",
                      effect_threshold = claim$effect_threshold) {
  if (kill_rule == "p_over_alpha") {
    return(is.finite(claim$p_value) && claim$p_value > alpha)
  }
  if (kill_rule == "ci_crosses_zero") {
    return(is.finite(claim$conf_low) && is.finite(claim$conf_high) &&
             claim$conf_low <= 0 && claim$conf_high >= 0)
  }
  if (kill_rule == "sign_flip") {
    if (is.null(original_claim)) return(FALSE)
    return(sign(claim$estimate) != sign(original_claim$estimate))
  }
  if (kill_rule == "effect_below_threshold") {
    if (is.null(effect_threshold)) return(FALSE)
    return(abs(claim$estimate) < abs(effect_threshold))
  }
  FALSE
}

#' Score claim survival
#'
#' Computes falsifyr's heuristic 0-100 survival score from an attack
#' leaderboard.
#'
#' @param attacks A data frame of attack results.
#' @param smallest_kill Optional row-like object describing the smallest kill.
#'
#' @return Integer survival score from 0 to 100.
#' @examples
#' fit <- lm(score ~ treatment + age, data = fragile_trial)
#' result <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")
#' score_survival(result$attacks, result$smallest_kill)
#' @export
score_survival <- function(attacks, smallest_kill = NULL) {
  if (is.null(attacks) || !nrow(attacks)) return(100)
  killed <- sum(attacks$killed, na.rm = TRUE)
  families <- length(unique(attacks$attack_family[attacks$killed %in% TRUE]))
  score <- 100 - killed * 10 - families * 8
  if (!is.null(smallest_kill) && isTRUE(smallest_kill$killed)) {
    score <- score - smallest_kill$severity
  }
  score <- score - placebo_rate_penalty(attacks)
  max(0, min(100, round(score)))
}

#' @export
print.falsifyr_attack <- function(x, ...) {
  claim <- x$claim
  cli::cli_h1("FALSIFYR ATTACK")
  cli::cli_text("Claim")
  cli::cli_text("  {claim_label(claim)}")
  if (!is.null(claim$formula)) cli::cli_text("  formula: {formula_text(claim$formula)}")
  if (!identical(claim$alternative %||% "two.sided", "two.sided")) cli::cli_text("  alternative: {claim$alternative}")
  cli::cli_text("  estimate: {fmt_num(claim$estimate)}")
  cli::cli_text("  p-value: {fmt_p(claim$p_value)}")
  cli::cli_text("  {ci_text(claim)}")
  cli::cli_text("")
  cli::cli_text("Verdict")
  cli::cli_text("  {x$verdict} | survival score: {x$survival_score}/100")
  cli::cli_text("")
  cli::cli_text("Smallest kill")
  if (is.null(x$smallest_kill)) {
    cli::cli_text("  No attack killed the claim in this run.")
  } else {
    cli::cli_text("  {x$smallest_kill$attack_name}: {x$smallest_kill$explanation}")
    details <- smallest_kill_details(x$smallest_kill)
    for (detail in details) {
      cli::cli_text("  {detail}")
    }
  }
  if (nrow(x$attacks)) {
    died <- x$attacks$attack_name[x$attacks$killed %in% TRUE]
    survived <- x$attacks$attack_name[x$attacks$status == "survived"]
    unavailable <- x$attacks$attack_name[x$attacks$status == "unavailable"]
    weakest <- weakest_assumptions(x$attacks, n = 3)
    cli::cli_text("")
    cli::cli_text("Weakest assumptions")
    if (length(weakest)) {
      for (i in seq_along(weakest)) {
        cli::cli_text("  {i}. {weakest[[i]]}")
      }
    } else {
      cli::cli_text("  No attack killed the claim in this run.")
    }
    cli::cli_text("")
    cli::cli_text("Died under")
    cli::cli_text("  {if (length(died)) paste(died, collapse = '; ') else 'none'}")
    cli::cli_text("")
    cli::cli_text("Survived")
    cli::cli_text("  {if (length(survived)) paste(survived, collapse = '; ') else 'none'}")
    if (length(unavailable)) {
      cli::cli_text("")
      cli::cli_text("Unavailable")
      cli::cli_text("  {paste(unavailable, collapse = '; ')}")
    }
  }
  cli::cli_text("")
  cli::cli_text("A killed claim is fragile under an attack; that does not prove it is false.")
  cli::cli_text("Use plot(x) for survival map.")
  cli::cli_text("Use report(x, \"attack.html\") for full report.")
  invisible(x)
}

#' @export
plot.falsifyr_attack <- function(x, ...) {
  if (!nrow(x$attacks)) {
    stop("No attack results to plot.", call. = FALSE)
  }
  ggplot2::ggplot(x$attacks, ggplot2::aes(x = .data$attack_name, y = .data$p_value, fill = .data$killed)) +
    ggplot2::geom_col() +
    ggplot2::geom_hline(yintercept = x$claim$alpha, linetype = 2) +
    ggplot2::coord_flip() +
    ggplot2::theme_minimal() +
    ggplot2::labs(
      x = NULL,
      y = "Perturbed p-value",
      fill = "Killed",
      title = "Claim survival map",
      subtitle = paste0("Target term: ", x$claim$term)
    )
}

#' Write an HTML attack report
#'
#' Creates a standalone static HTML report for a `falsifyr_attack` object.
#'
#' @param result A `falsifyr_attack` object returned by [attack()].
#' @param file Output HTML file path. This argument is required; `report()`
#'   never writes to the working directory by default.
#'
#' @return The normalized output path, invisibly.
#' @examples
#' fit <- lm(score ~ treatment + age, data = fragile_trial)
#' result <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")
#' out <- report(result, file = tempfile(fileext = ".html"))
#' file.exists(out)
#' @export
report <- function(result, file) {
  if (!inherits(result, "falsifyr_attack")) {
    stop("`result` must be a falsifyr_attack object.", call. = FALSE)
  }
  if (missing(file) || !is.character(file) || length(file) != 1L ||
      is.na(file) || !nzchar(file)) {
    stop("`file` must be supplied as one non-empty output path.", call. = FALSE)
  }
  html <- paste0(
    "<!doctype html><html><head><meta charset='utf-8'>",
    "<title>falsifyr attack report</title>",
    "<style>body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;margin:40px;line-height:1.45;color:#1f2933}",
    "table{border-collapse:collapse;width:100%;margin-top:12px}td,th{border-bottom:1px solid #d9e2ec;padding:8px;text-align:left}",
    ".score{font-size:38px;font-weight:700}.caveat{color:#52606d}</style></head><body>",
    "<h1>FALSIFYR ATTACK</h1>",
    "<h2>Claim card</h2>",
    claim_card_html(result$claim),
    "<h2>Survival verdict</h2>",
    "<p class='score'>", result$verdict, " ", result$survival_score, "/100</p>",
    "<p class='caveat'>The survival score is a heuristic summary, not a formal probability that the claim is true.</p>",
    "<h2>Smallest kill</h2>",
    smallest_kill_html(result$smallest_kill),
    "<h2>Attack leaderboard</h2>",
    attacks_table_html(result$attacks),
    "<h2>Family sections</h2>",
    family_sections_html(result$attacks),
    "<h2>Fragility curves</h2>",
    fragility_curves_html(result$attacks),
    "<h2>Limitations and caveats</h2>",
    limitations_html(result),
    "<h2>Reproducibility appendix</h2>",
    reproducibility_html(result),
    "</body></html>"
  )
  writeLines(html, con = file, useBytes = TRUE)
  invisible(normalizePath(file, mustWork = FALSE))
}

attack_row_deletion <- function(model, claim, data, intensity, alpha, kill_rule, cluster = NULL) {
  n <- nrow(data)
  max_k <- switch(intensity,
    fast = min(5, n - 3),
    normal = min(20, max(1, floor(0.05 * n))),
    deep = min(40, max(1, floor(0.1 * n))),
    insane = min(60, max(1, floor(0.2 * n)))
  )
  if (max_k < 1) {
    return(attack_result("row_deletion", "Influential row deletion", "unavailable", FALSE, claim, NA_real_, 100, "Not enough rows to attack.", list()))
  }
  rank <- rank_rows_for_claim(model, claim)
  search <- switch(intensity,
    fast = row_deletion_ranked_search(model, claim, data, rank, max_k, alpha, kill_rule),
    normal = row_deletion_greedy_search(model, claim, data, rank, max_k, min(20, n), alpha, kill_rule),
    deep = row_deletion_greedy_search(model, claim, data, rank, max_k, min(50, n), alpha, kill_rule),
    insane = row_deletion_beam_search(model, claim, data, rank, max_k, min(60, n), beam_width = 5, alpha, kill_rule)
  )
  if (is.null(search)) {
    return(attack_result(
      "row_deletion", "Adversarial row deletion", "unavailable", FALSE, claim,
      NA_real_, 0, "No valid row-deletion refits were found.", list(method = intensity)
    ))
  }
  name <- switch(search$method,
    ranked = "Influential row deletion",
    greedy = "Greedy row deletion",
    beam = "Beam row deletion",
    "Adversarial row deletion"
  )
  if (isTRUE(search$killed)) {
    individual <- attack_result(
      "row_deletion", name, "killed", TRUE, search$claim,
      length(search$rows) / n, severity_from_distance(length(search$rows) / n),
      paste0("remove ", length(search$rows), " row", if (length(search$rows) == 1) "" else "s", " -> p = ", fmt_p(search$claim$p_value)),
      list(rows = search$rows, rows_removed = length(search$rows), method = search$method, curve = search$curve)
    )
  } else {
    individual <- attack_result(
      "row_deletion", name, "survived", FALSE, search$claim,
      max_k / n, 0,
      paste0("survived removal of ", max_k, " influential row", if (max_k == 1) "" else "s"),
      list(rows = search$rows, rows_removed = length(search$rows), method = search$method, curve = search$curve)
    )
  }
  if (is.null(cluster)) return(individual)
  bind_attack_rows(list(
    individual,
    attack_group_deletion(model, claim, data, cluster, intensity, alpha, kill_rule)
  ))
}

attack_group_deletion <- function(model, claim, data, cluster, intensity, alpha, kill_rule) {
  if (!cluster %in% names(data)) {
    return(attack_result(
      "row_deletion", "Grouped row deletion", "unavailable", FALSE, claim,
      NA_real_, 0, "Grouping variable was unavailable; pass it through data =.",
      list(cluster = cluster, method = "grouped")
    ))
  }
  groups <- unique(stats::na.omit(data[[cluster]]))
  if (length(groups) < 3) {
    return(attack_result(
      "row_deletion", paste0("Grouped row deletion: ", cluster), "unavailable", FALSE,
      claim, NA_real_, 0, "At least three non-missing groups are required.",
      list(cluster = cluster, method = "grouped")
    ))
  }
  max_k <- switch(intensity,
    fast = 1,
    normal = min(3, max(1, ceiling(0.1 * length(groups)))),
    deep = min(6, max(1, ceiling(0.2 * length(groups)))),
    insane = min(10, max(1, ceiling(0.3 * length(groups))))
  )
  selected <- groups[FALSE]
  best <- NULL
  curve <- list()
  for (k in seq_len(max_k)) {
    remaining <- setdiff(groups, selected)
    trials <- lapply(remaining, function(group) {
      candidate_groups <- c(selected, group)
      rows <- which(data[[cluster]] %in% candidate_groups)
      evaluated <- evaluate_row_subset(model, claim, data, rows, alpha, kill_rule)
      if (!is.null(evaluated)) evaluated$groups <- candidate_groups
      evaluated
    })
    trials <- Filter(Negate(is.null), trials)
    if (!length(trials)) break
    scores <- vapply(trials, `[[`, numeric(1), "progress")
    best <- trials[[which.max(scores)]]
    selected <- best$groups
    curve[[k]] <- data.frame(
      groups_removed = length(selected),
      groups = paste(selected, collapse = ","),
      rows_removed = length(best$rows),
      estimate = best$claim$estimate,
      p_value = best$claim$p_value,
      killed = isTRUE(best$killed),
      stringsAsFactors = FALSE
    )
    if (isTRUE(best$killed)) break
  }
  if (is.null(best)) {
    return(attack_result(
      "row_deletion", paste0("Grouped row deletion: ", cluster), "unavailable", FALSE,
      claim, NA_real_, 0, "No valid grouped deletion refits were found.",
      list(cluster = cluster, method = "grouped")
    ))
  }
  distance <- length(best$groups) / length(groups)
  killed <- isTRUE(best$killed)
  attack_result(
    "row_deletion", paste0("Grouped row deletion: ", cluster),
    if (killed) "killed" else "survived", killed, best$claim,
    distance, if (killed) severity_from_distance(distance) else 0,
    paste0(
      if (killed) "remove " else "survived removal of ",
      length(best$groups), " group", if (length(best$groups) == 1) "" else "s",
      " (", length(best$rows), " rows) -> p = ", fmt_p(best$claim$p_value)
    ),
    list(
      cluster = cluster,
      groups = best$groups,
      rows = best$rows,
      method = "grouped",
      curve = do.call(rbind, curve)
    )
  )
}

attack_standard_error <- function(model, claim, data, intensity, alpha, kill_rule, seed) {
  rows <- list()
  if (requireNamespace("sandwich", quietly = TRUE) && requireNamespace("lmtest", quietly = TRUE)) {
    hc_types <- c("HC0", "HC1", "HC2", "HC3")
    hc_rows <- lapply(hc_types, function(type) {
      robust <- try(lmtest::coeftest(model, vcov. = sandwich::vcovHC(model, type = type)), silent = TRUE)
      if (inherits(robust, "try-error") || !claim$term %in% rownames(robust)) {
        return(NULL)
      }
      robust_claim <- claim
      robust_claim$std_error <- unname(robust[claim$term, 2])
      robust_claim$statistic <- unname(robust[claim$term, 3])
      robust_claim$p_value <- robust_p_value(model, unname(robust[claim$term, 3]), unname(robust[claim$term, 4]), claim$alternative %||% "two.sided")
      killed <- is_killed(robust_claim, claim, alpha, kill_rule)
      attack_result(
        "standard_error", paste(type, "robust standard errors"),
        if (killed) "killed" else "survived", killed, robust_claim,
        1, if (killed) robust_severity(type) else 0,
        paste0(type, " p = ", fmt_p(robust_claim$p_value)),
        list(method = type, vcov = "sandwich::vcovHC")
      )
    })
    rows <- c(rows, hc_rows)
  }

  b <- switch(intensity, fast = 80, normal = 200, deep = 500, insane = 1000)
  boot_p <- bootstrap_p_value(model, data, claim$term, b, seed, claim$alternative %||% "two.sided")
  boot_claim <- claim
  boot_claim$p_value <- boot_p
  killed <- is_killed(boot_claim, claim, alpha, kill_rule)
  rows <- c(rows, list(attack_result(
    "standard_error", "Bootstrap uncertainty",
    if (killed) "killed" else "survived", killed, boot_claim,
    1, if (killed) 24 else 0,
    paste0("bootstrap p approx = ", fmt_p(boot_p)),
    list(method = "bootstrap", B = b)
  )))
  bind_attack_rows(rows)
}

attack_covariate_drop <- function(model, claim, data, alpha, kill_rule) {
  formula <- stats::formula(model)
  labels <- attr(stats::terms(formula), "term.labels")
  raw_term <- claim_variable(model, claim$term)
  candidates <- setdiff(labels, raw_term)
  candidates <- candidates[!grepl(":", candidates, fixed = TRUE)]
  candidates <- candidates[!grepl("|", candidates, fixed = TRUE)]
  if (!length(candidates)) {
    return(attack_result("covariate", "Drop-one covariate", "unavailable", FALSE, claim, NA_real_, 0, "No adjustment covariates to drop.", list()))
  }
  rows <- lapply(candidates, function(covariate) {
    new_formula <- stats::update.formula(formula, paste(". ~ . -", covariate))
    fit <- try(refit_model(model, data, formula = new_formula), silent = TRUE)
    if (inherits(fit, "try-error")) {
      return(attack_result("covariate", paste0("Drop ", covariate), "unavailable", FALSE, claim, NA_real_, 0, "Refit failed.", list(covariate = covariate)))
    }
    claim_k <- try(extract_claim(fit, claim$term, alpha = alpha, alternative = claim$alternative %||% "two.sided", kill_rule = kill_rule), silent = TRUE)
    if (inherits(claim_k, "try-error")) {
      return(attack_result("covariate", paste0("Drop ", covariate), "unavailable", FALSE, claim, NA_real_, 0, "Claim unavailable after dropping covariate.", list(covariate = covariate)))
    }
    killed <- is_killed(claim_k, claim, alpha, kill_rule)
    attack_result(
      "covariate", paste0("Drop ", covariate),
      if (killed) "killed" else "survived", killed, claim_k,
      1, if (killed) 22 else 0,
      paste0("drop ", covariate, " -> p = ", fmt_p(claim_k$p_value)),
      list(covariate = covariate)
    )
  })
  bind_attack_rows(rows)
}

attack_specification <- function(model, claim, data, intensity, alpha, kill_rule) {
  formula <- stats::formula(model)
  outcome <- all.vars(formula)[1]
  labels <- attr(stats::terms(formula), "term.labels")
  target <- match_formula_term(claim$term, labels)
  if (is.null(target)) {
    return(attack_result(
      "specification", "Bounded specification search", "unavailable", FALSE, claim,
      NA_real_, 0, "Claim term could not be mapped to a simple formula term.", list()
    ))
  }
  adjustments <- setdiff(labels, target)
  adjustments <- adjustments[!grepl(":", adjustments, fixed = TRUE)]
  adjustments <- adjustments[!grepl("|", adjustments, fixed = TRUE)]
  if (!length(adjustments)) {
    return(attack_result(
      "specification", "Bounded specification search", "unavailable", FALSE, claim,
      NA_real_, 0, "No adjustment terms were available for bounded specification search.", list()
    ))
  }

  spec_limit <- switch(intensity, fast = 4, normal = 16, deep = 64, insane = 256)
  specs <- bounded_specification_grid(target, adjustments, spec_limit)
  rows <- lapply(seq_along(specs), function(i) {
    rhs_terms <- specs[[i]]
    omitted <- setdiff(adjustments, rhs_terms)
    if (!length(omitted)) return(NULL)
    spec_formula <- formula
    for (term_to_drop in omitted) {
      spec_formula <- stats::update.formula(spec_formula, paste(". ~ . -", term_to_drop))
    }
    fit <- try(refit_model(model, data, formula = spec_formula), silent = TRUE)
    if (inherits(fit, "try-error")) return(NULL)
    claim_s <- try(extract_claim(fit, claim$term, alpha = alpha, alternative = claim$alternative %||% "two.sided", kill_rule = kill_rule), silent = TRUE)
    if (inherits(claim_s, "try-error")) return(NULL)
    data.frame(
      formula = deparse(spec_formula),
      terms_kept = paste(rhs_terms, collapse = " + "),
      omitted = paste(omitted, collapse = ", "),
      omitted_count = length(omitted),
      estimate = claim_s$estimate,
      p_value = claim_s$p_value,
      killed = is_killed(claim_s, claim, alpha, kill_rule),
      stringsAsFactors = FALSE
    )
  })
  spec_tbl <- do.call(rbind, Filter(Negate(is.null), rows))
  if (is.null(spec_tbl) || !nrow(spec_tbl)) {
    return(attack_result(
      "specification", "Bounded specification search", "unavailable", FALSE, claim,
      NA_real_, 0, "No valid bounded specification refits were found.", list()
    ))
  }

  killed_tbl <- spec_tbl[spec_tbl$killed %in% TRUE, , drop = FALSE]
  if (nrow(killed_tbl)) {
    killed_tbl <- killed_tbl[order(killed_tbl$omitted_count, -killed_tbl$p_value), , drop = FALSE]
    best <- killed_tbl[1, , drop = FALSE]
    spec_claim <- claim
    spec_claim$estimate <- best$estimate
    spec_claim$p_value <- best$p_value
    distance <- best$omitted_count / max(1, length(adjustments))
    return(attack_result(
      "specification", "Bounded specification search", "killed", TRUE, spec_claim,
      distance, severity_from_distance(distance),
      paste0("claim survives ", sum(!spec_tbl$killed), " / ", nrow(spec_tbl), " bounded specs; killed when omitting ", best$omitted, " -> p = ", fmt_p(best$p_value)),
      list(specifications = spec_tbl)
    ))
  }

  best <- spec_tbl[which.max(spec_tbl$p_value), , drop = FALSE]
  spec_claim <- claim
  spec_claim$estimate <- best$estimate
  spec_claim$p_value <- best$p_value
  attack_result(
    "specification", "Bounded specification search", "survived", FALSE, spec_claim,
    1, 0,
    paste0("claim survived ", nrow(spec_tbl), " bounded specifications; max p = ", fmt_p(best$p_value)),
    list(specifications = spec_tbl)
  )
}

attack_missingness <- function(model, claim, data, alpha, kill_rule) {
  formula <- stats::formula(model)
  needed <- all.vars(formula)
  outcome <- needed[1]
  predictors <- setdiff(needed, outcome)
  if (!length(predictors) || !all(needed %in% names(data))) {
    return(attack_result(
      "missingness", "Missing-data imputation", "unavailable", FALSE, claim,
      NA_real_, 0, "Original data needed for missingness attack were unavailable.", list()
    ))
  }

  data <- as.data.frame(data[, needed, drop = FALSE])
  missing_predictors <- predictors[vapply(data[predictors], anyNA, logical(1))]
  if (!length(missing_predictors)) {
    return(attack_result(
      "missingness", "Missing-data imputation", "unavailable", FALSE, claim,
      NA_real_, 0, "No missing predictor values were found in the recoverable data.", list()
    ))
  }

  rows <- lapply(c("mean", "median", "mode_explicit", "indicator"), function(method) {
    imputed <- impute_missing_predictors(data, predictors, method)
    imputed <- imputed[!is.na(imputed[[outcome]]), , drop = FALSE]
    formula <- stats::formula(model)
    if (identical(method, "indicator")) {
      indicators <- paste0(missing_predictors, "_missing")
      formula <- stats::update.formula(
        formula,
        paste(". ~ . +", paste(indicators, collapse = " + "))
      )
    }
    fit <- try(refit_model(model, imputed, formula = formula), silent = TRUE)
    if (inherits(fit, "try-error")) {
      return(attack_result(
        "missingness", missingness_name(method), "unavailable", FALSE, claim,
        missingness_distance(method), 0, "Refit failed after missing-data perturbation.",
        list(method = method, missing_predictors = missing_predictors)
      ))
    }
    claim_m <- try(extract_claim(fit, claim$term, alpha = alpha, alternative = claim$alternative %||% "two.sided", kill_rule = kill_rule), silent = TRUE)
    if (inherits(claim_m, "try-error")) {
      return(attack_result(
        "missingness", missingness_name(method), "unavailable", FALSE, claim,
        missingness_distance(method), 0, "Claim unavailable after missing-data perturbation.",
        list(method = method, missing_predictors = missing_predictors)
      ))
    }
    killed <- is_killed(claim_m, claim, alpha, kill_rule)
    attack_result(
      "missingness", missingness_name(method),
      if (killed) "killed" else "survived", killed, claim_m,
      missingness_distance(method), if (killed) severity_from_distance(missingness_distance(method)) else 0,
      paste0(missingness_name(method), " -> p = ", fmt_p(claim_m$p_value)),
      list(
        method = method,
        missing_predictors = missing_predictors,
        imbalance = missingness_imbalance(data, predictors, claim_variable(model, claim$term))
      )
    )
  })
  bind_attack_rows(rows)
}

attack_measurement_error <- function(model, claim, data, intensity, alpha, kill_rule, seed) {
  outcome <- claim$outcome
  grid <- switch(intensity,
    fast = c(0.05, 0.1, 0.2, 0.35),
    normal = c(0.025, 0.05, 0.1, 0.15, 0.25, 0.35),
    deep = seq(0.025, 0.5, length.out = 10),
    insane = seq(0.01, 0.75, length.out = 16)
  )
  b <- switch(intensity, fast = 30, normal = 80, deep = 150, insane = 300)

  rows <- list(attack_continuous_noise(
    model, claim, data, variable = outcome, attack_name = "Outcome noise",
    target_label = "outcome", grid = grid, b = b, seed = seed + 1000,
    alpha = alpha, kill_rule = kill_rule
  ))

  numeric_predictors <- measurement_numeric_predictors(model, claim, data, intensity)
  for (i in seq_along(numeric_predictors)) {
    variable <- numeric_predictors[[i]]
    rows <- c(rows, list(attack_continuous_noise(
      model, claim, data, variable = variable,
      attack_name = paste0("Predictor noise: ", variable),
      target_label = paste0(variable, " predictor"), grid = grid, b = b,
      seed = seed + 1100 + i, alpha = alpha, kill_rule = kill_rule
    )))
  }

  term_variable <- claim_variable(model, claim$term)
  rows <- c(rows, list(attack_binary_flip(
    model, claim, data, variable = term_variable, intensity = intensity,
    seed = seed + 1500, alpha = alpha, kill_rule = kill_rule
  )))

  bind_attack_rows(rows)
}

attack_continuous_noise <- function(model, claim, data, variable, attack_name, target_label, grid, b, seed, alpha, kill_rule) {
  if (!variable %in% names(data) || !is.numeric(data[[variable]])) {
    return(attack_result("measurement_error", attack_name, "unavailable", FALSE, claim, NA_real_, 0, paste0(target_label, " is not numeric."), list(variable = variable)))
  }
  variable_sd <- stats::sd(data[[variable]], na.rm = TRUE)
  if (!is.finite(variable_sd) || variable_sd <= 0) {
    return(attack_result("measurement_error", attack_name, "unavailable", FALSE, claim, NA_real_, 0, paste0(target_label, " has no usable variation."), list(variable = variable)))
  }
  set.seed(seed)
  curve <- lapply(grid, function(level) {
    killed <- logical(b)
    p_values <- rep(NA_real_, b)
    for (i in seq_len(b)) {
      d <- data
      d[[variable]] <- d[[variable]] + stats::rnorm(nrow(d), 0, level * variable_sd)
      fit <- try(refit_model(model, d), silent = TRUE)
      if (inherits(fit, "try-error")) next
      c_i <- try(extract_claim(fit, claim$term, alpha = alpha, alternative = claim$alternative %||% "two.sided", kill_rule = kill_rule), silent = TRUE)
      if (inherits(c_i, "try-error")) next
      killed[i] <- is_killed(c_i, claim, alpha, kill_rule)
      p_values[i] <- c_i$p_value
    }
    data.frame(level = level, kill_rate = mean(killed, na.rm = TRUE), p_value = stats::median(p_values, na.rm = TRUE))
  })
  curve <- do.call(rbind, curve)
  hit <- curve[curve$kill_rate >= 0.5, , drop = FALSE]
  if (nrow(hit)) {
    row <- hit[1, ]
    noise_claim <- claim
    noise_claim$p_value <- row$p_value
    return(attack_result(
      "measurement_error", attack_name, "killed", TRUE, noise_claim,
      row$level, severity_from_distance(row$level),
      paste0("50% kill rate at noise SD = ", fmt_num(row$level), " x ", target_label, " SD"),
      list(curve = curve, variable = variable, method = "gaussian_noise")
    ))
  }
  last <- curve[nrow(curve), ]
  noise_claim <- claim
  noise_claim$p_value <- last$p_value
  attack_result(
    "measurement_error", attack_name, "survived", FALSE, noise_claim,
    max(grid), 0,
    paste0("no 50% kill rate up to noise SD = ", fmt_num(max(grid)), " x ", target_label, " SD"),
    list(curve = curve, variable = variable, method = "gaussian_noise")
  )
}

measurement_numeric_predictors <- function(model, claim, data, intensity) {
  labels <- attr(stats::terms(stats::formula(model)), "term.labels")
  raw_labels <- unique(vapply(labels, raw_variable_from_term, character(1)))
  predictors <- setdiff(raw_labels, claim$outcome)
  predictors <- predictors[predictors %in% names(data)]
  predictors <- predictors[vapply(predictors, function(variable) {
    is.numeric(data[[variable]]) && !is_binary_variable(data[[variable]])
  }, logical(1))]
  if (!length(predictors)) return(character())
  term_variable <- claim_variable(model, claim$term)
  predictors <- unique(c(intersect(term_variable, predictors), setdiff(predictors, term_variable)))
  limit <- switch(intensity, fast = 1, normal = 2, deep = 4, insane = 6)
  predictors[seq_len(min(limit, length(predictors)))]
}

attack_binary_flip <- function(model, claim, data, variable, intensity, seed, alpha, kill_rule) {
  if (!variable %in% names(data) || !is_binary_variable(data[[variable]])) {
    return(attack_result(
      "measurement_error", "Binary label flip", "unavailable", FALSE, claim,
      NA_real_, 0, "Claim term is not a simple binary variable.", list(variable = variable)
    ))
  }
  grid <- switch(intensity,
    fast = c(0.01, 0.025, 0.05, 0.1),
    normal = c(0.01, 0.025, 0.05, 0.075, 0.1, 0.15),
    deep = c(0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.15, 0.2),
    insane = c(0.005, 0.01, 0.02, 0.035, 0.05, 0.075, 0.1, 0.15, 0.2, 0.3)
  )
  b <- switch(intensity, fast = 30, normal = 80, deep = 150, insane = 300)
  set.seed(seed)
  values <- unique(stats::na.omit(data[[variable]]))
  curve <- lapply(grid, function(level) {
    killed <- logical(b)
    p_values <- rep(NA_real_, b)
    flip_n <- max(1, floor(level * nrow(data)))
    for (i in seq_len(b)) {
      d <- data
      idx <- sample.int(nrow(d), size = min(flip_n, nrow(d)), replace = FALSE)
      flipped <- d[[variable]]
      first <- flipped[idx] == values[1]
      flipped[idx[first]] <- values[2]
      flipped[idx[!first]] <- values[1]
      d[[variable]] <- flipped
      fit <- try(refit_model(model, d), silent = TRUE)
      if (inherits(fit, "try-error")) next
      c_i <- try(extract_claim(fit, claim$term, alpha = alpha, alternative = claim$alternative %||% "two.sided", kill_rule = kill_rule), silent = TRUE)
      if (inherits(c_i, "try-error")) next
      killed[i] <- is_killed(c_i, claim, alpha, kill_rule)
      p_values[i] <- c_i$p_value
    }
    data.frame(level = level, kill_rate = mean(killed, na.rm = TRUE), p_value = stats::median(p_values, na.rm = TRUE))
  })
  curve <- do.call(rbind, curve)
  hit <- curve[curve$kill_rate >= 0.5, , drop = FALSE]
  flip_claim <- claim
  if (nrow(hit)) {
    row <- hit[1, ]
    flip_claim$p_value <- row$p_value
    return(attack_result(
      "measurement_error", "Binary label flip", "killed", TRUE, flip_claim,
      row$level, severity_from_distance(row$level),
      paste0("50% kill rate after flipping ", fmt_pct(row$level), " of ", variable, " labels"),
      list(curve = curve, variable = variable, method = "binary_flip")
    ))
  }
  last <- curve[nrow(curve), ]
  flip_claim$p_value <- last$p_value
  attack_result(
    "measurement_error", "Binary label flip", "survived", FALSE, flip_claim,
    max(grid), 0,
    paste0("no 50% kill rate after flipping up to ", fmt_pct(max(grid)), " of ", variable, " labels"),
    list(curve = curve, variable = variable, method = "binary_flip")
  )
}

is_binary_variable <- function(x) {
  values <- unique(stats::na.omit(x))
  length(values) == 2
}

attack_placebo <- function(model, claim, data, intensity, seed, placebo_outcomes = character()) {
  variable <- claim_variable(model, claim$term)
  if (!variable %in% names(data) || grepl(":", claim$term, fixed = TRUE)) {
    return(attack_result("placebo", "Treatment-label permutation", "unavailable", FALSE, claim, NA_real_, 0, "Term cannot be safely mapped to one raw variable.", list()))
  }
  b <- switch(intensity, fast = 80, normal = 200, deep = 500, insane = 1000)
  rows <- list(
    attack_placebo_permutation(model, claim, data, variable, b, seed + 2000),
    attack_placebo_fake_predictor(model, claim, data, variable, b, seed + 2500)
  )
  if (length(placebo_outcomes)) {
    rows <- c(rows, attack_placebo_outcomes(model, claim, data, placebo_outcomes))
  }
  bind_attack_rows(rows)
}

attack_placebo_outcomes <- function(model, claim, data, placebo_outcomes) {
  lapply(unique(placebo_outcomes), function(placebo_outcome) {
    attack_placebo_outcome(model, claim, data, placebo_outcome)
  })
}

attack_placebo_outcome <- function(model, claim, data, placebo_outcome) {
  if (!is.character(placebo_outcome) || length(placebo_outcome) != 1 || is.na(placebo_outcome) || !nzchar(placebo_outcome)) {
    return(attack_result(
      "placebo", "User-supplied placebo outcome", "unavailable", FALSE, claim,
      NA_real_, 0, "Placebo outcome names must be non-empty character values.",
      list(method = "placebo_outcome", placebo_outcome = placebo_outcome)
    ))
  }
  if (!placebo_outcome %in% names(data)) {
    return(attack_result(
      "placebo", paste0("Placebo outcome: ", placebo_outcome), "unavailable", FALSE, claim,
      NA_real_, 0, "Requested placebo outcome was not available in recoverable data; pass data = with that column.",
      list(method = "placebo_outcome", placebo_outcome = placebo_outcome)
    ))
  }
  formula <- stats::formula(model)
  labels <- attr(stats::terms(formula), "term.labels")
  if (!length(labels)) {
    return(attack_result(
      "placebo", paste0("Placebo outcome: ", placebo_outcome), "unavailable", FALSE, claim,
      NA_real_, 0, "Original model has no predictors to reuse for a placebo outcome refit.",
      list(method = "placebo_outcome", placebo_outcome = placebo_outcome)
    ))
  }
  placebo_formula <- stats::as.formula(paste(placebo_outcome, "~", paste(labels, collapse = " + ")))
  environment(placebo_formula) <- environment(formula)
  fit <- try(refit_model(model, data, formula = placebo_formula), silent = TRUE)
  if (inherits(fit, "try-error")) {
    return(attack_result(
      "placebo", paste0("Placebo outcome: ", placebo_outcome), "unavailable", FALSE, claim,
      NA_real_, 0, "Refit failed for the user-supplied placebo outcome.",
      list(method = "placebo_outcome", placebo_outcome = placebo_outcome)
    ))
  }
  placebo_claim <- try(extract_claim(
    fit,
    claim$term,
    alpha = claim$alpha,
    alternative = claim$alternative %||% "two.sided",
    kill_rule = claim$kill_rule
  ), silent = TRUE)
  if (inherits(placebo_claim, "try-error")) {
    return(attack_result(
      "placebo", paste0("Placebo outcome: ", placebo_outcome), "unavailable", FALSE, claim,
      NA_real_, 0, "Claim term was unavailable in the placebo outcome refit.",
      list(method = "placebo_outcome", placebo_outcome = placebo_outcome)
    ))
  }
  placebo_claim$outcome <- placebo_outcome
  stronger <- is.finite(placebo_claim$p_value) &&
    placebo_claim$p_value <= claim$p_value &&
    abs(placebo_claim$estimate) >= abs(claim$estimate)
  attack_result(
    "placebo", paste0("Placebo outcome: ", placebo_outcome),
    if (stronger) "killed" else "survived", stronger, placebo_claim,
    if (stronger) 0.1 else 1, if (stronger) 18 else 0,
    paste0("placebo outcome p = ", fmt_p(placebo_claim$p_value), "; estimate = ", fmt_num(placebo_claim$estimate)),
    list(method = "placebo_outcome", placebo_outcome = placebo_outcome, placebo_rate = if (stronger) 1 else 0)
  )
}

attack_split_stability <- function(model, claim, data, intensity, alpha, kill_rule, seed) {
  n <- nrow(data)
  if (!is.finite(n) || n < 12) {
    return(attack_result(
      "split", "Train/test split stability", "unavailable", FALSE, claim,
      NA_real_, 0, "Not enough rows for repeated train/test split refits.", list()
    ))
  }

  grid <- switch(intensity,
    fast = c(0.2, 0.3),
    normal = c(0.1, 0.2, 0.3),
    deep = c(0.1, 0.15, 0.2, 0.25, 0.3, 0.4),
    insane = c(0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5)
  )
  b <- switch(intensity, fast = 30, normal = 80, deep = 150, insane = 300)
  min_train <- max(8, length(stats::coef(model)) + 3)

  variable <- raw_variable_from_term(claim$term)
  rows <- list(
    attack_split_stability_variant(
      model, claim, data, grid, b, min_train, alpha, kill_rule, seed + 3000,
      attack_name = "Random train/test split stability",
      method = "random_train_test_split",
      sampler = random_split_sampler
    )
  )
  rows <- c(rows, list(
    attack_stratified_split_stability(
      model, claim, data, variable, grid, b, min_train, alpha, kill_rule, seed + 3500
    )
  ))
  bind_attack_rows(rows)
}

attack_split_stability_variant <- function(model,
                                           claim,
                                           data,
                                           grid,
                                           b,
                                           min_train,
                                           alpha,
                                           kill_rule,
                                           seed,
                                           attack_name,
                                           method,
                                           sampler) {
  n <- nrow(data)
  set.seed(seed)
  curve <- lapply(grid, function(level) {
    train_n <- n - max(1, floor(level * n))
    if (train_n < min_train) {
      return(data.frame(
        level = level, train_rows = train_n, holdout_rows = n - train_n,
        kill_rate = NA_real_, estimate = NA_real_, p_value = NA_real_,
        valid_refits = 0L, stringsAsFactors = FALSE
      ))
    }
    killed <- logical(b)
    p_values <- rep(NA_real_, b)
    estimates <- rep(NA_real_, b)
    for (i in seq_len(b)) {
      train_idx <- sampler(data, train_n)
      fit <- try(refit_model(model, data[train_idx, , drop = FALSE]), silent = TRUE)
      if (inherits(fit, "try-error")) next
      c_i <- try(extract_claim(fit, claim$term, alpha = alpha, alternative = claim$alternative %||% "two.sided", kill_rule = kill_rule), silent = TRUE)
      if (inherits(c_i, "try-error")) next
      p_values[i] <- c_i$p_value
      estimates[i] <- c_i$estimate
      killed[i] <- is_killed(c_i, claim, alpha, kill_rule)
    }
    valid <- is.finite(p_values)
    data.frame(
      level = level,
      train_rows = train_n,
      holdout_rows = n - train_n,
      kill_rate = if (any(valid)) mean(killed[valid]) else NA_real_,
      estimate = if (any(is.finite(estimates))) stats::median(estimates, na.rm = TRUE) else NA_real_,
      p_value = if (any(valid)) stats::median(p_values[valid], na.rm = TRUE) else NA_real_,
      valid_refits = sum(valid),
      stringsAsFactors = FALSE
    )
  })
  curve <- do.call(rbind, curve)
  usable <- curve[is.finite(curve$kill_rate), , drop = FALSE]
  if (!nrow(usable)) {
    return(attack_result(
      "split", attack_name, "unavailable", FALSE, claim,
      NA_real_, 0, "No valid split refits were found.", list(curve = curve, B = b)
    ))
  }

  hit <- usable[usable$kill_rate >= 0.5, , drop = FALSE]
  split_claim <- claim
  if (nrow(hit)) {
    row <- hit[order(hit$level), , drop = FALSE][1, ]
    split_claim$estimate <- row$estimate
    split_claim$p_value <- row$p_value
    return(attack_result(
      "split", attack_name, "killed", TRUE, split_claim,
      row$level, severity_from_distance(row$level),
      paste0("50% kill rate after holding out ", fmt_pct(row$level), " of rows"),
      list(curve = curve, B = b, method = method)
    ))
  }

  worst <- usable[which.max(usable$kill_rate), , drop = FALSE]
  split_claim$estimate <- worst$estimate
  split_claim$p_value <- worst$p_value
  attack_result(
    "split", attack_name, "survived", FALSE, split_claim,
    max(usable$level), 0,
    paste0("no 50% kill rate across split refits; max kill rate ", fmt_pct(worst$kill_rate), " at ", fmt_pct(worst$level), " holdout"),
    list(curve = curve, B = b, method = method)
  )
}

random_split_sampler <- function(data, train_n) {
  sort(sample.int(nrow(data), size = train_n, replace = FALSE))
}

attack_stratified_split_stability <- function(model, claim, data, variable, grid, b, min_train, alpha, kill_rule, seed) {
  if (!variable %in% names(data) || !can_stratify_split(data[[variable]])) {
    return(attack_result(
      "split", "Stratified train/test split stability", "unavailable", FALSE, claim,
      NA_real_, 0, "Claim term could not be mapped to a categorical stratification variable.",
      list(variable = variable, method = "stratified_train_test_split")
    ))
  }
  attack_split_stability_variant(
    model, claim, data, grid, b, min_train, alpha, kill_rule, seed,
    attack_name = "Stratified train/test split stability",
    method = "stratified_train_test_split",
    sampler = function(data, train_n) stratified_split_sampler(data, train_n, variable)
  )
}

can_stratify_split <- function(x) {
  values <- stats::na.omit(x)
  if (!length(values)) return(FALSE)
  groups <- table(values)
  length(groups) >= 2 && length(groups) <= 8 && all(groups >= 4)
}

stratified_split_sampler <- function(data, train_n, variable) {
  n <- nrow(data)
  holdout_n <- n - train_n
  strata <- split(seq_len(n), data[[variable]], drop = TRUE)
  holdout <- integer()
  for (idx in strata) {
    stratum_holdout <- floor(length(idx) * holdout_n / n)
    if (stratum_holdout > 0) {
      holdout <- c(holdout, sample(idx, size = min(stratum_holdout, length(idx) - 1), replace = FALSE))
    }
  }
  remaining <- setdiff(seq_len(n), holdout)
  needed <- holdout_n - length(holdout)
  if (needed > 0) {
    protected <- unlist(lapply(strata, function(idx) {
      kept <- setdiff(idx, holdout)
      if (length(kept) <= 1) kept else integer()
    }), use.names = FALSE)
    candidates <- setdiff(remaining, protected)
    if (length(candidates) < needed) candidates <- remaining
    if (length(candidates) >= needed) {
      holdout <- c(holdout, sample(candidates, size = needed, replace = FALSE))
    }
  }
  if (length(holdout) > holdout_n) {
    holdout <- sample(holdout, size = holdout_n, replace = FALSE)
  }
  sort(setdiff(seq_len(n), holdout))
}

attack_placebo_permutation <- function(model, claim, data, variable, b, seed) {
  set.seed(seed)
  stronger <- logical(b)
  p_values <- rep(NA_real_, b)
  estimates <- rep(NA_real_, b)
  for (i in seq_len(b)) {
    d <- data
    d[[variable]] <- sample(d[[variable]])
    fit <- try(refit_model(model, d), silent = TRUE)
    if (inherits(fit, "try-error")) next
    c_i <- try(extract_claim(fit, claim$term, alpha = claim$alpha, alternative = claim$alternative %||% "two.sided", kill_rule = claim$kill_rule), silent = TRUE)
    if (inherits(c_i, "try-error")) next
    estimates[i] <- c_i$estimate
    p_values[i] <- c_i$p_value
    stronger[i] <- is.finite(c_i$p_value) &&
      c_i$p_value <= claim$p_value &&
      abs(c_i$estimate) >= abs(claim$estimate)
  }
  rate <- mean(stronger, na.rm = TRUE)
  placebo_claim <- claim
  placebo_claim$p_value <- stats::median(p_values, na.rm = TRUE)
  killed <- is.finite(rate) && rate >= 0.1
  attack_result(
    "placebo", "Treatment-label permutation",
    if (killed) "killed" else "survived", killed, placebo_claim,
    rate, if (killed) 18 else 0,
    paste0(fmt_pct(rate), " of placebo labels were at least as strong as original"),
    list(B = b, placebo_rate = rate, method = "label_permutation", curve = placebo_curve(p_values, estimates, stronger))
  )
}

attack_placebo_fake_predictor <- function(model, claim, data, variable, b, seed) {
  if (!is.numeric(data[[variable]])) {
    return(attack_result(
      "placebo", "Fake predictor placebo", "unavailable", FALSE, claim,
      NA_real_, 0, "Fake-predictor placebo currently supports simple numeric or binary terms.",
      list(variable = variable, method = "fake_predictor")
    ))
  }
  formula <- stats::formula(model)
  labels <- attr(stats::terms(formula), "term.labels")
  target <- match_formula_term(claim$term, labels)
  if (is.null(target)) {
    return(attack_result(
      "placebo", "Fake predictor placebo", "unavailable", FALSE, claim,
      NA_real_, 0, "Claim term could not be mapped to a simple formula term.",
      list(variable = variable, method = "fake_predictor")
    ))
  }

  fake_name <- unique_fake_predictor_name(data)
  outcome <- all.vars(formula)[1]
  rhs <- c(fake_name, setdiff(labels, target))
  fake_formula <- stats::as.formula(paste(outcome, "~", paste(rhs, collapse = " + ")))
  environment(fake_formula) <- environment(formula)

  set.seed(seed)
  stronger <- logical(b)
  p_values <- rep(NA_real_, b)
  estimates <- rep(NA_real_, b)
  for (i in seq_len(b)) {
    d <- data
    d[[fake_name]] <- sample(d[[variable]], size = nrow(d), replace = FALSE)
    fit <- try(refit_model(model, d, formula = fake_formula), silent = TRUE)
    if (inherits(fit, "try-error")) next
    c_i <- try(extract_claim(fit, fake_name, alpha = claim$alpha, alternative = claim$alternative %||% "two.sided", kill_rule = claim$kill_rule), silent = TRUE)
    if (inherits(c_i, "try-error")) next
    estimates[i] <- c_i$estimate
    p_values[i] <- c_i$p_value
    stronger[i] <- is.finite(c_i$p_value) &&
      c_i$p_value <= claim$p_value &&
      abs(c_i$estimate) >= abs(claim$estimate)
  }
  rate <- mean(stronger, na.rm = TRUE)
  placebo_claim <- claim
  placebo_claim$term <- fake_name
  placebo_claim$p_value <- stats::median(p_values, na.rm = TRUE)
  placebo_claim$estimate <- stats::median(estimates, na.rm = TRUE)
  killed <- is.finite(rate) && rate >= 0.1
  attack_result(
    "placebo", "Fake predictor placebo",
    if (killed) "killed" else "survived", killed, placebo_claim,
    rate, if (killed) 20 else 0,
    paste0(fmt_pct(rate), " of random fake predictors were at least as strong as original"),
    list(B = b, placebo_rate = rate, method = "fake_predictor", source_variable = variable, curve = placebo_curve(p_values, estimates, stronger))
  )
}

placebo_curve <- function(p_values, estimates, stronger) {
  data.frame(
    replicate = seq_along(p_values),
    estimate = estimates,
    p_value = p_values,
    killed = stronger,
    stringsAsFactors = FALSE
  )
}

unique_fake_predictor_name <- function(data) {
  base <- "falsifyr_fake_predictor"
  if (!base %in% names(data)) return(base)
  i <- 1
  repeat {
    candidate <- paste0(base, "_", i)
    if (!candidate %in% names(data)) return(candidate)
    i <- i + 1
  }
}

attack_htest_limitations <- function(claim, families) {
  output_families <- vapply(families, htest_output_family, character(1))
  rows <- lapply(unique(output_families), function(family) {
    attack_result(
      family,
      paste0(family_label(family), " unavailable"),
      "unavailable",
      FALSE,
      claim,
      NA_real_,
      0,
      "htest objects do not retain enough original data for this perturbation; supply a fitted lm/glm model for full attacks.",
      list(model_class = "htest")
    )
  })
  bind_attack_rows(rows)
}

htest_output_family <- function(family) {
  if (identical(family, "covariate_drop")) return("covariate")
  family
}

recover_model_data <- function(model, data = NULL, caller = parent.frame()) {
  if (!is.null(data)) {
    needed <- all.vars(stats::formula(model))
    return(stats::na.omit(as.data.frame(data)[, needed, drop = FALSE]))
  }
  if (inherits(model, "coxph")) {
    called_data <- try(model$call$data, silent = TRUE)
    if (!inherits(called_data, "try-error") && !is.null(called_data)) {
      original <- try(eval(called_data, envir = caller), silent = TRUE)
      needed <- all.vars(stats::formula(model))
      if (!inherits(original, "try-error") && is.data.frame(original) && all(needed %in% names(original))) {
        return(stats::na.omit(as.data.frame(original)[, needed, drop = FALSE]))
      }
    }
  }
  stats::model.frame(model)
}

recover_original_data <- function(model, data = NULL, caller = parent.frame(), extra_vars = character()) {
  needed <- all.vars(stats::formula(model))
  vars <- unique(c(needed, extra_vars))
  if (!is.null(data)) {
    available <- intersect(vars, names(as.data.frame(data)))
    return(as.data.frame(data)[, available, drop = FALSE])
  }
  called_data <- try(model$call$data, silent = TRUE)
  if (!inherits(called_data, "try-error") && !is.null(called_data)) {
    original <- try(eval(called_data, envir = caller), silent = TRUE)
    if (!inherits(original, "try-error") && is.data.frame(original) && all(needed %in% names(original))) {
      available <- intersect(vars, names(original))
      return(as.data.frame(original[, available, drop = FALSE]))
    }
  }
  stats::model.frame(model)
}

normalize_placebo_outcomes <- function(outcome) {
  if (is.null(outcome)) return(character())
  if (!is.character(outcome)) {
    stop("`outcome` must be a character vector of placebo outcome names.", call. = FALSE)
  }
  outcome <- outcome[!is.na(outcome) & nzchar(outcome)]
  unique(outcome)
}

normalize_cluster <- function(cluster) {
  if (is.null(cluster)) return(NULL)
  if (!is.character(cluster) || length(cluster) != 1 || is.na(cluster) || !nzchar(cluster)) {
    stop("`cluster` must be NULL or one non-empty column name.", call. = FALSE)
  }
  cluster
}

attach_cluster_data <- function(model_data, original_data, cluster) {
  if (is.null(cluster) || cluster %in% names(model_data) || !cluster %in% names(original_data)) {
    return(model_data)
  }
  model_rows <- rownames(model_data)
  original_rows <- rownames(original_data)
  matched <- match(model_rows, original_rows)
  if (anyNA(matched)) return(model_data)
  model_data[[cluster]] <- original_data[[cluster]][matched]
  model_data
}

supports_refit <- function(model) {
  inherits(model, c("lm", "glm", "aov", "merMod", "coxph"))
}

refit_call_args <- function(formula, data, ...) {
  dots <- list(...)
  specials <- refit_special_args(data)
  specials <- specials[setdiff(names(specials), names(dots))]
  c(list(formula = formula_without_offsets(formula), data = data), specials, dots)
}

refit_special_args <- function(data) {
  weights <- try(stats::model.weights(data), silent = TRUE)
  offset <- try(stats::model.offset(data), silent = TRUE)
  args <- list()
  if (!inherits(weights, "try-error") && !is.null(weights)) args$weights <- weights
  if (!inherits(offset, "try-error") && !is.null(offset)) args$offset <- offset
  args
}

formula_without_offsets <- function(formula) {
  terms <- stats::terms(formula)
  if (is.null(attr(terms, "offset"))) return(formula)
  response <- paste(deparse(formula[[2]], width.cutoff = 500), collapse = "")
  labels <- attr(terms, "term.labels")
  intercept <- attr(terms, "intercept")
  rhs <- labels
  if (identical(intercept, 0L)) rhs <- c("0", rhs)
  if (!length(rhs)) rhs <- if (identical(intercept, 0L)) "0" else "1"
  rebuilt <- stats::as.formula(paste(response, "~", paste(rhs, collapse = " + ")))
  environment(rebuilt) <- environment(formula)
  rebuilt
}

default_attack_families <- function(profile = "default") {
  switch(profile,
    clinical = c("missingness", "standard_error", "measurement_error", "row_deletion", "covariate_drop", "placebo", "specification"),
    social_science = c("specification", "covariate_drop", "placebo", "row_deletion", "standard_error", "missingness", "measurement_error"),
    prediction = c("split", "measurement_error", "placebo", "row_deletion", "standard_error", "specification"),
    strict = c("row_deletion", "standard_error", "missingness", "measurement_error", "placebo", "covariate_drop", "specification"),
    fast = c("row_deletion", "standard_error", "covariate_drop"),
    c("row_deletion", "standard_error", "covariate_drop", "missingness", "measurement_error", "placebo", "specification")
  )
}

claim_registry <- function() {
  c(
    lm = "extract_claim.lm",
    glm = "extract_claim.glm",
    aov = "extract_claim.aov",
    anova = "extract_claim.anova",
    htest = "extract_claim.htest",
    lmerMod = "extract_claim.merMod",
    glmerMod = "extract_claim.merMod",
    coxph = "extract_claim.coxph"
  )
}

attack_registry <- function() {
  c(
    row_deletion = "Row deletion and influence",
    standard_error = "Standard error and bootstrap",
    covariate_drop = "Covariate dependence",
    missingness = "Missing data",
    measurement_error = "Measurement error",
    placebo = "Placebo",
    specification = "Bounded specification",
    split = "Split stability"
  )
}

known_attack_families <- function() {
  names(attack_registry())
}

run_attack_family <- function(family,
                              model,
                              claim,
                              model_data,
                              original_data,
                              row_data,
                              cluster,
                              intensity,
                              alpha,
                              kill_rule,
                              seed,
                              placebo_outcomes,
                              verbose) {
  progress_message <- switch(family,
    row_deletion = "Running row-deletion attack.",
    standard_error = "Running standard-error attack.",
    covariate_drop = "Running covariate-dependence attack.",
    specification = "Running bounded specification attack.",
    missingness = "Running missing-data attack.",
    measurement_error = "Running measurement-error attack.",
    placebo = "Running placebo attack.",
    split = "Running split-stability attack."
  )
  attack_progress(verbose, intensity, progress_message)
  switch(family,
    row_deletion = attack_row_deletion(model, claim, row_data, intensity, alpha, kill_rule, cluster),
    standard_error = attack_standard_error(model, claim, model_data, intensity, alpha, kill_rule, seed),
    covariate_drop = attack_covariate_drop(model, claim, model_data, alpha, kill_rule),
    specification = attack_specification(model, claim, model_data, intensity, alpha, kill_rule),
    missingness = attack_missingness(model, claim, original_data, alpha, kill_rule),
    measurement_error = attack_measurement_error(model, claim, model_data, intensity, alpha, kill_rule, seed),
    placebo = attack_placebo(model, claim, original_data, intensity, seed, placebo_outcomes),
    split = attack_split_stability(model, claim, model_data, intensity, alpha, kill_rule, seed)
  )
}

parallel_attack_map <- function(families, fun, enabled) {
  if (!isTRUE(enabled) || length(families) < 2) return(lapply(families, fun))
  worker_environment <- new.env(parent = baseenv())
  captured_environment <- environment(fun)
  captured_names <- ls(captured_environment, all.names = TRUE)
  for (name in captured_names) {
    assign(
      name,
      get(name, envir = captured_environment, inherits = FALSE),
      envir = worker_environment
    )
  }
  namespace <- asNamespace("falsifyr")
  function_names <- ls(namespace, all.names = TRUE)
  function_names <- function_names[vapply(function_names, function(name) {
    is.function(get(name, envir = namespace, inherits = FALSE))
  }, logical(1))]
  for (name in function_names) {
    worker_function <- get(name, envir = namespace, inherits = FALSE)
    environment(worker_function) <- worker_environment
    assign(name, worker_function, envir = worker_environment)
  }
  environment(fun) <- worker_environment
  workers <- min(2L, length(families))
  cluster <- parallel::makePSOCKcluster(workers)
  on.exit(parallel::stopCluster(cluster), add = TRUE)
  parallel::parLapply(cluster, families, fun)
}

attack_progress <- function(verbose, intensity, message) {
  if (isTRUE(verbose) && identical(intensity, "insane")) {
    cli::cli_inform(message)
  }
}

attack_family_aliases <- function() {
  c(
    row_deletion = "row_deletion",
    row = "row_deletion",
    influence = "row_deletion",
    robust_se = "standard_error",
    se = "standard_error",
    standard_error = "standard_error",
    uncertainty = "standard_error",
    bootstrap = "standard_error",
    covariate = "covariate_drop",
    covariate_drop = "covariate_drop",
    drop_one = "covariate_drop",
    missing = "missingness",
    missingness = "missingness",
    missing_data = "missingness",
    noise = "measurement_error",
    measurement_error = "measurement_error",
    measurement = "measurement_error",
    placebo = "placebo",
    permutation = "placebo",
    split = "split",
    split_stability = "split",
    train_test = "split",
    train_test_split = "split",
    prediction_split = "split",
    specification = "specification",
    specs = "specification"
  )
}

normalize_attack_families <- function(attacks = NULL, profile = "default") {
  if (is.null(attacks)) {
    return(list(families = default_attack_families(profile), unknown = character()))
  }
  aliases <- attack_family_aliases()
  normalized <- unname(aliases[attacks])
  unknown <- attacks[is.na(normalized)]
  families <- unique(stats::na.omit(normalized))
  if (length(unknown)) {
    cli::cli_text("Skipping unknown attack famil{?y/ies}: {paste(unknown, collapse = ', ')}.")
  }
  list(families = families, unknown = unknown)
}

choose_term <- function(coefs, term) {
  terms <- setdiff(rownames(coefs), "(Intercept)")
  if (is.null(term)) {
    if (!length(terms)) stop("No non-intercept term is available.", call. = FALSE)
    return(terms[1])
  }
  if (!term %in% rownames(coefs)) {
    stop("Term `", term, "` was not found. Available terms: ",
         paste(terms, collapse = ", "), call. = FALSE)
  }
  term
}

safe_confint <- function(model, term, alpha) {
  ci <- try(stats::confint.default(model, parm = term, level = 1 - alpha), silent = TRUE)
  if (inherits(ci, "try-error")) {
    ci <- try(stats::confint(model, parm = term, level = 1 - alpha), silent = TRUE)
  }
  if (inherits(ci, "try-error")) return(c(NA_real_, NA_real_))
  if (is.null(dim(ci))) return(unname(as.numeric(ci[1:2])))
  unname(as.numeric(ci[1, 1:2]))
}

rank_rows_for_claim <- function(model, claim) {
  n <- stats::nobs(model)
  dfb <- try(stats::dfbetas(model), silent = TRUE)
  if (!inherits(dfb, "try-error") && claim$term %in% colnames(dfb)) {
    influence <- dfb[, claim$term]
    return(order(sign(claim$estimate) * influence, decreasing = TRUE, na.last = NA))
  }
  cooks <- try(stats::cooks.distance(model), silent = TRUE)
  if (!inherits(cooks, "try-error")) return(order(cooks, decreasing = TRUE, na.last = NA))
  seq_len(n)
}

row_deletion_ranked_search <- function(model, claim, data, rank, max_k, alpha, kill_rule) {
  best <- NULL
  curve <- list()
  for (k in seq_len(max_k)) {
    evaluated <- evaluate_row_subset(model, claim, data, rank[seq_len(k)], alpha, kill_rule)
    if (is.null(evaluated)) next
    curve <- c(curve, list(row_curve_step(evaluated)))
    best <- evaluated
    if (isTRUE(evaluated$killed)) return(add_row_search_method(add_row_search_curve(evaluated, curve), "ranked"))
  }
  add_row_search_method(add_row_search_curve(best, curve), "ranked")
}

row_deletion_greedy_search <- function(model, claim, data, rank, max_k, candidate_n, alpha, kill_rule) {
  candidates <- rank[seq_len(min(candidate_n, length(rank)))]
  selected <- integer()
  best <- NULL
  curve <- list()
  for (k in seq_len(max_k)) {
    remaining <- setdiff(candidates, selected)
    if (!length(remaining)) break
    trials <- lapply(remaining, function(row) {
      evaluate_row_subset(model, claim, data, c(selected, row), alpha, kill_rule)
    })
    trials <- Filter(Negate(is.null), trials)
    if (!length(trials)) break
    scores <- vapply(trials, `[[`, numeric(1), "progress")
    chosen <- trials[[which.max(scores)]]
    selected <- chosen$rows
    best <- chosen
    curve <- c(curve, list(row_curve_step(chosen)))
    if (isTRUE(chosen$killed)) return(add_row_search_method(add_row_search_curve(chosen, curve), "greedy"))
  }
  add_row_search_method(add_row_search_curve(best, curve), "greedy")
}

row_deletion_beam_search <- function(model, claim, data, rank, max_k, candidate_n, beam_width, alpha, kill_rule) {
  candidates <- rank[seq_len(min(candidate_n, length(rank)))]
  beam <- list(integer())
  best <- NULL
  curve <- list()
  for (k in seq_len(max_k)) {
    trials <- list()
    seen <- character()
    for (subset in beam) {
      for (row in setdiff(candidates, subset)) {
        rows <- sort(c(subset, row))
        key <- paste(rows, collapse = ",")
        if (key %in% seen) next
        seen <- c(seen, key)
        evaluated <- evaluate_row_subset(model, claim, data, rows, alpha, kill_rule)
        if (!is.null(evaluated)) trials <- c(trials, list(evaluated))
      }
    }
    if (!length(trials)) break
    scores <- vapply(trials, `[[`, numeric(1), "progress")
    order_idx <- order(scores, decreasing = TRUE)
    trials <- trials[order_idx]
    best <- trials[[1]]
    killed <- Filter(function(x) isTRUE(x$killed), trials)
    if (length(killed)) {
      killed_scores <- vapply(killed, `[[`, numeric(1), "progress")
      winner <- killed[[which.max(killed_scores)]]
      curve <- c(curve, list(row_curve_step(winner)))
      return(add_row_search_method(add_row_search_curve(winner, curve), "beam"))
    }
    curve <- c(curve, list(row_curve_step(best)))
    beam <- lapply(trials[seq_len(min(beam_width, length(trials)))], `[[`, "rows")
  }
  add_row_search_method(add_row_search_curve(best, curve), "beam")
}

evaluate_row_subset <- function(model, original_claim, data, rows, alpha, kill_rule) {
  rows <- unique(rows)
  if (!length(rows) || length(rows) >= nrow(data) - 2) return(NULL)
  fit <- try(refit_model(model, data[-rows, , drop = FALSE]), silent = TRUE)
  if (inherits(fit, "try-error")) return(NULL)
  claim <- try(extract_claim(fit, original_claim$term, alpha = alpha, alternative = original_claim$alternative %||% "two.sided", kill_rule = kill_rule), silent = TRUE)
  if (inherits(claim, "try-error")) return(NULL)
  list(
    rows = rows,
    claim = claim,
    killed = is_killed(claim, original_claim = original_claim, alpha = alpha, kill_rule = kill_rule),
    progress = row_attack_progress(claim, original_claim, kill_rule)
  )
}

row_attack_progress <- function(claim, original_claim, kill_rule) {
  if (kill_rule == "p_over_alpha" && is.finite(claim$p_value)) return(claim$p_value)
  if (kill_rule == "ci_crosses_zero" && is.finite(claim$conf_low) && is.finite(claim$conf_high)) {
    return(-min(abs(claim$conf_low), abs(claim$conf_high)))
  }
  if (kill_rule == "sign_flip") return(-sign(original_claim$estimate) * claim$estimate)
  if (kill_rule == "effect_below_threshold" && is.finite(claim$estimate)) return(-abs(claim$estimate))
  if (is.finite(claim$p_value)) return(claim$p_value)
  -Inf
}

add_row_search_method <- function(result, method) {
  if (is.null(result)) return(NULL)
  result$method <- method
  result
}

add_row_search_curve <- function(result, curve) {
  if (is.null(result)) return(NULL)
  curve <- Filter(Negate(is.null), curve)
  result$curve <- if (length(curve)) do.call(rbind, curve) else row_curve_empty()
  result
}

row_curve_step <- function(result) {
  if (is.null(result)) return(NULL)
  data.frame(
    k = length(result$rows),
    rows_removed = length(result$rows),
    rows = paste(result$rows, collapse = ","),
    estimate = result$claim$estimate,
    p_value = result$claim$p_value,
    killed = isTRUE(result$killed),
    progress = result$progress,
    stringsAsFactors = FALSE
  )
}

row_curve_empty <- function() {
  data.frame(
    k = integer(),
    rows_removed = integer(),
    rows = character(),
    estimate = double(),
    p_value = double(),
    killed = logical(),
    progress = double(),
    stringsAsFactors = FALSE
  )
}

bootstrap_p_value <- function(model, data, term, b, seed, alternative = "two.sided") {
  set.seed(seed + 500)
  estimates <- rep(NA_real_, b)
  for (i in seq_len(b)) {
    idx <- sample.int(nrow(data), nrow(data), replace = TRUE)
    fit <- try(refit_model(model, data[idx, , drop = FALSE]), silent = TRUE)
    if (inherits(fit, "try-error")) next
    c_i <- try(extract_claim(fit, term = term, alternative = alternative), silent = TRUE)
    if (!inherits(c_i, "try-error")) estimates[i] <- c_i$estimate
  }
  estimates <- estimates[is.finite(estimates)]
  if (!length(estimates)) return(NA_real_)
  if (identical(alternative, "less")) return(mean(estimates >= 0))
  if (identical(alternative, "greater")) return(mean(estimates <= 0))
  2 * min(mean(estimates <= 0), mean(estimates >= 0))
}

attack_result <- function(family, name, status, killed, claim, kill_distance, severity, explanation, payload) {
  tibble::tibble(
    attack_id = paste0(family, "_", gsub("[^a-z0-9]+", "_", tolower(name))),
    attack_family = family,
    attack_name = name,
    status = status,
    killed = killed,
    estimate = claim$estimate,
    p_value = claim$p_value,
    delta_p = claim$p_value - (claim$original_p_value %||% NA_real_),
    delta_estimate = NA_real_,
    kill_distance = kill_distance,
    severity = severity,
    explanation = explanation,
    payload = list(payload)
  )
}

attack_runtime <- function(call,
                           started_at,
                           model,
                           seed,
                           intensity,
                           profile,
                           alpha,
                           alternative,
                           kill_rule,
                           effect_threshold,
                           attacks,
                           unknown_attacks,
                           parallel) {
  ended_at <- Sys.time()
  version <- tryCatch(as.character(utils::packageVersion("falsifyr")), error = function(e) NA_character_)
  list(
    call = paste(deparse(call, width.cutoff = 500), collapse = " "),
    seed = seed,
    intensity = intensity,
    profile = profile,
    alpha = alpha,
    alternative = alternative,
    kill_rule = kill_rule,
    effect_threshold = effect_threshold,
    attacks = attacks,
    unknown_attacks = unknown_attacks,
    parallel = isTRUE(parallel),
    model_class = class(model)[1],
    package_version = version,
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    platform = R.version$platform,
    session_info = capture_session_info(),
    started_at = format(started_at, tz = "UTC", usetz = TRUE),
    ended_at = format(ended_at, tz = "UTC", usetz = TRUE),
    elapsed_sec = round(as.numeric(difftime(ended_at, started_at, units = "secs")), 3)
  )
}

bind_attack_rows <- function(rows) {
  rows <- Filter(function(x) !is.null(x) && nrow(x), rows)
  if (!length(rows)) {
    return(tibble::tibble(
      attack_id = character(), attack_family = character(), attack_name = character(),
      status = character(), killed = logical(), estimate = double(), p_value = double(),
      delta_p = double(), delta_estimate = double(), kill_distance = double(),
      severity = double(), explanation = character(), payload = list()
    ))
  }
  vctrs::vec_rbind(!!!rows)
}

rank_attack_leaderboard <- function(attacks) {
  if (!nrow(attacks)) {
    attacks$leaderboard_rank <- integer()
    return(attacks)
  }
  status_rank <- ifelse(attacks$killed %in% TRUE, 0,
    ifelse(attacks$status == "survived", 1, 2)
  )
  distance <- attacks$kill_distance
  distance[!is.finite(distance)] <- Inf
  p_rank <- attacks$p_value
  p_rank[!is.finite(p_rank)] <- -Inf
  ord <- order(status_rank, distance, -attacks$severity, -p_rank, attacks$attack_name)
  ranked <- attacks[ord, , drop = FALSE]
  ranked$leaderboard_rank <- seq_len(nrow(ranked))
  ranked
}

check_attack_result <- function(result) {
  if (!inherits(result, "falsifyr_attack")) {
    stop("`result` must be a falsifyr_attack object returned by attack().", call. = FALSE)
  }
  invisible(result)
}

pick_smallest_kill <- function(attacks) {
  killed <- attacks[attacks$killed %in% TRUE, , drop = FALSE]
  if (!nrow(killed)) return(NULL)
  killed <- killed[order(killed$kill_distance, -killed$severity, na.last = TRUE), , drop = FALSE]
  as.list(killed[1, ])
}

verdict_from_score <- function(score) {
  if (score >= 80) return("RESILIENT")
  if (score >= 60) return("STABLE")
  if (score >= 40) return("MIXED")
  if (score >= 20) return("FRAGILE")
  "COLLAPSES"
}

placebo_rate_penalty <- function(attacks) {
  if (is.null(attacks$payload) || !length(attacks$payload)) return(0)
  rates <- vapply(attacks$payload, function(payload) {
    rate <- payload$placebo_rate %||% NA_real_
    if (length(rate) != 1 || !is.finite(rate)) NA_real_ else rate
  }, numeric(1))
  rates <- rates[is.finite(rates)]
  if (!length(rates)) return(0)
  round(25 * max(0, min(1, max(rates))))
}

severity_from_distance <- function(distance) {
  if (!is.finite(distance)) return(0)
  round(max(5, min(35, 35 * (1 - distance))))
}

robust_severity <- function(type) {
  penalties <- c(HC0 = 18, HC1 = 20, HC2 = 24, HC3 = 28)
  if (type %in% names(penalties)) penalties[[type]] else 22
}

raw_variable_from_term <- function(term) {
  sub("`", "", strsplit(term, split = ":", fixed = TRUE)[[1]][1], fixed = TRUE)
}

claim_variable <- function(model, term) {
  matrix <- try(stats::model.matrix(model), silent = TRUE)
  terms <- try(stats::terms(model), silent = TRUE)
  if (!inherits(matrix, "try-error") && !inherits(terms, "try-error") && term %in% colnames(matrix)) {
    column <- match(term, colnames(matrix))
    assignment <- attr(matrix, "assign")[column]
    labels <- attr(terms, "term.labels")
    if (is.finite(assignment) && assignment > 0 && assignment <= length(labels)) {
      variables <- all.vars(stats::as.formula(paste("~", labels[assignment])))
      if (length(variables)) return(variables[1])
    }
  }
  raw_variable_from_term(term)
}

match_formula_term <- function(term, labels) {
  if (term %in% labels) return(term)
  raw <- raw_variable_from_term(term)
  if (raw %in% labels) return(raw)
  starts <- labels[vapply(labels, function(x) startsWith(term, x), logical(1))]
  if (length(starts) == 1) return(starts)
  NULL
}

bounded_specification_grid <- function(target, adjustments, limit) {
  specs <- list()
  for (size in seq(length(adjustments), 0)) {
    combos <- if (size == 0) {
      list(character())
    } else {
      utils::combn(adjustments, size, simplify = FALSE)
    }
    for (combo in combos) {
      specs <- c(specs, list(c(target, combo)))
      if (length(specs) >= limit) return(specs)
    }
  }
  specs
}

impute_missing_predictors <- function(data, predictors, method) {
  out <- data
  for (nm in predictors) {
    x <- out[[nm]]
    if (!anyNA(x)) next
    if (identical(method, "indicator")) {
      out[[paste0(nm, "_missing")]] <- as.integer(is.na(x))
    }
    if (is.numeric(x)) {
      replacement <- if (method %in% c("median", "indicator")) {
        stats::median(x, na.rm = TRUE)
      } else {
        mean(x, na.rm = TRUE)
      }
      out[[nm]][is.na(x)] <- replacement
    } else if (is.factor(x)) {
      if (method == "mode_explicit") {
        x <- add_missing_factor_level(x)
        x[is.na(x)] <- "(Missing)"
        out[[nm]] <- x
      } else {
        out[[nm]][is.na(x)] <- mode_value(x)
      }
    } else {
      out[[nm]][is.na(x)] <- mode_value(x)
    }
  }
  out
}

add_missing_factor_level <- function(x) {
  if (!"(Missing)" %in% levels(x)) levels(x) <- c(levels(x), "(Missing)")
  x
}

mode_value <- function(x) {
  non_missing <- x[!is.na(x)]
  if (!length(non_missing)) return(NA)
  tab <- sort(table(non_missing), decreasing = TRUE)
  names(tab)[1]
}

missingness_name <- function(method) {
  switch(method,
    mean = "Mean imputation",
    median = "Median imputation",
    mode_explicit = "Mode/explicit-missing imputation",
    indicator = "Missingness-indicator imputation",
    method
  )
}

missingness_distance <- function(method) {
  switch(method,
    mean = 0.18,
    median = 0.16,
    mode_explicit = 0.22,
    indicator = 0.24,
    0.25
  )
}

missingness_imbalance <- function(data, predictors, exposure) {
  if (!exposure %in% names(data)) return(NULL)
  exposure_values <- unique(data[[exposure]])
  if (length(exposure_values) > 8) return(NULL)
  missing_any <- Reduce(`|`, lapply(data[predictors], is.na))
  stats::aggregate(
    list(missing_rate = missing_any),
    by = list(exposure = data[[exposure]]),
    FUN = mean
  )
}

fmt_num <- function(x) {
  if (!is.finite(x)) return("NA")
  formatC(x, digits = 3, format = "fg")
}

fmt_p <- function(x) {
  if (!is.finite(x)) return("NA")
  if (x < 0.001) return("<0.001")
  formatC(x, digits = 3, format = "f")
}

fmt_pct <- function(x) {
  if (!is.finite(x)) return("NA")
  paste0(formatC(100 * x, digits = 1, format = "f"), "%")
}

esc <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x
}

smallest_kill_html <- function(kill) {
  if (is.null(kill)) return("<p>No attack killed the claim in this run.</p>")
  details <- smallest_kill_details(kill)
  detail_html <- if (length(details)) {
    paste0("<br>", paste(esc(details), collapse = "<br>"))
  } else {
    ""
  }
  paste0("<p><b>", esc(kill$attack_name), ":</b> ", esc(kill$explanation), detail_html, "</p>")
}

smallest_kill_details <- function(kill) {
  payload <- attack_payload(kill)
  details <- character()
  if (!is.null(payload$rows) && length(payload$rows)) {
    details <- c(details, paste0("Rows: ", paste(payload$rows, collapse = ", ")))
  }
  if (!is.null(payload$method) && length(payload$method) == 1) {
    details <- c(details, paste0("Method: ", payload$method))
  }
  if (!is.null(payload$variable) && length(payload$variable) == 1) {
    details <- c(details, paste0("Variable: ", payload$variable))
  }
  if (!is.null(payload$placebo_rate) && length(payload$placebo_rate) == 1 && is.finite(payload$placebo_rate)) {
    details <- c(details, paste0("Placebo rate: ", fmt_pct(payload$placebo_rate)))
  }
  details
}

attack_payload <- function(row_like) {
  payload <- row_like$payload %||% list()
  if (length(payload) == 1 && is.list(payload[[1]])) return(payload[[1]])
  payload
}

claim_card_html <- function(claim) {
  alternative <- if (!identical(claim$alternative %||% "two.sided", "two.sided")) {
    paste0("<b>Alternative:</b> ", esc(claim$alternative), "<br>")
  } else {
    ""
  }
  paste0(
    "<p><b>Claim:</b> ", esc(claim_label(claim)), "<br>",
    "<b>Formula:</b> <code>", esc(formula_text(claim$formula)), "</code><br>",
    alternative,
    "<b>Estimate:</b> ", fmt_num(claim$estimate), "<br>",
    "<b>p-value:</b> ", fmt_p(claim$p_value), "<br>",
    "<b>Confidence interval:</b> ", esc(ci_value_text(claim)), "</p>"
  )
}

claim_label <- function(claim) {
  outcome <- claim$outcome %||% NA_character_
  if (length(outcome) == 1 && !is.na(outcome) && nzchar(outcome)) {
    return(paste0(claim$term, " -> ", outcome))
  }
  claim$term
}

formula_text <- function(formula) {
  if (is.null(formula)) return("NA")
  paste(deparse(formula, width.cutoff = 500), collapse = " ")
}

ci_text <- function(claim) {
  paste0("confidence interval: ", ci_value_text(claim))
}

ci_value_text <- function(claim) {
  if (is.null(claim$conf_low) || is.null(claim$conf_high) ||
        !is.finite(claim$conf_low) || !is.finite(claim$conf_high)) {
    return("NA")
  }
  paste0("[", fmt_num(claim$conf_low), ", ", fmt_num(claim$conf_high), "]")
}

weakest_assumptions <- function(attacks, n = 3) {
  if (!nrow(attacks)) return(character())
  killed <- attacks[attacks$killed %in% TRUE, , drop = FALSE]
  if (!nrow(killed)) return(character())
  killed <- killed[order(killed$kill_distance, -killed$severity, na.last = TRUE), , drop = FALSE]
  killed <- killed[seq_len(min(n, nrow(killed))), , drop = FALSE]
  labels <- vapply(killed$attack_family, family_label, character(1))
  paste0(labels, ": ", killed$explanation)
}

attacks_table_html <- function(attacks) {
  if (!nrow(attacks)) return("<p>No attacks were run.</p>")
  rows <- apply(attacks, 1, function(row) {
    paste0(
      "<tr><td>", esc(row[["leaderboard_rank"]]), "</td><td>", esc(row[["attack_family"]]), "</td><td>", esc(row[["attack_name"]]),
      "</td><td>", esc(row[["status"]]), "</td><td>", esc(fmt_p(as.numeric(row[["p_value"]]))),
      "</td><td>", esc(row[["explanation"]]), "</td></tr>"
    )
  })
  paste0("<table><thead><tr><th>Rank</th><th>Family</th><th>Attack</th><th>Status</th><th>p-value</th><th>Explanation</th></tr></thead><tbody>",
         paste(rows, collapse = ""), "</tbody></table>")
}

family_sections_html <- function(attacks) {
  if (!nrow(attacks)) return("<p>No attack families were run.</p>")
  families <- unique(attacks$attack_family)
  sections <- lapply(families, function(family) {
    family_rows <- attacks[attacks$attack_family == family, , drop = FALSE]
    killed <- sum(family_rows$killed %in% TRUE)
    survived <- sum(family_rows$status == "survived")
    unavailable <- sum(family_rows$status == "unavailable")
    paste0(
      "<section><h3>", esc(family_label(family)), "</h3>",
      "<p>", killed, " killed, ", survived, " survived, ", unavailable, " unavailable.</p>",
      attacks_table_html(family_rows),
      "</section>"
    )
  })
  paste(sections, collapse = "")
}

limitations_html <- function(result) {
  unavailable <- result$attacks[result$attacks$status == "unavailable", , drop = FALSE]
  warnings <- result$warnings %||% list()
  unknown <- warnings$unknown_attacks %||% character()
  limited <- warnings$limited_model_class %||% character()
  not_run <- setdiff(known_attack_families(), result$runtime$attacks %||% character())

  pieces <- c(
    "<p>A killed claim is fragile under the named attack. It does not prove the original claim is false, and it does not say the perturbed analysis is preferable.</p>",
    "<p>This report summarizes attacks that falsifyr could run from the fitted object and recoverable data. Unsupported or unavailable attacks are listed below so absence of evidence is not mistaken for robustness.</p>"
  )

  if (nrow(unavailable)) {
    rows <- apply(unavailable, 1, function(row) {
      paste0(
        "<tr><td>", esc(row[["attack_family"]]), "</td><td>", esc(row[["attack_name"]]), "</td><td>",
        esc(row[["explanation"]]), "</td></tr>"
      )
    })
    pieces <- c(pieces, paste0(
      "<h3>Unavailable attacks</h3>",
      "<table><thead><tr><th>Family</th><th>Attack</th><th>Reason</th></tr></thead><tbody>",
      paste(rows, collapse = ""),
      "</tbody></table>"
    ))
  } else {
    pieces <- c(pieces, "<p>No requested attack returned an unavailable status.</p>")
  }

  if (length(unknown)) {
    pieces <- c(pieces, paste0(
      "<p><b>Unknown requested attack families:</b> ",
      esc(paste(unknown, collapse = ", ")),
      ".</p>"
    ))
  }

  if (length(not_run)) {
    not_run_labels <- vapply(not_run, function(family) family_label(htest_output_family(family)), character(1))
    pieces <- c(pieces, paste0(
      "<p><b>Attack families not run:</b> ",
      esc(paste(not_run_labels, collapse = ", ")),
      ".</p>"
    ))
  }

  if (length(limited)) {
    pieces <- c(pieces, paste0(
      "<p><b>Limited model support:</b> ",
      esc(paste(limited, collapse = ", ")),
      ". Use a fitted lm/glm object for full perturbation attacks.</p>"
    ))
  }

  paste(pieces, collapse = "")
}

fragility_curves_html <- function(attacks) {
  if (!nrow(attacks)) return("<p>No fragility curves were available.</p>")
  has_curve <- vapply(attacks$payload, function(payload) {
    is.data.frame(payload$curve) && nrow(payload$curve) > 0
  }, logical(1))
  if (!any(has_curve)) return("<p>No fragility curves were available for this run.</p>")
  sections <- lapply(which(has_curve), function(i) {
    paste0(
      "<section><h3>", esc(attacks$attack_name[[i]]), "</h3>",
      curve_table_html(attacks$payload[[i]]$curve),
      "</section>"
    )
  })
  paste(sections, collapse = "")
}

curve_table_html <- function(curve) {
  columns <- intersect(
    c("k", "rows_removed", "replicate", "level", "train_rows", "holdout_rows", "kill_rate", "estimate", "p_value", "killed", "rows"),
    names(curve)
  )
  if (!length(columns)) return("<p>Curve data were recorded but cannot be displayed compactly.</p>")
  shown <- utils::head(curve[columns], 12)
  header <- paste0("<tr>", paste0("<th>", esc(curve_column_label(columns)), "</th>", collapse = ""), "</tr>")
  rows <- apply(shown, 1, function(row) {
    cells <- vapply(columns, function(column) {
      paste0("<td>", esc(curve_cell_value(row[[column]], column)), "</td>")
    }, character(1))
    paste0("<tr>", paste(cells, collapse = ""), "</tr>")
  })
  note <- if (nrow(curve) > nrow(shown)) {
    paste0("<p class='caveat'>Showing first ", nrow(shown), " of ", nrow(curve), " curve rows.</p>")
  } else {
    ""
  }
  paste0("<table><thead>", header, "</thead><tbody>", paste(rows, collapse = ""), "</tbody></table>", note)
}

curve_column_label <- function(columns) {
  labels <- c(
    k = "Step",
    rows_removed = "Rows removed",
    replicate = "Replicate",
    level = "Perturbation level",
    train_rows = "Training rows",
    holdout_rows = "Holdout rows",
    kill_rate = "Kill rate",
    estimate = "Estimate",
    p_value = "p-value",
    killed = "Killed",
    rows = "Rows"
  )
  unname(ifelse(columns %in% names(labels), labels[columns], columns))
}

curve_cell_value <- function(value, column) {
  if (length(value) != 1 || is.na(value)) return("NA")
  if (column == "p_value") return(fmt_p(as.numeric(value)))
  if (column == "kill_rate") return(fmt_pct(as.numeric(value)))
  if (column %in% c("estimate", "level")) return(fmt_num(as.numeric(value)))
  if (column == "killed") return(if (as.logical(value)) "yes" else "no")
  as.character(value)
}

reproducibility_html <- function(result) {
  runtime <- result$runtime %||% list()
  paste0(
    "<dl>",
    "<dt>Call</dt><dd><code>", html_value(runtime$call), "</code></dd>",
    "<dt>Model class</dt><dd>", html_value(runtime$model_class), "</dd>",
    "<dt>Attack settings</dt><dd>",
    "seed = ", html_value(runtime$seed),
    "; intensity = ", html_value(runtime$intensity),
    "; profile = ", html_value(runtime$profile),
    "; alpha = ", html_value(runtime$alpha),
    "; kill rule = ", html_value(runtime$kill_rule),
    "; alternative = ", html_value(runtime$alternative),
    "</dd>",
    "<dt>Attack families</dt><dd>", html_value(runtime$attacks, collapse = ", "), "</dd>",
    "<dt>Unknown requested families</dt><dd>", html_value(runtime$unknown_attacks, collapse = ", "), "</dd>",
    "<dt>Package version</dt><dd>", html_value(runtime$package_version), "</dd>",
    "<dt>R version</dt><dd>", html_value(runtime$r_version), "</dd>",
    "<dt>Platform</dt><dd>", html_value(runtime$platform), "</dd>",
    "<dt>Session info</dt><dd>", session_info_html(runtime$session_info), "</dd>",
    "<dt>Started</dt><dd>", html_value(runtime$started_at), "</dd>",
    "<dt>Finished</dt><dd>", html_value(runtime$ended_at), "</dd>",
    "<dt>Elapsed seconds</dt><dd>", html_value(runtime$elapsed_sec), "</dd>",
    "</dl>"
  )
}

capture_session_info <- function() {
  tryCatch(utils::capture.output(utils::sessionInfo()), error = function(e) "sessionInfo() unavailable")
}

html_value <- function(x, collapse = "") {
  if (is.null(x) || !length(x)) return("NA")
  if (all(is.na(x))) return("NA")
  esc(paste(x, collapse = collapse))
}

session_info_html <- function(x) {
  if (is.null(x) || !length(x)) return("NA")
  paste0(
    "<details><summary>Show session info</summary><pre>",
    esc(paste(x, collapse = "\n")),
    "</pre></details>"
  )
}

family_label <- function(family) {
  labels <- c(
    row_deletion = "Row deletion / influence",
    standard_error = "Standard-error / uncertainty",
    covariate = "Covariate dependence",
    specification = "Specification",
    missingness = "Missing data",
    measurement_error = "Measurement error",
    placebo = "Placebo",
    split = "Split stability"
  )
  if (family %in% names(labels)) labels[[family]] else family
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
