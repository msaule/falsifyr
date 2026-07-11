devtools::load_all(quiet = TRUE)

validate_case <- function(name, model, term, expected, data = NULL, cluster = NULL) {
  result <- attack(
    model,
    term = term,
    data = data,
    cluster = cluster,
    attacks = c("row_deletion", "covariate_drop", "standard_error"),
    intensity = "fast",
    seed = 2026,
    verbose = FALSE
  )
  data.frame(
    case = name,
    model_class = result$claim$model_class,
    expected = expected,
    score = result$survival_score,
    verdict = result$verdict,
    killed = any(result$attacks$killed),
    smallest_kill = if (is.null(result$smallest_kill)) NA_character_ else result$smallest_kill$attack_name,
    stringsAsFactors = FALSE
  )
}

fragile_fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
resilient_fit <- lm(score ~ treatment + age + baseline_score, data = resilient_trial)

grouped_data <- fragile_trial
grouped_data$site <- factor(rep(seq_len(10), each = 8))
grouped_fit <- lm(score ~ treatment + age + baseline_score, data = grouped_data)

factor_data <- resilient_trial
factor_data$arm <- factor(ifelse(factor_data$treatment == 1, "active", "control"))
factor_fit <- lm(score ~ arm + age + baseline_score, data = factor_data)
factor_term <- grep("^arm", names(stats::coef(factor_fit)), value = TRUE)[1]

glm_data <- resilient_trial
glm_data$event <- as.integer(glm_data$score > stats::median(glm_data$score))
glm_fit <- glm(event ~ treatment + age + baseline_score, data = glm_data, family = binomial())

results <- rbind(
  validate_case("known fragile lm", fragile_fit, "treatment", "fragile"),
  validate_case("known resilient lm", resilient_fit, "treatment", "resilient"),
  validate_case("grouped deletion lm", grouped_fit, "treatment", "supported", grouped_data, "site"),
  validate_case("factor coefficient lm", factor_fit, factor_term, "supported"),
  validate_case("binomial glm", glm_fit, "treatment", "supported")
)

if (requireNamespace("lme4", quietly = TRUE)) {
  mixed_data <- resilient_trial
  mixed_data$site <- factor(rep(seq_len(12), each = 10))
  mixed_data$score <- mixed_data$score + rep(seq(-2, 2, length.out = 12), each = 10)
  mixed_fit <- lme4::lmer(score ~ treatment + age + (1 | site), data = mixed_data, REML = FALSE)
  results <- rbind(results, validate_case("linear mixed model", mixed_fit, "treatment", "supported"))
}

if (requireNamespace("survival", quietly = TRUE)) {
  cox_data <- survival::lung
  cox_fit <- survival::coxph(
    survival::Surv(time, status == 2) ~ age + sex,
    data = cox_data,
    model = TRUE,
    x = TRUE
  )
  results <- rbind(results, validate_case("Cox model", cox_fit, "age", "supported", cox_data))
}

fragile_score <- results$score[results$case == "known fragile lm"]
resilient_score <- results$score[results$case == "known resilient lm"]
stopifnot(
  fragile_score < resilient_score,
  results$killed[results$case == "known fragile lm"],
  !results$killed[results$case == "known resilient lm"],
  all(is.finite(results$score)),
  all(results$score >= 0 & results$score <= 100)
)

covariate_result <- attack(
  fragile_fit,
  term = "treatment",
  attacks = "covariate_drop",
  intensity = "fast",
  verbose = FALSE
)
covariate_text <- paste(capture.output(print(covariate_result)), collapse = " ")
stopifnot(
  !grepl("claim is false", covariate_text, fixed = TRUE),
  !grepl("should be removed", covariate_text, fixed = TRUE)
)

utils::write.csv(results, "validation/results.csv", row.names = FALSE, na = "")
print(results, row.names = FALSE)
