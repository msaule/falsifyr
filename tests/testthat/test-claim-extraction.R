test_that("lm claim extraction returns target coefficient", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  claim <- extract_claim(fit, term = "treatment")
  expect_equal(claim$term, "treatment")
  expect_lt(claim$p_value, 0.05)
  expect_true(is.finite(claim$estimate))
})

test_that("lm claim extraction supports directional alternatives", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  two_sided <- extract_claim(fit, term = "treatment")
  greater <- extract_claim(fit, term = "treatment", alternative = "greater")
  less <- extract_claim(fit, term = "treatment", alternative = "less")

  expect_equal(greater$alternative, "greater")
  expect_equal(less$alternative, "less")
  expect_lt(greater$p_value, two_sided$p_value)
  expect_gt(less$p_value, 0.9)
  expect_equal(greater$p_value, two_sided$p_value / 2, tolerance = 1e-8)
})

test_that("glm claim extraction works", {
  d <- resilient_trial
  d$event <- as.integer(d$score > median(d$score))
  fit <- glm(event ~ treatment + age + baseline_score, data = d, family = binomial())
  claim <- extract_claim(fit, term = "treatment")
  expect_equal(claim$model_class, "glm")
  expect_true(is.finite(claim$p_value))
})

test_that("glm claim extraction supports directional alternatives", {
  d <- resilient_trial
  d$event <- as.integer(d$score > median(d$score))
  fit <- glm(event ~ treatment + age + baseline_score, data = d, family = binomial())
  two_sided <- extract_claim(fit, term = "treatment")
  greater <- extract_claim(fit, term = "treatment", alternative = "greater")

  expect_equal(greater$alternative, "greater")
  expect_lt(greater$p_value, two_sided$p_value)
})

test_that("htest claim extraction works for t, Wilcoxon, and correlation tests", {
  tests <- list(
    t = t.test(score ~ treatment, data = fragile_trial),
    wilcox = wilcox.test(score ~ treatment, data = fragile_trial, exact = FALSE),
    correlation = cor.test(fragile_trial$score, fragile_trial$age)
  )

  for (test in tests) {
    claim <- extract_claim(test)
    expect_equal(claim$model_class, "htest")
    expect_true(is.finite(claim$p_value))
    expect_true(is.finite(claim$statistic))
    expect_equal(claim$alternative, "two.sided")
  }
})
