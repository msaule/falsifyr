test_that("standard-error attack reports HC0-HC3 when optional packages are available", {
  testthat::skip_if_not_installed("sandwich")
  testthat::skip_if_not_installed("lmtest")

  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "standard_error", intensity = "fast", seed = 11)

  methods <- vapply(res$attacks$payload, function(x) {
    if (is.null(x$method)) NA_character_ else x$method
  }, character(1))
  expect_true(all(c("HC0", "HC1", "HC2", "HC3", "bootstrap") %in% methods))
  expect_true(all(paste(c("HC0", "HC1", "HC2", "HC3"), "robust standard errors") %in% res$attacks$attack_name))
  expect_equal(res$attacks$attack_family, rep("standard_error", nrow(res$attacks)))
})
