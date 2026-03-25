# 02 — Implementation Notes: R Translation from Python

## Overview

This document records the technical process of translating the DISCO metric
from the Python reference implementation (`disco.py`, `dctree.py`) into R
(`disco.R`, `dctree.R`). It documents every numerical difference found between
the two languages, the root cause of each, and the exact fix applied.

**Reference:** Python implementation by Beer, Krieger, Weber, Ritzert, Assent, Plant (2025)  
**R translation:** Amin Entezari (2025)  
**Verification dataset:** Concentric circles — n=300, noise=0.05, factor=0.4, seed=42

---

## Verification Target

After all fixes, R and Python must produce identical scores to 10 decimal places:

```
DISCO — DBSCAN  : 0.6900921813  ✅
DISCO — K-Means : 0.0270091908  ✅
```

---

## Bug 1 — Core Distance Off-by-One

### Location
- `disco.R` → `calculate_reachability_distance()`
- `disco.R` → `p_noise()`

### Root Cause

Python's `dctree.py` computes core distances as follows (line 710):

```python
reach_dists[i] = np.max(np.partition(eucl_dists[i], min_points)[:min_points])
```

`eucl_dists[i]` is a row of the full pairwise distance matrix, which
**includes the point itself at distance 0**. So `np.partition(..., 5)[:5]`
returns the 5 smallest values: `[0, d1, d2, d3, d4]`. The maximum of these
is `d4` — the **4th nearest neighbor**.

R's `FNN::get.knn(X, k = min_points)` **excludes the point itself**, so
`k = 5` returns the 5th nearest neighbor — one neighbor further than Python.

### Effect

Core distances were systematically larger in R than in Python, which made
mutual reachability distances larger, which changed the MST structure and
all dc-distances computed from it.

### Fix

In both `dctree.R` and `disco.R`:

```r
# BEFORE (wrong — finds 5th neighbor, Python finds 4th)
knn_result <- FNN::get.knn(X, k = min_points)
core_dists <- knn_result$nn.dist[, min_points]

# AFTER (correct — matches Python's self-inclusive partition)
k          <- min_points - 1
knn_result <- FNN::get.knn(X, k = k)
core_dists <- knn_result$nn.dist[, k]
```

### Files Changed
- `R/disco.R` — `calculate_reachability_distance()` and `p_noise()`

---

## Bug 2 — MST Tie-Breaking Difference

### Location
- `disco.R` → `compute_mst()` → replaced entirely with `get_mst_edges()`

### Root Cause

When two candidate edges in Prim's algorithm have **equal weight** (which
occurs frequently in the mutual reachability distance matrix because many
distances are floored to the core distance value), the choice of which edge
to add next is determined by a tie-breaking rule.

- **Python** uses a custom Prim's implementation (`_get_mst_edges()`,
  `dctree.py` lines 401–438) with `np.argmin` applied to
  `nodes_min_dist[not_in_mst]`
- **R** used `igraph::mst(algorithm = "prim")` which has its own internal
  tie-breaking order

These produce **different MSTs** when edge weights are equal, resulting in
different dc-distances and therefore different DISCO scores.

### Effect

Even after fixing Bug 1, DBSCAN matched (0.6900921813) but K-Means still
differed (R: 0.0257201707 vs Python: 0.0270091908). The K-Means case is more
sensitive to MST tie-breaking because its clusters span both rings and more
equal-weight edges appear in the boundary region.

### Fix

Replaced `igraph::mst` with an exact R port of Python's `_get_mst_edges()`,
preserving the same Prim's algorithm, same starting node, and same `argmin`
tie-breaking:

```r
# Python _get_mst_edges() lines 401-438 ported to R
get_mst_edges <- function(dist_matrix) {
  n              <- nrow(dist_matrix)
  nodes_min_dist <- rep(Inf, n)
  parent         <- rep(1L, n)
  not_in_mst     <- rep(TRUE, n)
  u              <- 1L                   # start node (Python node 0 = R node 1)
  nodes_min_dist[u] <- 0
  not_in_mst[u]     <- FALSE

  for (step in seq_len(n - 1)) {
    update_mask <- not_in_mst & (dist_matrix[u, ] < nodes_min_dist)
    if (any(update_mask)) {
      nodes_min_dist[update_mask] <- dist_matrix[u, update_mask]
      parent[update_mask]         <- u
    }
    candidates <- which(not_in_mst)
    u          <- candidates[which.min(nodes_min_dist[candidates])]
    ...
  }
}
```

The dc-distances are then extracted via a BFS minimax path traversal over
the resulting MST adjacency list.

### Files Changed
- `R/disco.R` — `compute_mst()` removed, `get_mst_edges()` added

---

## Bug 3 — K-Means Cross-Language Non-Determinism

### Location
- `experiments/sklearn-circle/circle1.R` — clustering section

### Root Cause

`set.seed(42)` in R and `random_state=42` in Python control **different
random number generators**. Although both use Mersenne Twister, the
implementations differ, producing different random sequences from the
same integer seed. As a result, K-Means centroid initialization differed:

| | Cluster 0 | Cluster 1 | Centroid 0 | Centroid 1 |
|---|---|---|---|---|
| Python | 144 points | 156 points | (0.462, 0.114) | (−0.402, −0.172) |
| R | 148 points | 152 points | (0.460, 0.077) | (−0.423, −0.143) |

The two runs converged to **different local optima**, making direct
numerical comparison of DISCO scores impossible regardless of the correctness
of the DISCO implementation.

### Effect

DISCO was being evaluated on different partitions in R and Python, producing
structurally different scores that could never match.

### Fix

Export Python's final K-Means labels as CSV and load them directly in R,
ensuring both languages evaluate DISCO on the **identical partition**:

```python
# Python — export final labels
import pandas as pd
pd.DataFrame({"km_label": km.labels_}).to_csv("python_km_labels.csv", index=False)
```

```r
# R — load Python labels instead of rerunning K-Means
km_df     <- read.csv(".../python_km_labels.csv")
km_labels <- as.integer(km_df$km_label)
```

### Files Changed
- `experiments/sklearn-circle/circle1.R` — K-Means block
- `experiments/sklearn-circle/python_km_labels.csv` — added (609 B)

---

## Summary Table

| # | Bug | Location | Root Cause | Fix |
|---|---|---|---|---|
| 1 | Core distance off-by-one | `disco.R` (`calculate_reachability_distance`, `p_noise`) | Python includes self (dist=0) in k-NN partition; FNN excludes self | `k = min_points - 1` |
| 2 | MST tie-breaking | `disco.R` (`get_mst_edges`) | `igraph::mst` and Python's Prim break equal-weight edges differently | Port Python's exact `_get_mst_edges()` to R |
| 3 | K-Means non-determinism | `circle1.R` | R and Python RNGs produce different sequences from same seed | Load Python labels from CSV |

---

## Verification

After all three fixes, R and Python produce identical scores:

```
Dataset : Concentric circles (n=300, noise=0.05, factor=0.4, seed=42)
min_points : 5

DISCO — DBSCAN  : 0.6900921813  ✅  (R == Python)
DISCO — K-Means : 0.0270091908  ✅  (R == Python)
```

Verified on: R 4.3.1 | Python 3.10 | Date: March 2026