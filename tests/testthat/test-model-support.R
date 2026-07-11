test_that("aov claims can be extracted, refitted, and attacked", {
  fit <- aov(score ~ treatment + age + baseline_score, data = fragile_trial)
  claim <- extract_claim(fit, term = "treatment")
  refit <- refit_model(fit, stats::model.frame(fit))
  result <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")

  expect_equal(claim$model_class, "aov")
  expect_s3_class(refit, "aov")
  expect_s3_class(result, "falsifyr_attack")
  expect_false(any(result$attacks$status == "unavailable"))
})

test_that("anova tables return explicit limited-support attacks", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  table <- stats::anova(fit)
  claim <- extract_claim(table, term = "treatment")
  result <- attack(table, term = "treatment", attacks = "row_deletion")

  expect_equal(claim$model_class, "anova")
  expect_true(is.finite(claim$p_value))
  expect_equal(result$verdict, "UNTESTED")
  expect_equal(result$warnings$limited_model_class, "anova")
  expect_true(all(result$attacks$status == "unavailable"))
})

test_that("lmerMod claims can be extracted, refitted, and attacked", {
  skip_if_not_installed("lme4")
  data <- resilient_trial
  data$site <- factor(rep(seq_len(12), each = 10))
  data$score <- data$score + rep(seq(-2, 2, length.out = 12), each = 10)
  fit <- lme4::lmer(score ~ treatment + age + (1 | site), data = data, REML = FALSE)
  claim <- extract_claim(fit, term = "treatment")
  refit <- refit_model(fit, stats::model.frame(fit))
  result <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")

  expect_equal(claim$model_class, "lmerMod")
  expect_equal(claim$p_method, "Wald normal approximation")
  expect_s4_class(refit, "lmerMod")
  expect_s3_class(result, "falsifyr_attack")
})

test_that("glmerMod claims can be extracted and refitted", {
  skip_if_not_installed("lme4")
  data <- resilient_trial
  data$site <- factor(rep(seq_len(12), each = 10))
  data$score <- data$score + rep(seq(-2, 2, length.out = 12), each = 10)
  data$event <- as.integer(data$score > stats::median(data$score))
  fit <- lme4::glmer(event ~ treatment + age + (1 | site), data = data, family = stats::binomial())
  claim <- extract_claim(fit, term = "treatment")
  refit <- refit_model(fit, stats::model.frame(fit))

  expect_equal(claim$model_class, "glmerMod")
  expect_true(is.finite(claim$p_value))
  expect_s4_class(refit, "glmerMod")
})

test_that("coxph claims can be extracted, refitted, and attacked", {
  skip_if_not_installed("survival")
  data <- survival::lung
  fit <- survival::coxph(
    survival::Surv(time, status == 2) ~ age + sex,
    data = data,
    model = TRUE,
    x = TRUE
  )
  claim <- extract_claim(fit, term = "age")
  refit <- refit_model(fit, stats::model.frame(fit))
  result <- attack(fit, term = "age", data = data, attacks = "row_deletion", intensity = "fast")

  expect_equal(claim$model_class, "coxph")
  expect_equal(claim$effect_scale, "log hazard ratio")
  expect_s3_class(refit, "coxph")
  expect_s3_class(result, "falsifyr_attack")
})
