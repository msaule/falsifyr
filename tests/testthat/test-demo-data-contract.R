test_that("fragile_trial starts significant and dies under core attacks", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  claim <- extract_claim(fit, term = "treatment")

  expect_lt(claim$p_value, 0.05)

  row <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast", seed = 11)
  missing <- attack(fit, term = "treatment", attacks = "missingness", intensity = "fast", seed = 11)
  noise <- attack(fit, term = "treatment", attacks = "measurement_error", intensity = "fast", seed = 11)

  expect_true(any(row$attacks$killed))
  expect_true(any(missing$attacks$killed))
  expect_true(any(noise$attacks$killed))
})

test_that("resilient_trial has a strong claim and survives basic attacks", {
  fit <- lm(score ~ treatment + age + baseline_score, data = resilient_trial)
  claim <- extract_claim(fit, term = "treatment")

  expect_lt(claim$p_value, 0.001)

  row <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast", seed = 11)
  se <- attack(fit, term = "treatment", attacks = "standard_error", intensity = "fast", seed = 11)
  covariate <- attack(fit, term = "treatment", attacks = "covariate_drop", intensity = "fast", seed = 11)

  expect_false(any(row$attacks$killed))
  expect_false(any(se$attacks$killed))
  expect_false(any(covariate$attacks$killed))
})
