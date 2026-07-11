test_that("attack returns a falsifyr_attack object", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", intensity = "fast", seed = 11)
  expect_s3_class(res, "falsifyr_attack")
  expect_named(res, c("claim", "attacks", "smallest_kill", "survival_score", "verdict", "runtime", "warnings"))
})

test_that("row deletion finds the known fragile kill", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast", seed = 11)
  expect_true(any(res$attacks$killed))
  expect_equal(res$smallest_kill$attack_family, "row_deletion")
  expect_lte(res$smallest_kill$kill_distance, 0.05)
})

test_that("row deletion strategy follows intensity", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  fast <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast", seed = 11)
  normal <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "normal", seed = 11)
  insane <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "insane", seed = 11, verbose = FALSE)

  expect_equal(fast$attacks$payload[[1]]$method, "ranked")
  expect_equal(normal$attacks$payload[[1]]$method, "greedy")
  expect_equal(insane$attacks$payload[[1]]$method, "beam")
  expect_gte(normal$attacks$p_value, fast$attacks$p_value)
})

test_that("insane mode reports progress when verbose", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  output <- capture.output(
    {
      res <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "insane", seed = 11, verbose = TRUE)
      invisible(res)
    },
    type = "message"
  )

  expect_match(paste(output, collapse = "\n"), "Insane mode", fixed = TRUE)
  expect_match(paste(output, collapse = "\n"), "Running row-deletion attack.", fixed = TRUE)
})

test_that("insane mode progress can be suppressed", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  output <- capture.output(
    {
      res <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "insane", seed = 11, verbose = FALSE)
      invisible(res)
    },
    type = "message"
  )

  expect_equal(output, character())
})

test_that("attack preserves directional alternatives across refits", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  two_sided <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast", seed = 11)
  greater <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast", alternative = "greater", seed = 11)

  expect_equal(greater$claim$alternative, "greater")
  expect_equal(greater$runtime$alternative, "greater")
  expect_lt(greater$claim$p_value, two_sided$claim$p_value)
  expect_lte(greater$attacks$p_value, two_sided$attacks$p_value)
})

test_that("row deletion records a fragility curve", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast", seed = 11)
  curve <- res$attacks$payload[[1]]$curve

  expect_true(is.data.frame(curve))
  expect_named(curve, c("k", "rows_removed", "rows", "estimate", "p_value", "killed", "progress"))
  expect_gte(nrow(curve), 1)
  expect_equal(curve$rows_removed, seq_len(nrow(curve)))
  expect_equal(tail(curve$p_value, 1), res$attacks$p_value[[1]], tolerance = 1e-12)
})

test_that("default intensity is normal", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "row_deletion", seed = 11)

  expect_equal(res$runtime$intensity, "normal")
  expect_equal(res$attacks$payload[[1]]$method, "greedy")
})

test_that("fast profile uses interactive defaults", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", profile = "fast", seed = 11)

  expect_equal(res$runtime$intensity, "fast")
  expect_equal(res$runtime$attacks, c("row_deletion", "standard_error", "covariate_drop"))
  expect_true(all(unique(res$attacks$attack_family) %in% c("row_deletion", "standard_error", "covariate")))
})

test_that("profiles tune default attack family emphasis", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", profile = "social_science", intensity = "fast", seed = 11)

  expect_equal(res$runtime$profile, "social_science")
  expect_equal(res$runtime$attacks[1:3], c("specification", "covariate_drop", "placebo"))
})

test_that("attack records reproducibility metadata", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(
    fit,
    term = "treatment",
    attacks = "row_deletion",
    intensity = "fast",
    profile = "social_science",
    seed = 11
  )

  expect_match(res$runtime$call, "attack")
  expect_equal(res$runtime$seed, 11)
  expect_equal(res$runtime$profile, "social_science")
  expect_equal(res$runtime$attacks, "row_deletion")
  expect_equal(res$runtime$model_class, "lm")
  expect_type(res$runtime$package_version, "character")
  expect_type(res$runtime$r_version, "character")
  expect_true(is.character(res$runtime$session_info))
  expect_true(any(grepl("R version", res$runtime$session_info, fixed = TRUE)))
  expect_gte(res$runtime$elapsed_sec, 0)
})

test_that("resilient data survives the basic row deletion attack", {
  fit <- lm(score ~ treatment + age + baseline_score, data = resilient_trial)
  res <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast", seed = 11)
  expect_false(any(res$attacks$killed))
})

test_that("fragile survival score is lower than resilient score", {
  fragile <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  resilient <- lm(score ~ treatment + age + baseline_score, data = resilient_trial)
  fragile_res <- attack(fragile, term = "treatment", attacks = "row_deletion", intensity = "fast", seed = 11)
  resilient_res <- attack(resilient, term = "treatment", attacks = "row_deletion", intensity = "fast", seed = 11)
  expect_lt(fragile_res$survival_score, resilient_res$survival_score)
})

test_that("attack is deterministic with seed", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  a <- attack(fit, term = "treatment", attacks = c("row_deletion", "measurement_error", "placebo"), intensity = "fast", seed = 99)
  b <- attack(fit, term = "treatment", attacks = c("row_deletion", "measurement_error", "placebo"), intensity = "fast", seed = 99)
  expect_equal(a$attacks$p_value, b$attacks$p_value, tolerance = 1e-12)
  expect_equal(a$survival_score, b$survival_score)
})
