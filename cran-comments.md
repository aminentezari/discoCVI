## Submission

This is an update of discoCVI from 0.1.1 to 0.2.0.

* The DISCO score is now computed without building any n x n matrix: the
  minimum spanning tree is built in compiled code (Rcpp, new dependency) and
  all required quantities are obtained in one pass over the resulting merge
  tree. Results are identical to 0.1.1 up to floating-point rounding; a test
  suite comparing all exported functions against the 0.1.1 implementation
  has been added.
* Bug fix: points in singleton clusters now score 0, as defined in the
  original DISCO paper (Beer et al., <doi:10.48550/arXiv.2503.00127>).

## Test environments

* local macOS (aarch64-apple-darwin20), R 4.5.3
* win-builder (R-devel)

## R CMD check results

0 errors | 0 warnings | 0 notes

(Locally, the only note was "checking for future file timestamps: unable to
verify current time", which is caused by the local machine's network
settings and is not related to the package.)

## Reverse dependencies

There are currently no reverse dependencies on CRAN.
