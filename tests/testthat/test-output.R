test_that("plot returns a ggplot object", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")
  expect_s3_class(plot(res), "ggplot")
})

test_that("report writes an html file", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")
  file <- tempfile(fileext = ".html")
  out <- report(res, file = file)
  expect_true(file.exists(out))
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(html, "<!doctype html>", fixed = TRUE)
  expect_match(html, "treatment -&gt; score", fixed = TRUE)
  expect_match(html, "score ~ treatment + age + baseline_score", fixed = TRUE)
  expect_match(html, "Confidence interval", fixed = TRUE)
  expect_match(html, "Family sections", fixed = TRUE)
  expect_match(html, "Fragility curves", fixed = TRUE)
  expect_match(html, "Limitations and caveats", fixed = TRUE)
  expect_match(html, "No requested attack returned an unavailable status.", fixed = TRUE)
  expect_match(html, "Attack families not run", fixed = TRUE)
  expect_match(html, "Measurement error", fixed = TRUE)
  expect_match(html, "Reproducibility appendix", fixed = TRUE)
  expect_match(html, "Row deletion / influence", fixed = TRUE)
  expect_match(html, "Rows: 43", fixed = TRUE)
  expect_match(html, "Method: ranked", fixed = TRUE)
  expect_match(html, "Rows removed", fixed = TRUE)
  expect_match(html, "Attack settings", fixed = TRUE)
  expect_match(html, "Package version", fixed = TRUE)
  expect_match(html, "R version", fixed = TRUE)
  expect_match(html, "Session info", fixed = TRUE)
  expect_match(html, "Show session info", fixed = TRUE)
  expect_match(html, "row_deletion", fixed = TRUE)
})

test_that("report requires an explicit output path", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")
  files_before <- list.files(getwd(), all.files = TRUE)

  expect_error(report(res), "`file` must be supplied", fixed = TRUE)
  expect_equal(list.files(getwd(), all.files = TRUE), files_before)
})

test_that("print output includes weakest assumptions and next actions", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")
  output <- paste(capture.output(print(res), type = "message"), collapse = "\n")

  expect_match(output, "treatment -> score", fixed = TRUE)
  expect_match(output, "formula: score ~ treatment + age + baseline_score", fixed = TRUE)
  expect_match(output, "confidence interval", fixed = TRUE)
  expect_match(output, "Rows: 43", fixed = TRUE)
  expect_match(output, "Method: ranked", fixed = TRUE)
  expect_match(output, "Weakest assumptions", fixed = TRUE)
  expect_match(output, "Use plot(x) for survival map.", fixed = TRUE)
  expect_match(output, "Use report(x, \"attack.html\") for full report.", fixed = TRUE)
})

test_that("one-sided claims name their alternative in output and reports", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast", alternative = "greater")
  output <- paste(capture.output(print(res), type = "message"), collapse = "\n")
  file <- tempfile(fileext = ".html")
  report(res, file)
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  expect_match(output, "alternative: greater", fixed = TRUE)
  expect_match(html, "<b>Alternative:</b> greater", fixed = TRUE)
})

test_that("report limitations explain unavailable and limited attacks", {
  test <- t.test(score ~ treatment, data = fragile_trial)
  res <- attack(test, attacks = c("row_deletion", "noise"), intensity = "fast")
  file <- tempfile(fileext = ".html")
  report(res, file)
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  expect_match(html, "Unavailable attacks", fixed = TRUE)
  expect_match(html, "do not retain enough original data", fixed = TRUE)
  expect_match(html, "Limited model support", fixed = TRUE)
  expect_match(html, "htest", fixed = TRUE)
})

test_that("report limitations include unknown requested attacks", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = c("row_deletion", "not_real"), intensity = "fast")
  file <- tempfile(fileext = ".html")
  report(res, file)
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  expect_match(html, "Unknown requested attack families", fixed = TRUE)
  expect_match(html, "not_real", fixed = TRUE)
})

test_that("report omits not-run caveat when all known families were requested", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(
    fit,
    term = "treatment",
    attacks = c("row_deletion", "standard_error", "covariate_drop", "missingness", "measurement_error", "placebo", "specification", "split"),
    intensity = "fast",
    seed = 11
  )
  file <- tempfile(fileext = ".html")
  report(res, file)
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  expect_no_match(html, "Attack families not run", fixed = TRUE)
})
