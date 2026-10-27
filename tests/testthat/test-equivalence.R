# v0.2.0 must give the same results as the v0.1.1 reference implementation
# (helper-reference.R) up to floating-point rounding.

tol <- 1e-10

test_that("compute_dc_distances() matches v0.1.1", {
  set.seed(10)
  for (p in c(1, 2, 5)) {
    d <- make_blobs(80, p = p)
    for (mp in c(2, 5, 10)) {
      expect_equal(compute_dc_distances(d$X, mp),
                   ref_compute_dc_distances(d$X, mp), tolerance = tol)
    }
  }
})

test_that("extract_dc_distances_from_mst() matches the BFS version", {
  set.seed(11)
  X <- matrix(stats::rnorm(120), ncol = 2)
  R <- ref_calculate_reachability_distance(X, 5)
  E <- ref_get_mst_edges(R)
  expect_equal(extract_dc_distances_from_mst(E, nrow(X)),
               ref_extract_dc_distances_from_mst(E, nrow(X)), tolerance = tol)
})

test_that("p_cluster() matches v0.1.1, including singleton clusters", {
  set.seed(12)
  d  <- make_blobs(90, noise_frac = 0)
  D  <- ref_compute_dc_distances(d$X, 5)
  lab <- d$labels
  expect_equal(p_cluster(D, lab, precomputed_dc_dists = TRUE),
               ref_p_cluster(D, lab, precomputed_dc_dists = TRUE), tolerance = tol)
  lab[1] <- 99L                                   # singleton cluster
  expect_equal(p_cluster(D, lab, precomputed_dc_dists = TRUE),
               ref_p_cluster(D, lab, precomputed_dc_dists = TRUE), tolerance = tol)
  expect_equal(p_cluster(d$X, d$labels), ref_p_cluster(d$X, d$labels), tolerance = tol)
})

test_that("disco_samples() matches v0.1.1 on many configurations", {
  set.seed(13)
  for (trial in 1:25) {
    n  <- sample(40:160, 1)
    p  <- sample(c(1, 2, 3, 8), 1)
    mp <- sample(c(2, 3, 5, 10), 1)
    d  <- make_blobs(n, p, noise_frac = sample(c(0, 0.05, 0.3), 1),
                     k = sample(c(2, 3, 6), 1))
    lab <- d$labels
    r <- trial %% 5
    if (r == 1) lab[sample(n, 1)] <- 99L                       # singleton cluster
    if (r == 2) lab <- ifelse(lab == -1L, -1L, 0L)             # one cluster + noise
    if (r == 3) lab <- sample(-1:3, n, replace = TRUE)         # random labels
    if (r == 4) { lab[] <- -1L; lab[1:3] <- c(0L, 1L, 1L) }    # mostly noise
    if (length(unique(lab)) < 2) next
    expect_equal(disco_samples(d$X, lab, min_points = mp),
                 ref_disco_samples(d$X, lab, min_points = mp),
                 tolerance = tol,
                 info = sprintf("trial %d (case %d, n = %d, p = %d, min_points = %d)",
                                trial, r, n, p, mp))
  }
})

test_that("disco_score() matches v0.1.1 and accepts data frames", {
  set.seed(14)
  d <- make_blobs(100)
  expect_equal(disco_score(d$X, d$labels),
               mean(ref_disco_samples(d$X, d$labels)), tolerance = tol)
  expect_equal(disco_score(as.data.frame(d$X), d$labels),
               disco_score(d$X, d$labels))
})
