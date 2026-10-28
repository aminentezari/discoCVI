# discoCVI 0.2.1

* New vignette, "Evaluating density-based clusterings with discoCVI", with a
  complete workflow: clustering with HDBSCAN, converting noise labels,
  choosing a hyperparameter with DISCO, and inspecting pointwise and noise
  scores (`vignette("discoCVI")`).

# discoCVI 0.2.0

## Performance

* `disco_samples()` and `disco_score()` no longer build any n x n matrix.
  The minimum spanning tree of the mutual-reachability graph is computed in
  compiled code (Rcpp) with distances evaluated on the fly, and all
  quantities needed by DISCO (sums and minima of density-connectivity
  distances per cluster) are obtained in a single pass over the resulting
  single-linkage merge tree. Memory now grows linearly with the number of
  points (times the number of clusters) instead of quadratically. On
  synthetic benchmarks, 0.2.0 is 23 to 138 times faster than 0.1.1
  (n = 500 to 4,000; 1,222 MB vs 93 MB peak memory at n = 4,000), and
  100,000 points can be scored in about 50 seconds with about 200 MB peak
  memory for the whole R process.
* `extract_dc_distances_from_mst()` fills the DC-distance matrix block by
  block in Kruskal order instead of running a breadth-first search from
  every point.
* `compute_dc_distances()` no longer builds the mutual-reachability matrix.
* `p_cluster()` is vectorised (one matrix product instead of nested loops).

## Bug fixes

* Points that form a singleton cluster now receive a cluster score of 0, as
  defined in the DISCO paper (Beer et al., Section 3, "Edge cases") and as in
  scikit-learn's `silhouette_samples()`. Version 0.1.1 gave them a score of
  1, which inflated `disco_score()` for labelings containing singleton
  clusters (for example from DBSCAN with a small `minPts`). Labelings
  without singleton clusters are not affected.

## Correctness

* Apart from the singleton fix above, all results are identical to version
  0.1.1 up to floating-point rounding. A test suite comparing every exported
  function against the 0.1.1 implementation has been added
  (`tests/testthat`).

## Dependencies

* New dependency: Rcpp (compiled code).

# discoCVI 0.1.1

* Initial CRAN release.
