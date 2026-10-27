test_that("all-noise and single-cluster inputs follow the documented rules", {
  X <- matrix(stats::rnorm(40), ncol = 2)
  expect_equal(disco_samples(X, rep(-1L, 20)), rep(-1, 20))
  expect_equal(disco_samples(X, rep(3L, 20)), rep(0, 20))
})

test_that("scores are bounded in [-1, 1]", {
  set.seed(20)
  d <- make_blobs(150, noise_frac = 0.2)
  s <- disco_samples(d$X, d$labels)
  expect_true(all(s >= -1 - 1e-12 & s <= 1 + 1e-12))
})

test_that("invalid input is rejected", {
  X <- matrix(stats::rnorm(40), ncol = 2)
  expect_error(disco_samples(X, rep(0L, 19)), "label size")
  expect_error(disco_samples(X[0, , drop = FALSE], integer(0)), "empty")
  expect_error(disco_samples(X, rep(c(0L, 1L), 10), min_points = 1), "at least 2")
})

test_that("a larger dataset runs without building an n x n matrix", {
  skip_on_cran()
  set.seed(21)
  d <- make_blobs(5000)
  s <- disco_score(d$X, d$labels)
  expect_true(is.finite(s) && s >= -1 && s <= 1)
})
