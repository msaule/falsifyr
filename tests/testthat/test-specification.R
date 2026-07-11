test_that("bounded specification search reports evaluated specifications", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "specification", intensity = "normal", seed = 11)

  expect_equal(res$attacks$attack_family, "specification")
  expect_equal(res$attacks$status, "survived")
  expect_true(is.data.frame(res$attacks$payload[[1]]$specifications))
  expect_equal(nrow(res$attacks$payload[[1]]$specifications), 3)
})

test_that("bounded specification search can find an adjustment-dependent kill", {
  set.seed(1)
  n <- 100
  treatment <- rep(c(0, 1), each = n / 2)
  x <- 0.9 * treatment + rnorm(n, 0, 0.6)
  z <- rnorm(n)
  y <- 0.8 * treatment - 0.75 * x + 0.2 * z + rnorm(n, 0, 0.7)
  d <- data.frame(y = y, treatment = treatment, x = x, z = z)
  fit <- lm(y ~ treatment + x + z, data = d)

  res <- attack(fit, term = "treatment", attacks = "specification", intensity = "normal", seed = 11)

  expect_true(res$attacks$killed)
  expect_match(res$attacks$explanation, "omitting")
  expect_true(any(res$attacks$payload[[1]]$specifications$killed))
})
