# DISCO R Package

> **Density-based Internal Score for Clustering Outcomes**

R implementation of the DISCO metric — a Cluster Validity Index (CVI) for evaluating density-based clustering results, including explicit evaluation of noise point quality. Translated from the original Python reference implementation by Beer, Krieger, Weber et al. (2025).

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
- [File Structure](#file-structure)
- [Results Interpretation](#results-interpretation)
- [Citation](#citation)

---

## Overview

DISCO evaluates clustering quality **without ground truth labels** by using **density-connectivity distance (dc-distance)** instead of Euclidean distance. It is the first CVI that:

- Handles **arbitrary-shaped clusters** (not just convex/spherical)
- Explicitly evaluates **noise point quality** (not just cluster quality)
- Returns bounded, interpretable scores in **[−1, 1]**

---

## Why DISCO?

Traditional CVIs like Silhouette and Davies-Bouldin assume convex clusters and ignore noise. On non-convex data, they can rank a wrong algorithm higher than the correct one:

| Algorithm | Silhouette | Davies-Bouldin | **DISCO** |
|-----------|-----------|----------------|-----------|
| DBSCAN (correct) | −0.16 ❌ | 2.8 (bad) ❌ | **0.68 ✅** |
| K-Means (wrong) | 0.37 ✅ | 0.6 (good) ✅ | **0.22 ❌** |

DISCO correctly identifies DBSCAN as better on non-convex data.

---

## Installation

```r
# Install from GitHub
devtools::install_github("aminentezari/Disco-R")
```

**Dependencies** (installed automatically):
- `FNN` — fast k-nearest neighbor search
- `igraph` — minimum spanning tree computation
- `dbscan` — for clustering examples

---

## Quick Start

```r
library(disco)
library(dbscan)

# 1. Generate synthetic data
data   <- make_circles(n_samples = 300, noise = 0.05, factor = 0.4, random_state = 42)
X      <- data$X
y_true <- data$labels

# 2. Apply clustering algorithms
db_result <- dbscan(X, eps = 0.2, minPts = 5)
db_labels <- as.integer(db_result$cluster)
db_labels[db_labels == 0L] <- -1L          # 0 → -1 for noise

set.seed(42)
km_labels <- as.integer(kmeans(X, centers = 2, nstart = 10)$cluster) - 1L

# 3. Compute DISCO scores
disco_score(X, db_labels)   # → 0.6900921813
disco_score(X, km_labels)   # → 0.0270091908

# 4. Per-point scores
scores <- disco_samples(X, db_labels)
summary_disco_scores(scores)

# 5. Visualize
plot_disco_scores(X, db_labels, scores, main = "DBSCAN — DISCO Scores")

# 6. Compare algorithms
compare_clusterings(X, list(DBSCAN = db_labels, KMeans = km_labels))
```

---

## Function Reference

### Core Functions (`disco.R`)

#### `disco_score(X, labels, min_points = 5)`
Returns a **single number** summarising overall clustering quality.

```r
score <- disco_score(X, labels, min_points = 5)
# → 0.6900921813
```

| Argument | Type | Description |
|---|---|---|
| `X` | matrix / data.frame | n × p feature matrix |
| `labels` | integer vector | Cluster labels. Use `-1` for noise points |
| `min_points` | integer | k for dc-distance computation. Default: `5` |

**Returns:** Single numeric value in [−1, 1].

---

#### `disco_samples(X, labels, min_points = 5)`
Returns a **per-point score** — useful for identifying which points are problematic.

```r
scores      <- disco_samples(X, labels)
bad_points  <- which(scores < 0)
```

**Returns:** Numeric vector of length n, one score per data point.

---

### Utility Functions (`utils.R`)

#### `make_circles(n_samples, noise, factor, random_state)`
Generates a synthetic concentric circles dataset.

```r
data <- make_circles(n_samples = 300, noise = 0.05, factor = 0.4, random_state = 42)
X      <- data$X       # 300 × 2 matrix
labels <- data$labels  # 0 = outer ring, 1 = inner ring
```

#### `make_moons(n_samples, noise, random_state)`
Generates two interleaving half-circles.

```r
data <- make_moons(n_samples = 300, noise = 0.05, random_state = 42)
```

#### `plot_disco_scores(X, labels, scores, main, ...)`
Visualises pointwise DISCO scores with a red-yellow-green colour scale.

```r
scores <- disco_samples(X, labels)
plot_disco_scores(X, labels, scores, main = "DBSCAN Results")
```

#### `compare_clusterings(X, clustering_list, min_points = 5)`
Evaluates and ranks multiple clusterings in one call.

```r
results <- compare_clusterings(X, list(
  DBSCAN = db_labels,
  KMeans = km_labels
))
print(results)
#   Clustering DISCO_Score
# 1     DBSCAN  0.69009218
# 2     KMeans  0.02700919
```

#### `summary_disco_scores(scores)`
Returns descriptive statistics for a vector of pointwise scores.

```r
summary_disco_scores(disco_samples(X, labels))
# $mean, $median, $sd, $min, $max, $q25, $q75, $n_negative, $n_positive
```

---

## Algorithm

DISCO computes scores in four steps:

### Step 1 — Core Distance κ(x)
Distance from point x to its k-th nearest neighbor (controlled by `min_points`).
Low core distance → dense region. High core distance → sparse region.

```
κ(x) = d_euclidean(x, x_k)
```

### Step 2 — Mutual Reachability Distance
Smooths distances based on local density:

```
dm(x, y) = max( κ(x), κ(y), d_euclidean(x, y) )
```

### Step 3 — DC-Distance via MST
Build a complete graph with `dm` as edge weights, compute its Minimum Spanning Tree (MST), then the dc-distance between any two points is the **maximum edge weight on the unique path** between them in the MST (minimax path):

```
dc(x, y) = max edge weight on path x → y in MST
```

### Step 4 — DISCO Score per Point

**For cluster points** (silhouette-like with dc-distance):
```
a = mean dc-distance to own cluster
b = mean dc-distance to nearest other cluster

ρ(x) = (b − a) / max(a, b)     ∈ [−1, 1]
```

**For noise points** (must satisfy both conditions):
```
p_sparse = (κ(x_n) − κ_max(C)) / max(κ(x_n), κ_max(C))   ← is noise sparse?
p_far    = (dc_min(x_n, C) − κ_max(C)) / max(...)          ← is noise remote?

ρ_noise(x_n) = min(p_sparse, p_far)
```

**Overall DISCO score:**
```
DISCO = (1/n) Σ ρ(x_i)
```

---

## Implementation Notes

This R package is a **line-by-line translation** of the Python reference implementation. Three differences were identified and corrected during translation to ensure numerical equivalence:

### 1. Core Distance Off-by-One
Python's `np.partition(eucl_dists[i], k)[:k]` **includes the point itself** (distance = 0), so the effective core distance is the `(k−1)`-th nearest neighbor. R's `FNN::get.knn` **excludes the point itself**, requiring `k = min_points − 1` to match Python.

```r
# Fix applied in dctree.R and disco.R (p_noise):
k <- min_points - 1
knn_result <- FNN::get.knn(X, k = k)
core_dists <- knn_result$nn.dist[, k]
```

### 2. MST Tie-Breaking
When two candidate MST edges have equal weight, `igraph::mst` and Python's custom Prim implementation break ties differently, producing different spanning trees and therefore different dc-distances. The fix was to **port Python's exact `_get_mst_edges()` function** into R, replicating the same Prim's algorithm and `argmin` tie-breaking rule.

```r
# Python's Prim (dctree.py lines 401-438) ported exactly to R
get_mst_edges <- function(dist_matrix) { ... }
```

### 3. Cross-Language K-Means Non-Determinism
`set.seed(42)` in R and `random_state=42` in Python use different random number generators (different Mersenne Twister implementations), producing different K-Means partitions. For exact numerical comparison, Python's labels were exported as CSV and loaded in R:

```python
# Python — export labels
pd.DataFrame({"km_label": km.labels_}).to_csv("python_km_labels.csv", index=False)
```
```r
# R — load Python labels
km_labels <- as.integer(read.csv("python_km_labels.csv")$km_label)
```

After all three fixes, R and Python produce **identical DISCO scores to 10 decimal places**:

```
DISCO — DBSCAN  : 0.6900921813  ✅
DISCO — K-Means : 0.0270091908  ✅
```

---

## File Structure

```
Disco-R/
├── R/
│   ├── disco.R       ← Main user-facing functions
│   │                    disco_score(), disco_samples(),
│   │                    p_cluster(), p_noise()
│   ├── dctree.R      ← DC-distance computation (internal)
│   │                    compute_dc_distances(), get_mst_edges(),
│   │                    calculate_reachability_distance()
│   └── utils.R       ← Helper functions
│                        make_circles(), make_moons(),
│                        plot_disco_scores(), compare_clusterings()
├── sklearn-circle/
│   ├── circles_data_points.csv   ← Shared dataset (R + Python)
│   └── python_km_labels.csv      ← Python K-Means labels (for exact comparison)
├── DESCRIPTION
├── LICENSE
└── README.md
```

---

## Results Interpretation

| Score Range | Interpretation |
|---|---|
| 0.7 – 1.0 | Excellent — well-separated, compact clusters |
| 0.4 – 0.7 | Good — clear cluster structure |
| 0.0 – 0.4 | Moderate — overlapping or touching clusters |
| −0.3 – 0.0 | Poor — misassigned points |
| −1.0 – −0.3 | Very poor — clustering worse than random |

### Common Pitfalls

```r
# ❌ WRONG: dbscan() uses 0 for noise
labels <- dbscan(X, eps = 0.2)$cluster          # 0, 1, 2

# ✅ CORRECT: DISCO uses -1 for noise
labels <- dbscan(X, eps = 0.2)$cluster - 1      # -1, 0, 1
```

---

## Citation

If you use this package, please cite the original paper:

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

MIT © Amin Entezari

Original Python implementation by Beer, Krieger, Weber, Ritzert, Assent, Plant (2025).

---

*For questions or issues: [amin_entezari@outlook.com](mailto:amin_entezari@outlook.com) · [Open an issue](https://github.com/aminentezari/Disco-R/issues)*
