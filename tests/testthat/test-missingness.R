test_that("missingness attack kills the fragile demo claim", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "missingness", intensity = "fast", seed = 11)

  expect_true(any(res$attacks$attack_family == "missingness"))
  expect_true(any(res$attacks$killed))
  expect_true(any(grepl("imputation", res$attacks$attack_name, ignore.case = TRUE)))
})

test_that("missingness attack includes an indicator-model sensitivity", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  result <- attack(fit, term = "treatment", attacks = "missingness", intensity = "fast")
  indicator <- result$attacks[result$attacks$attack_name == "Missingness-indicator imputation", ]

  expect_equal(nrow(indicator), 1)
  expect_equal(indicator$payload[[1]]$method, "indicator")
  expect_false(indicator$status == "unavailable")
})

test_that("missingness attack is explicit when no missing predictors exist", {
  fit <- lm(score ~ treatment + age + baseline_score, data = resilient_trial)
  res <- attack(fit, term = "treatment", attacks = "missingness", intensity = "fast", seed = 11)

  expect_equal(unique(res$attacks$status), "unavailable")
  expect_match(res$attacks$explanation[1], "No missing predictor values")
})
