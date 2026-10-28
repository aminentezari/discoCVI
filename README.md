# discoCVI

> **Evaluate density-based clusterings, including their noise labels, without ground truth.**

[![CRAN status](https://www.r-pkg.org/badges/version/discoCVI)](https://CRAN.R-project.org/package=discoCVI)
[![CRAN downloads](https://cranlogs.r-pkg.org/badges/grand-total/discoCVI)](https://CRAN.R-project.org/package=discoCVI)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![DISCO paper](https://img.shields.io/badge/arXiv-2503.00127-b31b1b.svg)](https://arxiv.org/abs/2503.00127)

**discoCVI** implements **DISCO** (Density-based Internal Score for
Clusterings with nOise; Beer et al., ICLR 2026), an internal cluster validity
index for density-based clustering. DISCO

- works for clusters of **arbitrary shape**, because it measures distances
  along dense regions (density-connectivity distance) instead of straight
  lines;
- is the first index that **explicitly scores noise labels**: a point
  labelled as noise scores high only if it really lies in a sparse region far
  from every cluster;
- is defined **for every labelling**, including a single cluster, singleton
  clusters and clusterings with only noise;
- returns scores in **[−1, 1]** (higher is better), both for the whole
  clustering and for each point.

Typical uses are comparing the results of different clustering algorithms
and choosing the parameters of DBSCAN or HDBSCAN when no labelled data exist.

---

## Contents

- [Installation](#installation)
- [Quick start](#quick-start)
- [Functions](#functions)
- [Noise labels: an important detail](#noise-labels-an-important-detail)
- [Interpreting scores](#interpreting-scores)
- [How DISCO works](#how-disco-works)
- [Performance](#performance)
- [Correctness](#correctness)
- [Version history](#version-history)
- [Citation](#citation)
- [Related packages](#related-packages)
- [Contributing](#contributing)
- [License and acknowledgements](#license-and-acknowledgements)

---

## Installation

```r
# released version from CRAN
install.packages("discoCVI")

# development version from GitHub
# install.packages("remotes")
remotes::install_github("aminentezari/discoCVI")
```

Dependencies: [FNN](https://CRAN.R-project.org/package=FNN) (nearest
neighbours) and [Rcpp](https://CRAN.R-project.org/package=Rcpp) (compiled
code). Installing from GitHub compiles C++ code; on macOS this needs the Xcode
command line tools (`xcode-select --install`), on Windows
[Rtools](https://cran.r-project.org/bin/windows/Rtools/).

---

## Quick start

```r
library(discoCVI)
library(dbscan)   # for HDBSCAN; any clustering method can be used

# two half-moons plus scattered noise
set.seed(42)
moons <- function(n, sd = 0.08) {
  t1 <- runif(n / 2, 0, pi); t2 <- runif(n / 2, 0, pi)
  rbind(cbind(cos(t1), sin(t1)), cbind(1 - cos(t2), 0.5 - sin(t2))) +
    matrix(rnorm(2 * n, sd = sd), ncol = 2)
}
X <- rbind(moons(600), cbind(runif(40, -1.5, 2.5), runif(40, -1, 1.5)))

# 1. cluster, and convert dbscan's noise label 0 to DISCO's -1
labels <- hdbscan(X, minPts = 10)$cluster
labels[labels == 0] <- -1L

# 2. score the clustering (higher is better)
disco_score(X, labels)

# 3. compare with k-means, which cuts across the moons
disco_score(X, kmeans(X, centers = 2, nstart = 10)$cluster)

# 4. choose minPts without ground truth
score_minpts <- function(m) {
  lab <- hdbscan(X, minPts = m)$cluster
  lab[lab == 0] <- -1L
  disco_score(X, lab)
}
sapply(c(3, 5, 10, 20, 50), score_minpts)

# 5. inspect individual points
s <- disco_samples(X, labels)   # one score per point
which(s < 0)                    # badly placed points
```

A complete walk-through, including plots of the pointwise scores and an
analysis of noise points, is in the vignette:

```r
vignette("discoCVI")
```

---

## Functions

| Function | Returns |
|---|---|
| `disco_score(X, labels, min_points = 5)` | DISCO score of the clustering: one number in [−1, 1] |
| `disco_samples(X, labels, min_points = 5)` | pointwise DISCO scores, one per row of `X` |
| `p_cluster(X, labels, min_points = 5, precomputed_dc_dists = FALSE)` | scores of cluster points (silhouette on density-connectivity distances) |
| `p_noise(X, labels, min_points = 5, dc_dists = NULL)` | `list(p_sparse, p_far)`: the two parts of the score of each noise point |
| `compute_dc_distances(X, min_points = 5)` | the n × n density-connectivity distance matrix |

**Arguments.** `X` is a numeric matrix or data frame (rows = points).
`labels` is an integer vector with one cluster label per point and **`-1`
for noise**. `min_points` (default 5, as in the DISCO paper) is the
neighbourhood size DISCO uses to measure density; it does not need to match
the `minPts` of your clustering algorithm.

`disco_score()` and `disco_samples()` never build an n × n matrix and scale
to large datasets. `compute_dc_distances()` returns a full n × n matrix by
definition; use it for small datasets or when you want to reuse the
distances for many labellings:

```r
D  <- compute_dc_distances(X)
nn <- labels != -1
p_cluster(D[nn, nn], labels[nn], precomputed_dc_dists = TRUE)
```

---

## Noise labels: an important detail

DISCO uses **`-1`** for noise, as the original implementation and
scikit-learn do. The **dbscan** package uses **`0`** for noise in both
`dbscan()` and `hdbscan()`. Convert the labels before scoring:

```r
labels <- hdbscan(X, minPts = 10)$cluster
labels[labels == 0] <- -1L
```

If you pass the labels unchanged, all noise points are silently treated as
one extra cluster, which changes the score and its meaning.

---

## Interpreting scores

| Score | Meaning |
|---|---|
| 0.7 to 1.0 | excellent: well-separated, dense clusters and convincing noise |
| 0.4 to 0.7 | good: clear cluster structure |
| 0.0 to 0.4 | moderate: clusters overlap or are weakly separated |
| −0.3 to 0.0 | poor: many points are better suited to another cluster |
| −1.0 to −0.3 | very poor |

For a **cluster point**, a negative score means the point is, on average,
closer (in density-connectivity) to another cluster than to its own. For a
**noise point**, a negative score means the point lies in a dense region or
is density-connected to a cluster, so it should probably have been assigned
to that cluster. These thresholds are rules of thumb; compare scores between
clusterings of the same data rather than across datasets.

---

## How DISCO works

1. **Core distance** κ(x): distance from x to its `min_points`-th nearest
   neighbour (counting x itself).
2. **Mutual-reachability distance**: d_m(x, y) = max(κ(x), κ(y), ‖x − y‖).
3. **Density-connectivity distance** d_dc(x, y): the largest edge on the path
   between x and y in the minimum spanning tree of d_m. Points are close if
   they are connected through a dense region.
4. **Cluster points** get the silhouette coefficient computed on d_dc:
   (b − a) / max(a, b), with a the mean distance to the own cluster and b the
   mean distance to the closest other cluster.
5. **Noise points** get min(p_sparse, p_far): p_sparse is positive if the
   point is sparser than every cluster, p_far is positive if it is not
   density-connected to any cluster.
6. The **DISCO score** is the mean of the pointwise scores.

Edge cases follow the paper: only noise → −1 for all points; one cluster and
no noise → 0; points in singleton clusters → 0; one cluster plus noise →
cluster points are compared with the closest noise point.

**Implementation (since 0.2.0).** The density-connectivity distance between
two points equals the height at which they are first joined in the
single-linkage merge tree of the minimum spanning tree. discoCVI therefore
builds the spanning tree in C++ (distances computed on the fly), turns it into
the merge tree, and gathers every quantity DISCO needs in one pass over that
tree. No n × n matrix is ever stored: memory grows linearly with n, while the
running time remains O(n²), as in the original definition.

---

## Performance

Synthetic data (three Gaussian clusters + 5 % noise, 2 dimensions); MacBook
Pro, Apple M2 Pro, 16 GB, single thread; median of repeated runs, each in a
fresh process; peak memory of the whole process. Scores are identical in all
comparisons.

**Against the previous version (0.1.1):**

| n | 0.1.1 | 0.2.x | speed-up | memory 0.1.1 | memory 0.2.x |
|---|---|---|---|---|---|
| 500 | 0.25 s | 0.011 s | 23× | 118 MB | 91 MB |
| 2,000 | 4.3 s | 0.053 s | 81× | 377 MB | 89 MB |
| 4,000 | 18.6 s | 0.134 s | 138× | 1,222 MB | 93 MB |
| 32,000 | not feasible | 5.3 s | | | 125 MB |
| 100,000 | not feasible | 50 s | | | 198 MB |

**Against the original Python implementation (Beer et al.):**

| n | Python | discoCVI 0.2.x | speed-up | memory Python | memory discoCVI |
|---|---|---|---|---|---|
| 500 | 0.032 s | 0.011 s | 2.9× | 68 MB | 88 MB |
| 2,000 | 0.262 s | 0.056 s | 4.7× | 211 MB | 93 MB |
| 8,000 | 3.53 s | 0.405 s | 8.7× | 1,134 MB | 96 MB |

R itself accounts for about 67 MB of the discoCVI figures. Energy
measurements (CodeCarbon) show the same savings: one evaluation of 4,000
points used 45 mWh with 0.1.1 and 0.26 mWh with 0.2.x. All scripts and raw
results are in [`benchmarks/`](https://github.com/aminentezari/discoCVI/tree/main/benchmarks).

---

## Correctness

- The test suite (`tests/testthat`) keeps the 0.1.1 implementation as a
  reference and compares **all exported functions** on random data (1 to 8
  dimensions, `min_points` 2 to 10, with and without noise, singleton
  clusters, one cluster plus noise, mostly-noise and random labellings).
  Differences are of the order of 1e-15.
- Pointwise scores agree with the **original Python implementation** to
  within 3e-13 on all benchmark datasets, including one with a singleton
  cluster ([`benchmarks/python_compare/`](https://github.com/aminentezari/discoCVI/tree/main/benchmarks/python_compare)).
- Earlier validation of 0.1.1 against the Python reference on eight
  benchmark datasets (circles, moons, spirals, Complex8/9, Dartboard, blobs)
  gave identical scores to 10 decimal places.

---

## Version history

- **0.2.1**: new vignette with a complete workflow.
- **0.2.0**: DISCO computed without any n × n matrix (23–138× faster than
  0.1.1, linear memory, 100,000 points in under a minute); minimum spanning
  tree in C++ via Rcpp; test suite against 0.1.1; **bug fix**: points in
  singleton clusters now score 0, as defined in the paper (0.1.1 gave 1).
- **0.1.1**: first CRAN release, a line-by-line translation of the Python
  reference implementation.

Details in [NEWS.md](https://github.com/aminentezari/discoCVI/blob/main/NEWS.md).

---

## Citation

If you use discoCVI, please cite the DISCO paper and the package:

```bibtex
@inproceedings{beer2026disco,
  title     = {Internal Evaluation of Density-Based Clusterings with Noise},
  author    = {Beer, Anna and Krieger, Lena and Weber, Pascal and
               Ritzert, Martin and Assent, Ira and Plant, Claudia},
  booktitle = {International Conference on Learning Representations (ICLR)},
  year      = {2026},
  doi       = {10.48550/arXiv.2503.00127}
}

@manual{discocvi,
  title  = {discoCVI: Implementation of the DISCO Metric for Internal
            Clustering Evaluation},
  author = {Entezari, Amin},
  year   = {2026},
  note   = {R package},
  doi    = {10.32614/CRAN.package.discoCVI},
  url    = {https://CRAN.R-project.org/package=discoCVI}
}
```

You can also run `citation("discoCVI")` in R.

---

## Related packages

- [dbscan](https://CRAN.R-project.org/package=dbscan): DBSCAN, HDBSCAN and
  OPTICS clustering (produces the labels that discoCVI evaluates).
- [DBCVindex](https://CRAN.R-project.org/package=DBCVindex): the DBCV
  density-based validity index.
- [fpc](https://CRAN.R-project.org/package=fpc),
  [clusterCrit](https://CRAN.R-project.org/package=clusterCrit),
  [cluster](https://CRAN.R-project.org/package=cluster): classical validity
  indices (silhouette, CDbw and many others).

None of these evaluates noise labels; that is what DISCO adds.

---

## Contributing

Bug reports and feature requests are welcome on
[GitHub issues](https://github.com/aminentezari/discoCVI/issues). Please
include a small reproducible example.

---

## License and acknowledgements

MIT © Amin Entezari.

DISCO was proposed by Anna Beer, Lena Krieger, Pascal Weber, Martin Ritzert,
Ira Assent and Claudia Plant; the original Python implementation is by Beer,
Krieger and Weber, who are also listed as authors of this package. Davide
Chicco supervised the development of version 0.1.

*Contact: amin_entezari@outlook.com*
