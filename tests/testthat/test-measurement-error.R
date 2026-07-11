test_that("measurement-error attack includes outcome, predictor, and binary flips", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "measurement_error", intensity = "fast", seed = 99)

  expect_true("Outcome noise" %in% res$attacks$attack_name)
  expect_true(any(grepl("^Predictor noise:", res$attacks$attack_name)))
  expect_true("Binary label flip" %in% res$attacks$attack_name)
  expect_true(any(vapply(res$attacks$payload, function(x) identical(x$method, "binary_flip"), logical(1))))
})

test_that("measurement-error attack remains deterministic with seed", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  a <- attack(fit, term = "treatment", attacks = "measurement_error", intensity = "fast", seed = 101)
  b <- attack(fit, term = "treatment", attacks = "measurement_error", intensity = "fast", seed = 101)

  expect_equal(a$attacks$p_value, b$attacks$p_value, tolerance = 1e-12)
  expect_equal(a$attacks$explanation, b$attacks$explanation)
})
