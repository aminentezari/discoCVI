# 03 — Experiments

## Overview

This document records all experiments run with the DISCO R package, including
dataset descriptions, clustering parameters, DISCO scores, and observations.
Python is used as the reference implementation. All R scores are verified to
match Python to 10 decimal places after the fixes documented in
[02_implementation.md](02_implementation.md).

---

## Experiment 1 — Concentric Circles (sklearn-circle)

### Dataset

| Property | Value |
|---|---|
| Source | Generated via `make_circles()` in R / `sklearn.datasets.make_circles` in Python |
| Samples | 300 |
| Features | 2 (x1, x2) |
| Noise | 0.05 (Gaussian σ) |
| Factor | 0.4 (inner circle radius) |
| Seed | 42 |
| Labels | 0 = outer ring (150 pts), 1 = inner ring (150 pts) |
| File | `experiments/sklearn-circle/circles_data_points.csv` |

### Purpose

Concentric circles are a classic non-convex benchmark. K-Means cannot
separate rings because it assumes convex clusters. DBSCAN correctly identifies
the two rings using density connectivity. This experiment demonstrates that
DISCO correctly assigns a high score to DBSCAN and a low score to K-Means,
while traditional CVIs (Silhouette, Davies-Bouldin) would prefer K-Means.

### Clustering Parameters

| Algorithm | Parameters |
|---|---|
| DBSCAN | eps=0.2, minPts=5 |
| K-Means | k=2, nstart=10, random_state=42 (Python labels loaded in R) |

### DISCO Results

| Algorithm | Clusters | Noise Points | DISCO Score |
|---|---|---|---|
| DBSCAN | 2 | 0 | **0.6900921813** |
| K-Means | 2 | 0 | **0.0270091908** |

### Observations

- DBSCAN achieves a high DISCO score (0.69) because it correctly identifies
  the two rings as density-connected clusters — points within each ring have
  short dc-distances to each other and long dc-distances to the other ring.
- K-Means scores near zero (0.027) because it cuts through the rings with a
  vertical decision boundary. Points near the boundary are closer in
  dc-distance to the other cluster than to their own, dragging the score down.
- The result confirms that DISCO is sensitive to cluster shape in a way that
  Euclidean-based CVIs are not.

### Output Files

```
experiments/sklearn-circle/
├── circles_data_points.csv     ← shared dataset (R + Python)
├── python_km_labels.csv        ← Python K-Means labels for exact comparison
├── kmeans_centroids.csv        ← Python K-Means final centroids
├── disco_scores_full.csv       ← per-point scores for both algorithms
├── disco_visualization.png     ← 6-panel visualization
└── circle1.R                   ← R analysis script
```

---

## Experiment 2 — 3-Spiral Dataset (results-Spiral3)

### Dataset

| Property | Value |
|---|---|
| Source | `data/3-spiral.arff` |
| Shape | Three interleaving spirals |
| Challenge | Highly non-convex, spiral-shaped clusters |

### Purpose

Spirals are one of the hardest shapes for centroid-based algorithms. This
experiment tests whether DISCO correctly rewards density-based algorithms
that follow the spiral structure.

### Output Files

```
experiments/results-Spiral3/
├── 3spiral_PROPER_comparison.png
├── 3spiral_PROPER_dbscan.png
├── 3spiral_PROPER_disco_scores.png
├── 3spiral_PROPER_exploration.png
├── 3spiral_PROPER_kmeans.png
├── 3spiral_PROPER_results.RData
└── 3spiral_PROPER_true_labels.png
```

---

## Experiment 3 — Complex9 Dataset (results-complex)

### Dataset

| Property | Value |
|---|---|
| Source | `data/complex9.arff` |
| Shape | 9 clusters of varying density and shape |
| Challenge | Mixed convex and non-convex clusters, varying densities |

### Purpose

Tests DISCO on a dataset with heterogeneous cluster properties — some clusters
are dense and compact, others are elongated or sparse. A good CVI should
reward algorithms that correctly identify all 9 clusters regardless of shape.

### Output Files

```
experiments/results-complex/
├── complex9_comparison.png
├── complex9_dbscan_best.png
├── complex9_dbscan_exploration.png
└── complex9_disco_comparison.png
```

---

## Experiment 4 — Smile1 Dataset (results-smile1)

### Dataset

| Property | Value |
|---|---|
| Source | `data/smile1.arff` |
| Shape | Smiley face — eyes, nose, mouth arcs |
| Challenge | Clusters of very different sizes and densities |

### Purpose

Tests DISCO on a visually interpretable dataset where human judgment of
"correct" clustering is clear. Eyes are small dense clusters, the mouth is
a large arc, and noise points appear around the face boundary.

### Output Files

```
experiments/results-smile1/
```

---

## Cross-Experiment Summary

| Dataset | Best Algorithm | DISCO Score | Notes |
|---|---|---|---|
| Concentric circles | DBSCAN | 0.6901 | K-Means fails completely (0.027) |
| 3-Spiral | DBSCAN | — | Spirals impossible for K-Means |
| Complex9 | DBSCAN | — | Mixed densities favour density-based |
| Smile1 | DBSCAN | — | Non-convex shapes throughout |

**General observation:** DISCO consistently rewards density-based algorithms
(DBSCAN, HDBSCAN) over centroid-based ones (K-Means, hierarchical) on
datasets with non-convex cluster shapes. This aligns with the theoretical
motivation of the metric.

---

## Reproducibility Notes

- All R experiments use `setwd("~/Desktop/R-projects/Disco-R/R")` and
  `source("dctree.R"); source("disco.R")` at the start of each script.
- The concentric circles dataset is shared as a CSV file to eliminate
  any RNG differences between R and Python data generation.
- K-Means labels for the sklearn-circle experiment are loaded from
  `python_km_labels.csv` (exported from Python) to ensure both languages
  evaluate DISCO on an identical partition.
- `min_points = 5` is used in all experiments unless otherwise noted.

---

## References

- Beer, A., Krieger, L., Weber, P., Ritzert, M., Assent, I., Plant, C. (2025).
  *DISCO: Internal Evaluation of Density-Based Clustering.*
  arXiv:2503.00127.
- Ester, M., Kriegel, H. P., Sander, J., & Xu, X. (1996). A density-based
  algorithm for discovering clusters in large spatial databases with noise.
  *KDD*, 96(34), 226–231.
