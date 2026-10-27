# discoCVI

> **Implementation of the DISCO Metric for Internal Clustering Evaluation**

R implementation of the DISCO (Density-based Internal Score for Clustering
Outcomes) metric — a Cluster Validity Index (CVI) for evaluating
density-based clustering results, including explicit evaluation of noise point
quality. Translated from the original Python reference implementation by
Beer, Krieger, Weber et al. (2025).

[![CRAN](https://www.r-pkg.org/badges/version/discoCVI)](https://CRAN.R-project.org/package=discoCVI)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![R >= 3.6](https://img.shields.io/badge/R-%3E%3D%203.6-blue.svg)](https://cran.r-project.org/)
[![Paper](https://img.shields.io/badge/arXiv-2503.00127-red.svg)](https://arxiv.org/abs/2503.00127)

---

## What's new in 0.2.0

- **Much faster, much less memory, same scores.** DISCO is now computed
  without building any n × n matrix. It is 23 to 138 times faster than 0.1.1
  (n = 500 to 4,000), and 100,000 points can be scored in under a minute
  with about 200 MB of peak memory for the whole R process (0.1.1 needed
  1.2 GB for 4,000 points).
- **Identical results.** Every exported function is tested against the 0.1.1
  implementation (`tests/testthat`); differences are at the level of
  floating-point rounding (< 1e-14).
- **Bug fix.** Points in singleton clusters now score 0, as defined in the
  DISCO paper (0.1.1 gave them 1).
- **Compiled code.** The minimum spanning tree is built in C++ (Rcpp).

See [NEWS.md](NEWS.md) for details.

---

## Table of Contents

- [Overview](#overview)
- [Why DISCO?](#why-disco)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Function Reference](#function-reference)
- [Algorithm](#algorithm)
- [Performance](#performance)
- [Implementation Notes](#implementation-notes)
- [Experimental Results](#experimental-results)
- [File Structure](#file-structure)
- [Results Interpretation](#results-interpretation)
- [Citation](#citation)

---

## Overview

discoCVI evaluates clustering quality **without ground truth labels** by using
**density-connectivity distance (dc-distance)** instead of Euclidean distance.
It is the first CVI that:

- Handles **arbitrary-shaped clusters** (not just convex/spherical)
- Explicitly evaluates **noise point quality** (not just cluster quality)
- Returns bounded, interpretable scores in **[−1, 1]**

---

## Why DISCO?

Traditional CVIs like Silhouette and Davies-Bouldin assume convex clusters and
ignore noise. On non-convex data, they rank the wrong algorithm higher:

| Algorithm | Silhouette | Davies-Bouldin | **DISCO** |
|-----------|-----------|----------------|-----------|
| DBSCAN (correct) | −0.16 ❌ | 2.8 (bad) ❌ | **0.68 ✅** |
| K-Means (wrong)  | 0.37 ✅  | 0.6 (good) ✅ | **0.22 ❌** |

DISCO correctly identifies DBSCAN as better on non-convex data.

---

## Installation

```r
# Released version from CRAN
install.packages("discoCVI")

# Development version from GitHub
# install.packages("remotes")
remotes::install_github("aminentezari/discoCVI")
```

**Dependencies** (installed automatically):
- `FNN` — fast k-nearest neighbour search
- `Rcpp` — compiled minimum spanning tree (from 0.2.0)

Installing from GitHub compiles C++ code; on macOS this needs the Xcode
command line tools (`xcode-select --install`), on Windows Rtools.

---

## Quick Start

```r
library(discoCVI)
library(dbscan)

# 1. Two concentric circles with a little noise
set.seed(42)
n     <- 300
theta <- runif(n, 0, 2 * pi)
r     <- ifelse(seq_len(n) <= n / 2, 1, 0.4)
X     <- cbind(r * cos(theta), r * sin(theta)) + matrix(rnorm(2 * n, sd = 0.05), ncol = 2)

# 2. Cluster with DBSCAN and with k-means
db_labels <- dbscan(X, eps = 0.2, minPts = 5)$cluster - 1L   # noise 0 -> -1
km_labels <- kmeans(X, centers = 2, nstart = 10)$cluster - 1L

# 3. Evaluate: DBSCAN should score clearly higher
disco_score(X, db_labels)
disco_score(X, km_labels)

# 4. Per-point scores: which points are badly placed?
scores <- disco_samples(X, db_labels)
summary(scores)
which(scores < 0)
```

> **Noise labels.** DISCO expects noise to be labelled **`-1`**. The `dbscan`
> package labels noise **`0`** (both `dbscan()` and `hdbscan()`), so convert
> first: `labels <- res$cluster - 1L`, or `labels[labels == 0] <- -1L`.

---

## Function Reference

### Core Functions

#### `disco_score(X, labels, min_points = 5)`
Returns a single number summarising overall clustering quality.

| Argument | Type | Description |
|---|---|---|
| `X` | matrix / data.frame | n x p feature matrix |
| `labels` | integer vector | Cluster labels; use `-1` for noise |
| `min_points` | integer | k for dc-distance. Default: `5` |

**Returns:** Single numeric in [-1, 1].

#### `disco_samples(X, labels, min_points = 5)`
Returns per-point scores — useful for identifying problematic points.

```r
scores     <- disco_samples(X, labels)
bad_points <- which(scores < 0)
```

#### `p_cluster(X, labels, min_points, precomputed_dc_dists)`
Silhouette-style scores using dc-distances. `-1` is treated as a valid cluster here.

#### `p_noise(X, labels, min_points, dc_dists)`
Returns `list(p_sparse, p_far)` for noise points only.

#### `compute_dc_distances(X, min_points = 5)`
Returns the n x n DC-distance matrix directly. Useful for comparing several
labelings of the same data, but note that the matrix itself has n² entries;
`disco_score()` and `disco_samples()` do not need it.

```r
D  <- compute_dc_distances(X)
s1 <- p_cluster(D, labels1, precomputed_dc_dists = TRUE)
s2 <- p_cluster(D, labels2, precomputed_dc_dists = TRUE)
```

---

## Algorithm

### Step 1 - Core Distance
```
k(x) = d_euclidean(x, x_{min_points-1})
```

### Step 2 - Mutual Reachability Distance
```
dm(x, y) = max( k(x), k(y), d_euclidean(x, y) )
```

### Step 3 - DC-Distance via MST
```
dc(x, y) = max edge weight on minimax path x -> y in MST
```

### Step 4 - DISCO Score per Point

**Cluster points:**
```
a = mean dc-distance to own cluster (excluding self)
b = min over other clusters of mean dc-distance
p(x) = (b - a) / max(a, b)
```

**Noise points:**
```
p_sparse = (k(n) - k_max(C)) / max(k(n), k_max(C))
p_far    = (dc_min(n,C) - k_max(C)) / max(dc_min(n,C), k_max(C))
p(n)     = min(p_sparse, p_far)
```

**Overall:**
```
DISCO = (1/n) * sum(p(x_i))
```

---

## Performance

From version 0.2.0, `disco_samples()` and `disco_score()` never store an
n × n matrix:

1. Core distances come from a k-nearest-neighbour search.
2. The minimum spanning tree of the mutual-reachability graph is built in C++
   with Prim's algorithm, computing each distance only when it is needed.
3. Sorting the tree edges gives the single-linkage merge tree. The dc-distance
   between two points is exactly the weight of the merge at which they first
   become connected.
4. One pass over this merge tree accumulates, for every point, the sum and the
   minimum of its dc-distances to each cluster — everything DISCO needs.

Memory therefore grows linearly with the number of points (times the number
of clusters) instead of quadratically. Time is still dominated by the
O(n²) spanning tree, but without R loops or large temporary matrices.

Benchmark on synthetic data (3 Gaussian blobs + 5% noise, 2 dimensions;
Apple Silicon laptop, single thread; median of 5 runs, each in a fresh R
process; peak memory = maximum resident set size of the whole R process,
of which about 67 MB is R itself; energy measured with CodeCarbon, minus an
R start-up baseline). Scores of the two versions are identical.

| n | time 0.1.1 | time 0.2.0 | speed-up | peak memory 0.1.1 | peak memory 0.2.0 |
|---|---|---|---|---|---|
| 500 | 0.25 s | 0.011 s | 23× | 118 MB | 91 MB |
| 1,000 | 1.0 s | 0.022 s | 46× | 200 MB | 92 MB |
| 2,000 | 4.3 s | 0.053 s | 81× | 377 MB | 89 MB |
| 4,000 | 18.6 s | 0.134 s | 138× | 1,222 MB | 93 MB |
| 16,000 | — | 1.4 s | | — | 109 MB |
| 32,000 | — | 5.3 s | | — | 125 MB |
| 100,000 | — | 50 s | | — | 198 MB |

At n = 4,000, version 0.2.0 uses about 0.26 mWh instead of 45 mWh of
energy per evaluation. Full results and scripts are in `benchmarks/`.

---

## Implementation Notes

The original R version (0.1.1) is a **line-by-line translation** of the Python
reference (`disco.py` + `dctree.py`). Three issues were found and fixed during
the translation:

### Bug 1 - Core Distance Off-by-One

Python includes self (dist=0) in k-NN, so effective neighbor is k-1.
`FNN::get.knn` excludes self:

```r
k          <- min_points - 1
knn_result <- FNN::get.knn(X, k = k)
core_dists <- knn_result$nn.dist[, k]
```

### Bug 2 - MST Tie-Breaking

`igraph::mst` breaks equal-weight edges differently than Python's Prim.
Fixed by porting Python's exact `_get_mst_edges()` (dctree.py lines 401-438).
(The dc-distances themselves do not depend on how ties are broken, because the
largest edge on a path between two points is the same in every minimum
spanning tree.)

### Bug 3 - K-Means Cross-Language Non-Determinism

R and Python RNGs produce different K-Means partitions from the same seed.
Fixed by exporting Python labels as CSV and loading in R:

```python
# Python
pd.DataFrame({"km_label": km.labels_}).to_csv("python_km_labels.csv", index=False)
```
```r
# R
km_labels <- as.integer(read.csv("python_km_labels.csv")$km_label)
```

After all fixes, R and Python produce **identical scores to 10 decimal places**:
```
DISCO - DBSCAN  : 0.6900921813  (R == Python)
DISCO - K-Means : 0.0270091908  (R == Python)
```

### Bug 4 - Singleton Clusters (fixed in 0.2.0)

The DISCO paper sets the score of a point that forms a cluster on its own to
0 (Section 3, "Edge cases"). Version 0.1.1 returned 1 for such points, because
the mean distance to the "rest of its cluster" was taken as 0. Version 0.2.0
follows the paper. Labelings without singleton clusters are not affected.

Version 0.2.0 replaces the matrix-based computation with the merge-tree
algorithm described under [Performance](#performance) and is tested to give
the same results as 0.1.1 (apart from the singleton fix).

---

## Experimental Results

Eight benchmark datasets validated against the Python reference. All
differences are within machine epsilon (< 1e-14).

| Dataset | n | Clusters | DBSCAN | K-Means | Match |
|---|---|---|---|---|---|
| Concentric Circles | 300 | 2 | 0.6900921813 | 0.0270091908 | R == Python |
| Two Moons | 1000 | 2 | 0.8179598377 | 0.2832395719 | R == Python |
| 3-Spiral | 312 | 3 | 0.5836514046 | -0.0014176359 | R == Python |
| Complex9 | 3031 | 9 | 0.4209464514 | 0.0551096775 | R == Python |
| Complex8 | 2551 | 8 | 0.0718687652 | 0.0122574749 | R == Python |
| Dartboard1 | 1000 | 4 | 0.8743426861 | -0.0033636711 | R == Python |
| Blobs | 450 | 3 | 0.8548953163 | 0.8575691834 | R == Python |
| Diagonal Blobs | 600 | 3 | 0.7215536253 | 0.7043253397 | R == Python |

> **Note:** Negative K-Means scores on Dartboard1 and 3-Spiral are correct and
> expected — DISCO penalises algorithms that cut through ring or spiral structures.

---

## File Structure

```
discoCVI/
├── R/
│   ├── disco.R              <- Exported functions and documentation
│   ├── disco_tree.R         <- Fast merge-tree engine (0.2.0)
│   └── RcppExports.R        <- Generated by Rcpp
├── src/
│   ├── prim_mrd.cpp         <- Minimum spanning tree in C++ (0.2.0)
│   └── RcppExports.cpp      <- Generated by Rcpp
├── tests/testthat/          <- Equivalence tests against 0.1.1
├── man/                     <- Generated by devtools::document()
├── benchmarks/              <- Timing, memory and energy benchmarks
├── DESCRIPTION
├── NAMESPACE                <- Generated by devtools::document()
├── NEWS.md
├── LICENSE
└── README.md
```

---

## Results Interpretation

| Score | Meaning |
|---|---|
| 0.7 - 1.0 | Excellent - well-separated, compact clusters |
| 0.4 - 0.7 | Good - clear cluster structure |
| 0.0 - 0.4 | Moderate - overlapping clusters |
| -0.3 - 0.0 | Poor - misassigned points |
| -1.0 - -0.3 | Very poor - clustering worse than random |

### Common Pitfall

```r
# WRONG: dbscan() and hdbscan() use 0 for noise
labels <- dbscan(X, eps = 0.2)$cluster

# CORRECT: DISCO uses -1 for noise
labels <- dbscan(X, eps = 0.2)$cluster - 1L
```

---

## Citation

```bibtex
@inproceedings{beer2026disco,
  title     = {Internal Evaluation of Density-Based Clusterings with Noise},
  author    = {Beer, Anna and Krieger, Lena and Weber, Pascal and
               Ritzert, Martin and Assent, Ira and Plant, Claudia},
  booktitle = {International Conference on Learning Representations (ICLR)},
  year      = {2026},
  note      = {arXiv:2503.00127}
}
```

**R Package:**
```
Entezari A (2026). discoCVI: Implementation of the DISCO Metric for
Internal Clustering Evaluation. R package version 0.2.0.
https://CRAN.R-project.org/package=discoCVI
```

---

## License

MIT © Amin Entezari

Original Python implementation by Beer, Krieger, Weber, Ritzert, Assent,
Plant (2025).

*For questions: amin_entezari@outlook.com*
