#' @rdname extract_claim
#' @export
extract_claim.aov <- function(model,
                              term = NULL,
                              alpha = 0.05,
                              alternative = c("two.sided", "less", "greater"),
                              kill_rule = "p_over_alpha",
                              effect_threshold = NULL,
                              ...) {
  lm_model <- model
  class(lm_model) <- "lm"
  claim <- extract_claim.lm(
    lm_model,
    term = term,
    alpha = alpha,
    alternative = alternative,
    kill_rule = kill_rule,
    effect_threshold = effect_threshold,
    ...
  )
  claim$model_class <- "aov"
  claim
}

#' @rdname extract_claim
#' @export
extract_claim.merMod <- function(model,
                                 term = NULL,
                                 alpha = 0.05,
                                 alternative = c("two.sided", "less", "greater"),
                                 kill_rule = "p_over_alpha",
                                 effect_threshold = NULL,
                                 ...) {
  alternative <- match.arg(alternative)
  coefs <- summary(model)$coefficients
  term <- choose_term(coefs, term)
  estimate <- unname(coefs[term, "Estimate"])
  std_error <- unname(coefs[term, "Std. Error"])
  statistic_col <- grep("value$", colnames(coefs), value = TRUE)[1]
  statistic <- unname(coefs[term, statistic_col])
  p_col <- grep("^Pr\\(", colnames(coefs), value = TRUE)
  two_sided_p <- if (length(p_col)) {
    unname(coefs[term, p_col[1]])
  } else {
    2 * stats::pnorm(abs(statistic), lower.tail = FALSE)
  }
  p_value <- directional_normal_p(statistic, two_sided_p, alternative)
  critical <- stats::qnorm(1 - alpha / 2)
  formula <- stats::formula(model)

  list(
    model_class = if (inherits(model, "glmerMod")) "glmerMod" else "lmerMod",
    formula = formula,
    outcome = all.vars(formula)[1],
    term = term,
    estimate = estimate,
    std_error = std_error,
    statistic = statistic,
    p_value = p_value,
    conf_low = estimate - critical * std_error,
    conf_high = estimate + critical * std_error,
    alpha = alpha,
    alternative = alternative,
    kill_rule = kill_rule,
    effect_threshold = effect_threshold,
    p_method = if (length(p_col)) "model summary" else "Wald normal approximation"
  )
}

#' @rdname extract_claim
#' @export
extract_claim.coxph <- function(model,
                                term = NULL,
                                alpha = 0.05,
                                alternative = c("two.sided", "less", "greater"),
                                kill_rule = "p_over_alpha",
                                effect_threshold = NULL,
                                ...) {
  alternative <- match.arg(alternative)
  coefs <- summary(model)$coefficients
  term <- choose_term(coefs, term)
  estimate <- unname(coefs[term, "coef"])
  se_col <- if ("robust se" %in% colnames(coefs)) "robust se" else "se(coef)"
  std_error <- unname(coefs[term, se_col])
  statistic <- unname(coefs[term, "z"])
  two_sided_p <- unname(coefs[term, "Pr(>|z|)"])
  p_value <- directional_normal_p(statistic, two_sided_p, alternative)
  critical <- stats::qnorm(1 - alpha / 2)
  formula <- stats::formula(model)

  list(
    model_class = "coxph",
    formula = formula,
    outcome = paste(deparse(formula[[2]], width.cutoff = 500), collapse = ""),
    term = term,
    estimate = estimate,
    std_error = std_error,
    statistic = statistic,
    p_value = p_value,
    conf_low = estimate - critical * std_error,
    conf_high = estimate + critical * std_error,
    alpha = alpha,
    alternative = alternative,
    kill_rule = kill_rule,
    effect_threshold = effect_threshold,
    effect_scale = "log hazard ratio",
    hazard_ratio = exp(estimate)
  )
}

directional_normal_p <- function(statistic, two_sided_p, alternative) {
  if (identical(alternative, "two.sided")) return(two_sided_p)
  stats::pnorm(statistic, lower.tail = identical(alternative, "less"))
}

#' @rdname refit_model
#' @export
refit_model.aov <- function(model, data, formula = NULL, ...) {
  formula <- formula %||% stats::formula(model)
  args <- refit_call_args(formula = formula, data = data, ...)
  do.call(stats::aov, args)
}

#' @rdname refit_model
#' @export
refit_model.merMod <- function(model, data, formula = NULL, ...) {
  if (!requireNamespace("lme4", quietly = TRUE)) {
    stop("Refitting mixed models requires the suggested lme4 package.", call. = FALSE)
  }
  formula <- formula %||% stats::formula(model)
  if (inherits(model, "glmerMod")) {
    return(lme4::glmer(formula = formula, data = data, family = stats::family(model), ...))
  }
  lme4::lmer(formula = formula, data = data, REML = FALSE, ...)
}

#' @rdname refit_model
#' @export
refit_model.coxph <- function(model, data, formula = NULL, ...) {
  if (!requireNamespace("survival", quietly = TRUE)) {
    stop("Refitting Cox models requires the suggested survival package.", call. = FALSE)
  }
  formula <- formula %||% stats::formula(model)
  needed <- all.vars(formula)
  if (!all(needed %in% names(data)) && ncol(data) && inherits(data[[1]], "Surv")) {
    response <- paste0("`", names(data)[1], "`")
    labels <- attr(stats::terms(formula), "term.labels")
    formula <- stats::reformulate(labels, response = response, env = environment(formula))
  }
  survival::coxph(
    formula = formula,
    data = data,
    ties = model$method %||% "efron",
    model = TRUE,
    x = TRUE,
    ...
  )
}
