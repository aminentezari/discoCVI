# DISCO: Density-based Internal Score for Clustering Outcomes
## Algorithm and Implementation Guide

---

## Table of Contents

1. [Overview](#overview)
2. [The Problem DISCO Solves](#the-problem)
3. [Core Concepts](#core-concepts)
4. [Mathematical Foundation](#mathematical-foundation)
5. [Algorithm Workflow](#algorithm-workflow)
6. [Implementation Structure](#implementation-structure)
7. [Function Descriptions](#function-descriptions)
8. [Example Usage](#example-usage)
9. [Results Interpretation](#results-interpretation)

---

## 1. Overview

**DISCO** is a **Cluster Validity Index (CVI)** that evaluates the quality of
density-based clustering results **without needing ground truth labels**.

### Key Properties

Unlike traditional CVIs (like Silhouette Coefficient), DISCO:
- Handles **arbitrary-shaped clusters** (not just spherical)
- Evaluates **noise point quality** explicitly
- Uses **density-connectivity distance** instead of Euclidean distance
- Returns scores between **-1 (worst)** and **1 (best)**

### Paper Reference

- **Authors**: Beer, Krieger, Weber, Ritzert, Assent, Plant (2025)
- **Title**: DISCO: Internal Evaluation of Density-Based Clustering
- **arXiv**: 2503.00127

---

## 2. The Problem DISCO Solves

### Traditional CVI Limitations

**Problem 1: Shape Assumption**

Traditional CVIs (Silhouette, Davies-Bouldin) assume clusters are convex
(spherical/elliptical) and use Euclidean distance. On non-convex data such
as two moons or concentric circles, K-Means produces a better Silhouette
score than DBSCAN even though DBSCAN is correct.

**Problem 2: Noise Handling**

Existing CVIs either ignore noise points, treat them as a cluster, or filter
them out — none explicitly evaluates whether the noise labels are correct.

### DISCO's Solution

DISCO uses:
1. **Density-Connectivity Distance (dc-distance)** — captures density-based
   cluster structure rather than Euclidean geometry
2. **Explicit Noise Evaluation** — p_sparse checks if noise is in sparse
   regions; p_far checks if noise is remote from clusters

---

## 3. Core Concepts

### 3.1 Core Distance

**Definition**: Distance to the k-th nearest neighbor.

For point x with parameter mu (min_points):

    k(x) = distance to (mu-1)-th nearest neighbor

Low core distance indicates a dense region. High core distance indicates
a sparse region.

### 3.2 Mutual Reachability Distance

**Purpose**: Smooth out density variations between points.

    dm(x, y) = max(k(x), k(y), d_euclidean(x, y))

If either x or y is in a sparse area, the mutual reachability distance is
large. Both points must be in dense regions for the distance to be small.

### 3.3 Density-Connectivity Distance (dc-distance)

**Key idea**: Minimax path distance through dense regions.

Steps:
1. Build complete graph with dm as edge weights
2. Compute Minimum Spanning Tree (MST)
3. dc-distance = maximum edge weight on the unique path in the MST

A path through dense regions has a small maximum edge. A path that must
cross a sparse gap has a large maximum edge, which captures the
density-connectivity structure.

---

## 4. Mathematical Foundation

### 4.1 DISCO Score for Cluster Points

For point x in cluster C_x:

    a = average dc-distance to other points in C_x  (compactness)
    b = average dc-distance to nearest other cluster (separation)

    p(x) = (b - a) / max(a, b)    in [-1, 1]

- p = +1: Point is well inside its cluster, far from others
- p =  0: Point is on the boundary between clusters
- p = -1: Point is closer to another cluster than its own

### 4.2 DISCO Score for Noise Points

Two conditions must be satisfied for a noise point to be correctly labelled.

**Condition 1: p_sparse (Sparseness)**

Is the noise point in a region sparser than the clusters?

Let k_max(C) = max core distance in cluster C (the cluster's density threshold).

    p_sparse(x_n) = min over all C of:
        (k(x_n) - k_max(C)) / max(k(x_n), k_max(C))

High p_sparse means x_n is sparser than all clusters (good noise label).
Negative p_sparse means x_n is denser than a cluster (bad noise label).

**Condition 2: p_far (Remoteness)**

Is the noise point far from all clusters in dc-distance?

Let d_min(x_n, C) = minimum dc-distance from x_n to any point in C.

    p_far(x_n) = min over all C of:
        (d_min(x_n, C) - k_max(C)) / max(d_min(x_n, C), k_max(C))

**Combined noise score**:

    p(x_n) = min(p_sparse(x_n), p_far(x_n))

Both conditions must be satisfied simultaneously.

### 4.3 Overall DISCO Score

    DISCO = (1/n) * sum of p(x_i) for all i

    where p(x_i) = p_cluster(x_i)  if x_i is a cluster point
                 = p_noise(x_i)    if x_i is a noise point

---

## 5. Algorithm Workflow

### Main Algorithm: disco_score(X, labels, min_points)

**Input:**
- X: n x d data matrix
- labels: n-dimensional vector (cluster IDs, -1 for noise)
- min_points: parameter mu for density computation

**Output:** Single number in [-1, 1]

**Steps:**

1. Handle edge cases:
   - All noise: return -1 for all points
   - Single cluster, no noise: return 0 for all points

2. Compute DC-distances:
   - Core distances via FNN::get.knn with k = min_points - 1
   - Mutual reachability distances: element-wise max
   - MST via Prim's algorithm (exact port from Python)
   - Extract dc-distances via BFS minimax path traversal

3. Score cluster points via p_cluster

4. Score noise points via p_noise

5. Return mean of all scores

### Time and Space Complexity

- Time: O(n^3) — dominated by dc-distance extraction
- Space: O(n^2) — for the distance matrices

---

## 6. Implementation Structure

### File Organization

    discoCVI/
    |-- R/
    |   |-- disco.R       <- All functions (DC-distance + scoring + utilities)
    |-- man/              <- Documentation (auto-generated by devtools::document)
    |-- DESCRIPTION       <- Package metadata
    |-- NAMESPACE         <- Exported functions
    |-- LICENSE
    |-- README.md

All functions are combined in a single file `R/disco.R` with three logical
sections: DC-distance infrastructure, DISCO scoring functions, and utilities.

---

## 7. Function Descriptions

### Core Scoring Functions

#### disco_score(X, labels, min_points = 5)

Returns the mean DISCO score for the entire clustering.

    Input:  X (n x d matrix), labels (integer vector), min_points (integer)
    Output: Single numeric in [-1, 1]

#### disco_samples(X, labels, min_points = 5)

Returns per-point DISCO scores. Useful for identifying problematic points.

    Output: Numeric vector of length n

#### p_cluster(X, labels, min_points, precomputed_dc_dists)

Silhouette-style score using dc-distances. Note: -1 is treated as a valid
cluster label here, not as noise.

#### p_noise(X, labels, min_points, dc_dists)

Evaluates noise point quality. Returns list(p_sparse, p_far).

### DC-Distance Functions

#### compute_dc_distances(X, min_points = 5)

Main entry point for the DC-distance matrix. Calls the three sub-functions
below in sequence.

    Output: n x n symmetric distance matrix

#### calculate_reachability_distance(points, min_points)

Computes the n x n mutual-reachability distance matrix. Uses
FNN::get.knn with k = min_points - 1 (matches Python's self-inclusive
np.partition behaviour).

#### get_mst_edges(dist_matrix)

Minimum spanning tree via exact port of Python's _get_mst_edges()
(dctree.py lines 401-438). Preserves the same argmin tie-breaking.

    Output: data.frame with columns i, j, dist (n-1 edges)

#### extract_dc_distances_from_mst(mst_edges, n)

BFS minimax path traversal over the MST. The dc-distance between two
points equals the maximum edge weight on the unique path in the MST.

    Output: n x n symmetric DC-distance matrix

### Utility Functions

#### make_moons(n_samples, noise, random_state)

Generates two interleaving half-circles.

#### make_circles(n_samples, noise, factor, random_state)

Generates concentric circles.

#### make_blobs(n_samples, centers, std, random_state)

Generates Gaussian blobs.

#### plot_disco_scores(X, labels, scores, main)

Scatter plot with red-yellow-green colour scale for DISCO scores.

#### compare_clusterings(X, clustering_list, min_points)

Evaluates and ranks multiple clustering results. Returns a data frame
sorted by DISCO score.

#### summary_disco_scores(scores)

Returns mean, median, min, max, SD, quantiles, n_negative, n_positive.

---

## 8. Example Usage

### Basic Workflow

```r
library(discoCVI)
library(dbscan)

# Generate data
data <- make_moons(n_samples = 300, noise = 0.05, random_state = 42)
X    <- data$X

# Cluster
db_labels <- dbscan(X, eps = 0.2, minPts = 5)$cluster - 1L
km_labels <- kmeans(X, centers = 2, nstart = 10)$cluster - 1L

# Evaluate
disco_score(X, db_labels)   # 0.701
disco_score(X, km_labels)   # 0.223

# Per-point analysis
scores <- disco_samples(X, db_labels)
bad_points <- which(scores < 0)

# Compare algorithms
compare_clusterings(X, list(DBSCAN = db_labels, KMeans = km_labels))

# Visualise
plot_disco_scores(X, db_labels, scores)
```

### Precomputing DC-Distances

When comparing multiple clusterings on the same data, precompute once:

```r
D  <- compute_dc_distances(X, min_points = 5)
s1 <- p_cluster(D, labels1, precomputed_dc_dists = TRUE)
s2 <- p_cluster(D, labels2, precomputed_dc_dists = TRUE)
```

---

## 9. Results Interpretation

### Score Ranges

| Score | Quality | Meaning |
|---|---|---|
| 0.7 - 1.0 | Excellent | Well-separated, compact clusters |
| 0.4 - 0.7 | Good | Clear cluster structure |
| 0.0 - 0.4 | Moderate | Overlapping or touching clusters |
| -0.3 - 0.0 | Poor | Misassigned points |
| -1.0 - -0.3 | Very poor | Clustering actively harmful |

### Comparison with Other CVIs

On the Two Moons dataset:

| Method | Silhouette | Davies-Bouldin | DISCO |
|---|---|---|---|
| DBSCAN (correct) | -0.16 | 2.8 (bad) | 0.68 |
| K-Means (wrong) | 0.37 | 0.6 (good) | 0.22 |

Silhouette and Davies-Bouldin prefer K-Means. DISCO correctly identifies
DBSCAN as the better algorithm.

### When to Use DISCO

Use DISCO when:
- Clusters have arbitrary shapes
- Using density-based algorithms (DBSCAN, HDBSCAN, OPTICS)
- Noise points are present and their quality matters
- Comparing different clustering approaches
- Tuning hyperparameters (eps, minPts)

Do not use DISCO when:
- Clusters are clearly convex (use Silhouette instead)
- Very large datasets (n > 5000) where O(n^3) is prohibitive

### min_points Parameter

The default value of 5 works well for most datasets.

- Small values (2-3): sensitive to noise, may fragment clusters
- Large values (10-20): smoother scores, may miss small clusters
- Rule of thumb: use min_points = max(5, log(n))

### Common Pitfall

```r
# WRONG: dbscan() uses 0 for noise
labels <- dbscan(X, eps = 0.2)$cluster

# CORRECT: DISCO uses -1 for noise
labels <- dbscan(X, eps = 0.2)$cluster - 1L
```

---

## References

1. Beer, A., Krieger, L., Weber, P., Ritzert, M., Assent, I., Plant, C. (2025).
   DISCO: Internal Evaluation of Density-Based Clustering. arXiv:2503.00127.

2. Rousseeuw, P.J. (1987). Silhouettes: A graphical aid to the interpretation
   and validation of cluster analysis. Journal of Computational and Applied
   Mathematics, 20, 53-65.

3. Ester, M., Kriegel, H.P., Sander, J., Xu, X. (1996). A density-based
   algorithm for discovering clusters in large spatial databases with noise.
   Proceedings of KDD, 226-231.
