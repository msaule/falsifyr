test_that("broom methods expose leaderboard and claim summaries", {
  skip_if_not_installed("broom")
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  result <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")

  tidied <- broom::tidy(result)
  glanced <- broom::glance(result)

  expect_s3_class(tidied, "tbl_df")
  expect_equal(nrow(tidied), nrow(result$attacks))
  expect_true(all(c("leaderboard_rank", "attack_family", "killed") %in% names(tidied)))
  expect_false("payload" %in% names(tidied))

  expect_s3_class(glanced, "tbl_df")
  expect_equal(nrow(glanced), 1)
  expect_equal(glanced$term, "treatment")
  expect_equal(glanced$survival_score, result$survival_score)
})
