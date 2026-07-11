test_that("factor coefficients map back to their source variable", {
  data <- resilient_trial
  data$arm <- factor(ifelse(data$treatment == 1, "active", "control"))
  fit <- lm(score ~ arm + age + baseline_score, data = data)
  term <- grep("^arm", names(stats::coef(fit)), value = TRUE)[1]

  expect_equal(falsifyr:::claim_variable(fit, term), "arm")
  result <- attack(fit, term = term, attacks = "placebo", intensity = "fast", seed = 7)
  expect_false(all(result$attacks$status == "unavailable"))
})

test_that("mixed-model formula attacks preserve random effects", {
  skip_if_not_installed("lme4")
  data <- resilient_trial
  data$site <- factor(rep(seq_len(12), each = 10))
  data$score <- data$score + rep(seq(-2, 2, length.out = 12), each = 10)
  fit <- lme4::lmer(score ~ treatment + age + baseline_score + (1 | site), data = data, REML = FALSE)
  result <- attack(
    fit,
    term = "treatment",
    attacks = c("covariate_drop", "specification"),
    intensity = "fast"
  )

  expect_true(any(result$attacks$attack_family == "covariate"))
  expect_true(any(result$attacks$attack_family == "specification"))
  expect_false(all(result$attacks$status == "unavailable"))
})
