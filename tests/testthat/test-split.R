test_that("split stability records train/test refit curves", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "split", intensity = "fast", seed = 11)

  expect_true(all(res$attacks$attack_family == "split"))
  expect_true("Random train/test split stability" %in% res$attacks$attack_name)
  expect_true("Stratified train/test split stability" %in% res$attacks$attack_name)
  expect_true(all(res$attacks$status %in% c("killed", "survived")))
  random <- res$attacks[res$attacks$attack_name == "Random train/test split stability", , drop = FALSE]
  expect_true(is.data.frame(random$payload[[1]]$curve))
  expect_named(
    random$payload[[1]]$curve,
    c("level", "train_rows", "holdout_rows", "kill_rate", "estimate", "p_value", "valid_refits")
  )
  expect_equal(random$payload[[1]]$B, 30)
})

test_that("split stability is deterministic with seed", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)

  one <- attack(fit, term = "treatment", attacks = "train_test_split", intensity = "fast", seed = 11)
  two <- attack(fit, term = "treatment", attacks = "train_test_split", intensity = "fast", seed = 11)

  expect_equal(one$attacks$p_value, two$attacks$p_value)
  expect_equal(one$attacks$payload[[1]]$curve, two$attacks$payload[[1]]$curve)
  expect_equal(one$attacks$payload[[2]]$curve, two$attacks$payload[[2]]$curve)
})

test_that("stratified split preserves term groups in training samples", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "split", intensity = "fast", seed = 11)
  stratified <- res$attacks[res$attacks$attack_name == "Stratified train/test split stability", , drop = FALSE]

  expect_true(stratified$status %in% c("killed", "survived"))
  expect_equal(stratified$payload[[1]]$method, "stratified_train_test_split")
  expect_true(all(stratified$payload[[1]]$curve$valid_refits > 0))
})

test_that("prediction profile emphasizes split stability", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", profile = "prediction", intensity = "fast", seed = 11)

  expect_equal(res$runtime$profile, "prediction")
  expect_true("split" %in% res$runtime$attacks)
  expect_true("split" %in% res$attacks$attack_family)
})
