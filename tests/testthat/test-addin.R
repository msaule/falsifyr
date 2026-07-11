test_that("addin helpers find supported model objects", {
  env <- new.env(parent = emptyenv())
  env$fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  env$not_model <- data.frame(x = 1)

  expect_equal(falsifyr:::addin_supported_models(env), "fit")
})

test_that("addin helpers list non-intercept model terms", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  terms <- falsifyr:::addin_model_terms(fit)

  expect_true("treatment" %in% terms)
  expect_false("(Intercept)" %in% terms)
})

test_that("addin attack choices expose all user-facing families", {
  choices <- falsifyr:::addin_attack_choices()

  expect_true("Split stability" %in% names(choices))
  expect_equal(unname(choices[["Split stability"]]), "split")
  expect_true(all(c("row_deletion", "standard_error", "missingness", "measurement_error", "placebo", "specification") %in% unname(choices)))
})

test_that("addin exits quietly outside RStudio", {
  out <- capture.output(result <- attack_this_claim(envir = new.env()), type = "message")

  expect_null(result)
  expect_match(paste(out, collapse = "\n"), "requires RStudio")
})
