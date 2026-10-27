# discoCVI 0.2.0

## Performance

* `disco_samples()` and `disco_score()` no longer build any n x n matrix.
  The minimum spanning tree of the mutual-reachability graph is computed in
  compiled code (Rcpp) with distances evaluated on the fly, and all
  quantities needed by DISCO (sums and minima of density-connectivity
  distances per cluster) are obtained in a single pass over the resulting
  single-linkage merge tree. Memory now grows linearly with the number of
  points (times the number of clusters) instead of quadratically. On
  synthetic benchmarks, scoring 2,000 points is about 95 times faster than
  in 0.1.1, and 100,000 points can be scored in under a minute with about
  100 MB of additional memory.
* `extract_dc_distances_from_mst()` fills the DC-distance matrix block by
  block in Kruskal order instead of running a breadth-first search from
  every point.
* `compute_dc_distances()` no longer builds the mutual-reachability matrix.
* `p_cluster()` is vectorised (one matrix product instead of nested loops).

## Correctness

* All results are identical to version 0.1.1 up to floating-point rounding.
  A test suite comparing every exported function against the 0.1.1
  implementation has been added (`tests/testthat`).

## Dependencies

* New dependency: Rcpp (compiled code).

# discoCVI 0.1.1

* Initial CRAN release.
