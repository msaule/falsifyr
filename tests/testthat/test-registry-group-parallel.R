test_that("v1 registries cover documented models and attack families", {
  expect_equal(
    names(falsifyr:::claim_registry()),
    c("lm", "glm", "aov", "anova", "htest", "lmerMod", "glmerMod", "coxph")
  )
  expect_equal(
    names(falsifyr:::attack_registry()),
    c("row_deletion", "standard_error", "covariate_drop", "missingness", "measurement_error", "placebo", "specification", "split")
  )
})

test_that("grouped deletion evaluates complete groups", {
  data <- fragile_trial
  data$site <- factor(rep(seq_len(10), each = 8))
  fit <- lm(score ~ treatment + age + baseline_score, data = data)
  result <- attack(
    fit,
    term = "treatment",
    data = data,
    cluster = "site",
    attacks = "row_deletion",
    intensity = "fast"
  )
  grouped <- result$attacks[result$attacks$attack_name == "Grouped row deletion: site", ]

  expect_equal(nrow(grouped), 1)
  expect_equal(grouped$payload[[1]]$method, "grouped")
  expect_equal(grouped$payload[[1]]$cluster, "site")
  expect_gte(length(grouped$payload[[1]]$rows), 1)
})

test_that("parallel family execution matches serial execution", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  families <- c("row_deletion", "covariate_drop")
  serial <- attack(fit, term = "treatment", attacks = families, intensity = "fast", seed = 42)
  parallel <- attack(fit, term = "treatment", attacks = families, intensity = "fast", seed = 42, parallel = TRUE)

  expect_equal(parallel$attacks$attack_id, serial$attacks$attack_id)
  expect_equal(parallel$attacks$p_value, serial$attacks$p_value)
  expect_true(parallel$runtime$parallel)
})
