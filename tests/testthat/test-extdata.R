test_that("raw example data CSVs are installed", {
  fragile_path <- system.file("extdata", "fragile_trial.csv", package = "falsifyr")
  resilient_path <- system.file("extdata", "resilient_trial.csv", package = "falsifyr")

  expect_true(file.exists(fragile_path))
  expect_true(file.exists(resilient_path))

  fragile_csv <- utils::read.csv(fragile_path)
  resilient_csv <- utils::read.csv(resilient_path)

  expect_equal(dim(fragile_csv), dim(fragile_trial))
  expect_equal(dim(resilient_csv), dim(resilient_trial))
  expect_equal(names(fragile_csv), names(fragile_trial))
  expect_equal(names(resilient_csv), names(resilient_trial))
})
