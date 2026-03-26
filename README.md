# DISCO R Package

> **Density-based Internal Score for Clustering Outcomes**

R implementation of the DISCO metric — a Cluster Validity Index (CVI) for
evaluating density-based clustering results, including explicit evaluation of
noise point quality. Translated from the original Python reference implementation
by Beer, Krieger, Weber et al. (2025).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![R >= 3.6](https://img.shields.io/badge/R-%3E%3D%203.6-blue.svg)](https://cran.r-project.org/)
[![Paper](https://img.shields.io/badge/arXiv-2503.00127-red.svg)](https://arxiv.org/abs/2503.00127)

---

## Table of Contents

- [Overview](#overview)
- [Why DISCO?](#why-disco)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Function Reference](#function-reference)
- [Algorithm](#algorithm)
- [Implementation Notes](#implementation-notes)
- [Experimental Results](#experimental-results)
- [File Structure](#file-structure)
- [Results Interpretation](#results-interpretation)
- [Citation](#citation)

---

## Overview

DISCO evaluates clustering quality **without ground truth labels** by using
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
# Install from GitHub
devtools::install_github("aminentezari/Disco-R")
```

**Dependencies** (installed automatically):
- `FNN` — fast k-nearest neighbor search

---

## Quick Start

```r
library(disco)
library(dbscan)

# 1. Generate synthetic data
data   <- make_circles(n_samples = 300, noise = 0.05, factor = 0.4, random_state = 42)
X      <- data$X

# 2. Apply clustering
db_labels <- dbscan(X, eps = 0.2, minPts = 5)$cluster - 1L  # 0 -> -1 for noise
km_labels <- kmeans(X, centers = 2, nstart = 10)$cluster - 1L

# 3. Evaluate
disco_score(X, db_labels)   # -> 0.6900921813
disco_score(X, km_labels)   # -> 0.0270091908

# 4. Per-point scores
scores <- disco_samples(X, db_labels)
summary_disco_scores(scores)

# 5. Visualise
plot_disco_scores(X, db_labels, scores, main = "DBSCAN - DISCO Scores")

# 6. Compare algorithms
compare_clusterings(X, list(DBSCAN = db_labels, KMeans = km_labels))
```

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
Returns the n x n DC-distance matrix directly.

```r
D  <- compute_dc_distances(X)
s1 <- p_cluster(D, labels1, precomputed_dc_dists = TRUE)
s2 <- p_cluster(D, labels2, precomputed_dc_dists = TRUE)
```

### Utility Functions

| Function | Description |
|---|---|
| `make_circles(n, noise, factor, seed)` | Concentric circles dataset |
| `make_moons(n, noise, seed)` | Two interleaving crescents |
| `make_blobs(n, centers, std, seed)` | Gaussian blobs with variable density |
| `plot_disco_scores(X, labels, scores)` | Red-yellow-green scatter plot |
| `compare_clusterings(X, list(...))` | Rank multiple clusterings by DISCO |
| `summary_disco_scores(scores)` | Mean, median, SD, quantiles, n_negative |

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

## Implementation Notes

This R package is a **line-by-line translation** of the Python reference
(`disco.py` + `dctree.py`). Three bugs were found and fixed:

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

---

## Experimental Results

Six benchmark datasets validated. All differences are within machine epsilon (< 1e-14).

| Dataset | n | Clusters | DBSCAN | K-Means | Match |
|---|---|---|---|---|---|
| Concentric Circles | 300 | 2 | 0.6900921813 | 0.0270091908 | R == Python |
| Two Moons | 300 | 2 | 0.7012281111 | 0.2230356624 | R == Python |
| Complex9 | 3031 | 9 | 0.4209464514 | 0.0551096775 | R == Python |
| Complex8 | 2551 | 8 | 0.0718687652 | 0.0122574749 | R == Python |
| Dartboard1 | 1000 | 4 | 0.8743426861 | -0.0033636711 | R == Python |
| 3-Spiral | 312 | 3 | 0.5836514046 | -0.0014176359 | R == Python |

> **Note:** Negative K-Means scores on Dartboard1 and 3-Spiral are correct and
> expected — DISCO penalises algorithms that cut through ring or spiral structures.

---

## File Structure

```
Disco-R/
├── R/
│   └── disco.R              <- All functions (single combined file)
├── man/                     <- Auto-generated by devtools::document()
├── docs/
│   ├── algorithm.md         <- Mathematical foundations
│   ├── 02_implementation.md <- Bug reports and fixes
│   └── 03_experiments.md    <- Experimental results
├── experiments/
│   ├── sklearn-circle/      <- Concentric circles
│   ├── moons/               <- Two moons
│   ├── complex9/            <- Complex9 (9 clusters)
│   ├── complex8/            <- Complex8 (8 clusters)
│   ├── dartboard1/          <- Dartboard1 (4 rings)
│   └── spiral3/             <- 3-Spiral
├── data/                    <- .arff benchmark datasets
├── DESCRIPTION
├── NAMESPACE                <- Auto-generated by devtools::document()
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
# WRONG: dbscan() uses 0 for noise
labels <- dbscan(X, eps = 0.2)$cluster

# CORRECT: DISCO uses -1 for noise
labels <- dbscan(X, eps = 0.2)$cluster - 1L
```

---

## Citation

```bibtex
@article{beer2025disco,
  title   = {DISCO: Internal Evaluation of Density-Based Clustering},
  author  = {Beer, Anna and Krieger, Lena and Weber, Pascal and
             Ritzert, Martin and Assent, Ira and Plant, Claudia},
  journal = {arXiv preprint arXiv:2503.00127},
  year    = {2025}
}
```

**R Package:**
```
Amin Entezari (2025). disco: Density-based Internal Score for Clustering Outcomes.
R package. https://github.com/aminentezari/Disco-R
```

---

## License

MIT (c) Amin Entezari

Original Python implementation by Beer, Krieger, Weber, Ritzert, Assent, Plant (2025).

*For questions: amin_entezari@outlook.com*
