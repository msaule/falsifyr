test_that("refit_model preserves lm weights and offsets from model frames", {
  data <- data.frame(
    score = c(1.1, 1.4, 1.8, 2.1, 2.5, 2.9, 3.2, 3.7),
    treatment = c(0, 0, 0, 0, 1, 1, 1, 1),
    age = c(41, 48, 53, 59, 44, 50, 57, 63),
    exposure = c(1.0, 1.1, 1.2, 1.3, 1.1, 1.2, 1.3, 1.4),
    weight = c(1, 2, 1, 2, 1, 2, 1, 2)
  )
  fit <- lm(score ~ treatment + age + offset(log(exposure)), data = data, weights = weight)
  refit <- refit_model(fit, stats::model.frame(fit)[-1, , drop = FALSE])

  expect_s3_class(refit, "lm")
  expect_equal(unname(stats::weights(refit)), data$weight[-1])
  expect_equal(stats::model.offset(stats::model.frame(refit)), log(data$exposure[-1]))
})

test_that("refit_model preserves glm weights and offsets from model frames", {
  data <- data.frame(
    recovered = c(0, 1, 0, 1, 0, 1, 1, 1),
    treatment = c(0, 0, 0, 0, 1, 1, 1, 1),
    age = c(41, 48, 53, 59, 44, 50, 57, 63),
    exposure = c(1.0, 1.1, 1.2, 1.3, 1.1, 1.2, 1.3, 1.4),
    weight = c(1, 2, 1, 2, 1, 2, 1, 2)
  )
  fit <- glm(
    recovered ~ treatment + age + offset(log(exposure)),
    data = data,
    family = binomial(),
    weights = weight
  )
  refit <- refit_model(fit, stats::model.frame(fit)[-1, , drop = FALSE])

  expect_s3_class(refit, "glm")
  expect_equal(unname(stats::weights(refit)), data$weight[-1])
  expect_equal(stats::model.offset(stats::model.frame(refit)), log(data$exposure[-1]))
  expect_equal(stats::family(refit)$family, "binomial")
})

test_that("row deletion can attack weighted offset models", {
  data <- fragile_trial
  data$exposure <- seq(1, 1.4, length.out = nrow(data))
  data$weight <- rep(c(1, 2), length.out = nrow(data))
  fit <- lm(
    score ~ treatment + age + offset(log(exposure)),
    data = data,
    weights = weight
  )
  res <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast", seed = 11)

  expect_s3_class(res, "falsifyr_attack")
  expect_equal(res$attacks$attack_family, "row_deletion")
  expect_false(any(res$attacks$status == "unavailable"))
})
