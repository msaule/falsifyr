test_that("survival score penalizes placebo rates even below kill threshold", {
  attacks <- tibble::tibble(
    attack_id = c("placebo_low", "placebo_high"),
    attack_family = c("placebo", "placebo"),
    attack_name = c("Low placebo", "High placebo"),
    status = c("survived", "survived"),
    killed = c(FALSE, FALSE),
    estimate = c(0.1, 0.1),
    p_value = c(0.2, 0.2),
    delta_p = c(0.1, 0.1),
    delta_estimate = c(0, 0),
    kill_distance = c(0.02, 0.08),
    severity = c(0, 0),
    explanation = c("low", "high"),
    payload = list(list(placebo_rate = 0.02), list(placebo_rate = 0.08)),
    leaderboard_rank = c(1L, 2L)
  )

  expect_equal(score_survival(attacks), 98)
})

test_that("survival score clamps large placebo-rate penalties", {
  attacks <- tibble::tibble(
    attack_id = "placebo_extreme",
    attack_family = "placebo",
    attack_name = "Extreme placebo",
    status = "survived",
    killed = FALSE,
    estimate = 0.1,
    p_value = 0.2,
    delta_p = 0.1,
    delta_estimate = 0,
    kill_distance = 1,
    severity = 0,
    explanation = "extreme",
    payload = list(list(placebo_rate = 3)),
    leaderboard_rank = 1L
  )

  expect_equal(score_survival(attacks), 75)
})
