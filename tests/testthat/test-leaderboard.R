test_that("attack table is ranked as a leaderboard", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", intensity = "fast", seed = 123)

  expect_equal(res$attacks$leaderboard_rank, seq_len(nrow(res$attacks)))
  expect_equal(res$attacks$attack_id[1], res$smallest_kill$attack_id)
  killed_positions <- which(res$attacks$killed %in% TRUE)
  survived_positions <- which(res$attacks$status == "survived")
  expect_lt(max(killed_positions), min(survived_positions))
})

test_that("HTML attack table includes leaderboard ranks", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast")
  file <- tempfile(fileext = ".html")
  report(res, file)
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  expect_match(html, "<th>Rank</th>", fixed = TRUE)
})

test_that("leaderboard and smallest-kill accessors expose ranked results", {
  fit <- lm(score ~ treatment + age + baseline_score, data = fragile_trial)
  res <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast", seed = 11)

  expect_equal(attack_leaderboard(res), res$attacks)
  expect_equal(smallest_kill(res)$attack_id, res$smallest_kill$attack_id)
  expect_equal(attack_leaderboard(res)$leaderboard_rank, seq_len(nrow(res$attacks)))
})

test_that("smallest-kill accessor returns NULL when no attack kills the claim", {
  fit <- lm(score ~ treatment + age + baseline_score, data = resilient_trial)
  res <- attack(fit, term = "treatment", attacks = "row_deletion", intensity = "fast", seed = 11)

  expect_null(smallest_kill(res))
})

test_that("leaderboard accessors reject non-attack objects", {
  expect_error(
    attack_leaderboard(data.frame()),
    "`result` must be a falsifyr_attack object",
    fixed = TRUE
  )
  expect_error(
    smallest_kill(list()),
    "`result` must be a falsifyr_attack object",
    fixed = TRUE
  )
})
