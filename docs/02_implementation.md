# 02 — Implementation Notes: R Translation from Python

## Overview

This document records the technical process of translating the DISCO metric
from the Python reference implementation (`disco.py`, `dctree.py`) into R.
It documents every numerical difference found between the two languages,
the root cause of each, and the exact fix applied.

**Reference:** Python implementation by Beer, Krieger, Weber, Ritzert,
Assent, Plant (2025). arXiv:2503.00127.

**R translation:** Amin Entezari (2025)

**Verification dataset:** Concentric circles — n=300, noise=0.05,
factor=0.4, seed=42

---

## Verification Target

After all fixes, R and Python must produce identical scores to 10 decimal
places:

```
DISCO — DBSCAN  : 0.6900921813
DISCO — K-Means : 0.0270091908
```

---

## Bug 1 — Core Distance Off-by-One

### Location

- `R/disco.R` — `calculate_reachability_distance()`
- `R/disco.R` — `p_noise()`

### Root Cause

Python (`dctree.py`, line 710) computes core distances as:

```python
reach_dists[i] = np.max(np.partition(eucl_dists[i], min_points)[:min_points])
```

`eucl_dists[i]` is a row of the full pairwise distance matrix which
**includes the point itself at distance 0**. So
`np.partition(..., 5)[:5]` returns `[0, d1, d2, d3, d4]` and the maximum
is `d4` — the **4th nearest neighbour**.

`FNN::get.knn(X, k = min_points)` **excludes the point itself**, so
`k = 5` returns the 5th nearest neighbour — one further than Python.

### Effect

Core distances were systematically larger in R than in Python, inflating
mutual reachability distances and changing the MST structure and all
dc-distances computed from it.

### Fix

```r
# BEFORE (wrong)
knn_result <- FNN::get.knn(X, k = min_points)
core_dists <- knn_result$nn.dist[, min_points]

# AFTER (correct)
k          <- min_points - 1
knn_result <- FNN::get.knn(X, k = k)
core_dists <- knn_result$nn.dist[, k]
```

---

## Bug 2 — MST Tie-Breaking Difference

### Location

- `R/disco.R` — MST construction replaced with `get_mst_edges()`

### Root Cause

When two candidate edges in Prim's algorithm have equal weight (which
occurs frequently because many distances are floored to the core distance
value), the tie-breaking rule determines which edge is added next.

- **Python** uses a custom Prim's implementation (`_get_mst_edges()`,
  `dctree.py` lines 401-438) with `np.argmin`
- **R (initial)** used `igraph::mst(algorithm = "prim")` which has
  different internal ordering

Different tie-breaking produces a different MST, different dc-distances,
and different DISCO scores.

### Effect

After fixing Bug 1, DBSCAN matched (0.6900921813) but K-Means still
differed (R: 0.0257 vs Python: 0.0270).

### Fix

Replaced `igraph::mst` with an exact R port of Python's
`_get_mst_edges()`:

```r
get_mst_edges <- function(dist_matrix) {
  n              <- nrow(dist_matrix)
  nodes_min_dist <- rep(Inf, n)
  parent         <- rep(1L, n)
  not_in_mst     <- rep(TRUE, n)
  u              <- 1L
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

---

## Bug 3 — K-Means Cross-Language Non-Determinism

### Location

- All experiment R scripts — K-Means clustering block

### Root Cause

`set.seed(42)` in R and `random_state=42` in Python both use Mersenne
Twister but with different implementations, producing different random
sequences from the same seed. K-Means centroid initialisation differed:

| | Cluster 0 | Cluster 1 | Centroid 0 | Centroid 1 |
|---|---|---|---|---|
| Python | 144 pts | 156 pts | (0.462, 0.114) | (-0.402, -0.172) |
| R | 148 pts | 152 pts | (0.460, 0.077) | (-0.423, -0.143) |

### Fix

Run K-Means in Python, export labels as CSV, load in R:

```python
# Python
pd.DataFrame({"km_label": km.labels_}).to_csv(
    "python_km_labels.csv", index=False)
```

```r
# R
km_labels <- as.integer(
  read.csv("python_km_labels.csv")$km_label)
```

This approach is also applied to DBSCAN for datasets where floating-point
differences in distance computation produce different cluster counts at
the exact boundary of eps.

---

## Summary

| # | Bug | Location | Root Cause | Fix |
|---|---|---|---|---|
| 1 | Core distance off-by-one | `calculate_reachability_distance`, `p_noise` | Python includes self in k-NN; FNN excludes self | `k = min_points - 1` |
| 2 | MST tie-breaking | `get_mst_edges` | `igraph::mst` tie-breaking differs from Python | Port Python's exact `_get_mst_edges()` |
| 3 | K-Means non-determinism | All experiment scripts | R and Python RNGs differ | Export Python labels as CSV; load in R |

---

## Verification

```
Dataset    : Concentric circles (n=300, noise=0.05, factor=0.4, seed=42)
min_points : 5

DISCO — DBSCAN  : 0.6900921813   (R == Python, difference < 1e-14)
DISCO — K-Means : 0.0270091908   (R == Python, difference < 1e-14)
```

Verified on: R 4.3.1 | Python 3.10 | April 2026
