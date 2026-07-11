test_that("attack aliases from the spec map to internal families", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(
    fit,
    term = "treatment",
    attacks = c("row_deletion", "robust_se", "missingness", "noise", "placebo"),
    intensity = "fast",
    seed = 11
  )

  expect_true("row_deletion" %in% res$attacks$attack_family)
  expect_true("standard_error" %in% res$attacks$attack_family)
  expect_true("missingness" %in% res$attacks$attack_family)
  expect_true("measurement_error" %in% res$attacks$attack_family)
  expect_true("placebo" %in% res$attacks$attack_family)
})

test_that("unknown attack names are reported", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  messages <- capture.output(
    res <- attack(fit, term = "treatment", attacks = c("noise", "not_real"), intensity = "fast"),
    type = "message"
  )

  expect_equal(res$warnings$unknown_attacks, "not_real")
  expect_match(paste(messages, collapse = "\n"), "Skipping unknown attack", fixed = TRUE)
  expect_true(all(res$attacks$attack_family == "measurement_error"))
})
