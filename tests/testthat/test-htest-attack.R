test_that("attack returns an explicit limited result for htest objects", {
  test <- t.test(score ~ treatment, data = fragile_trial)
  res <- attack(test, attacks = c("row_deletion", "noise"), intensity = "fast")

  expect_s3_class(res, "falsifyr_attack")
  expect_equal(res$claim$model_class, "htest")
  expect_equal(res$verdict, "UNTESTED")
  expect_true(is.na(res$survival_score))
  expect_true(all(res$attacks$status == "unavailable"))
  expect_true("row_deletion" %in% res$attacks$attack_family)
  expect_true("measurement_error" %in% res$attacks$attack_family)
  expect_equal(res$warnings$limited_model_class, "htest")
})

test_that("htest reports explain why perturbations are unavailable", {
  test <- cor.test(fragile_trial$score, fragile_trial$age)
  res <- attack(test, attacks = "placebo")

  expect_match(res$attacks$explanation[1], "do not retain enough original data")
  expect_null(res$smallest_kill)
})

test_that("wilcox.test htest objects receive limited-support attack reports", {
  test <- wilcox.test(score ~ treatment, data = fragile_trial, exact = FALSE)
  res <- attack(test, attacks = c("row_deletion", "standard_error"), intensity = "fast")

  expect_s3_class(res, "falsifyr_attack")
  expect_equal(res$claim$model_class, "htest")
  expect_equal(res$verdict, "UNTESTED")
  expect_true(all(res$attacks$status == "unavailable"))
  expect_equal(res$warnings$limited_model_class, "htest")
})

test_that("htest print output names unavailable attacks", {
  test <- t.test(score ~ treatment, data = fragile_trial)
  res <- attack(test, attacks = "noise")
  output <- paste(capture.output(print(res), type = "message"), collapse = "\n")

  expect_match(output, "Unavailable", fixed = TRUE)
  expect_match(output, "Measurement error unavailable", fixed = TRUE)
})
