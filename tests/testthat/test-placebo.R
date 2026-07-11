test_that("placebo attack includes label permutation and fake predictor", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "placebo", intensity = "fast", seed = 11)

  expect_true("Treatment-label permutation" %in% res$attacks$attack_name)
  expect_true("Fake predictor placebo" %in% res$attacks$attack_name)

  methods <- vapply(res$attacks$payload, function(x) {
    if (is.null(x$method)) NA_character_ else x$method
  }, character(1))
  expect_true(all(c("label_permutation", "fake_predictor") %in% methods))
  expect_true(all(vapply(res$attacks$payload, function(x) is.data.frame(x$curve), logical(1))))
})

test_that("placebo attack is deterministic with seed", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  a <- attack(fit, term = "treatment", attacks = "placebo", intensity = "fast", seed = 42)
  b <- attack(fit, term = "treatment", attacks = "placebo", intensity = "fast", seed = 42)

  expect_equal(a$attacks$p_value, b$attacks$p_value, tolerance = 1e-12)
  expect_equal(a$attacks$payload[[1]]$placebo_rate, b$attacks$payload[[1]]$placebo_rate)
  expect_equal(a$attacks$payload[[2]]$placebo_rate, b$attacks$payload[[2]]$placebo_rate)
})

test_that("placebo attack supports user-supplied placebo outcomes", {
  d <- fragile_trial
  d$placebo_score <- rev(d$score)
  fit <- lm(score ~ treatment + age + baseline_score, data = d)

  res <- attack(
    fit,
    term = "treatment",
    data = d,
    outcome = "placebo_score",
    attacks = "placebo",
    intensity = "fast",
    seed = 11
  )
  placebo <- res$attacks[res$attacks$attack_name == "Placebo outcome: placebo_score", , drop = FALSE]

  expect_equal(nrow(placebo), 1)
  expect_true(placebo$status %in% c("killed", "survived"))
  expect_equal(placebo$payload[[1]]$method, "placebo_outcome")
  expect_equal(placebo$payload[[1]]$placebo_outcome, "placebo_score")
  expect_true(is.finite(placebo$p_value))
})

test_that("missing user-supplied placebo outcomes are explicit", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(
    fit,
    term = "treatment",
    outcome = "future_score",
    attacks = "placebo",
    intensity = "fast",
    seed = 11
  )
  placebo <- res$attacks[res$attacks$attack_name == "Placebo outcome: future_score", , drop = FALSE]

  expect_equal(placebo$status, "unavailable")
  expect_match(placebo$explanation, "pass data", fixed = TRUE)
})

test_that("placebo outcome names must be character", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)

  expect_error(
    attack(fit, term = "treatment", outcome = 1, attacks = "placebo", intensity = "fast"),
    "`outcome` must be a character vector",
    fixed = TRUE
  )
})
