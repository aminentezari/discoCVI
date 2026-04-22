# 03 — Experiments

## Overview

This document records all experiments run with the discoCVI R package.
Python is the reference implementation. All R scores match Python to
10 decimal places after the fixes in [02_implementation.md](02_implementation.md).

---

## Experiment 1 — Concentric Circles

| Property | Value |
|---|---|
| Source | `make_circles()` |
| n | 300 |
| Clusters | 2 (outer/inner ring) |
| DBSCAN | eps=0.2, minPts=5 |
| K-Means | k=2, Python labels |

| Algorithm | DISCO Score |
|---|---|
| DBSCAN | 0.6900921813 |
| K-Means | 0.0270091908 |

K-Means cuts through rings with a vertical boundary, scoring near zero.
DBSCAN correctly separates both rings.

---

## Experiment 2 — Two Moons

| Property | Value |
|---|---|
| Source | `make_moons()` |
| n | 1000 |
| Clusters | 2 crescents |
| DBSCAN | eps=0.2, minPts=5 |
| K-Means | k=2, Python labels |

| Algorithm | DISCO Score |
|---|---|
| DBSCAN | 0.8179598377 |
| K-Means | 0.2832395719 |

---

## Experiment 3 — 3-Spiral

| Property | Value |
|---|---|
| Source | `data/3-spiral.arff` |
| n | 312 |
| Clusters | 3 spirals |
| DBSCAN | eps=2, minPts=3, Python labels |
| K-Means | k=3, Python labels |

| Algorithm | DISCO Score |
|---|---|
| DBSCAN | 0.5836514046 |
| K-Means | -0.0014176359 |

Negative K-Means score: spiral structure is impossible for centroid-based
clustering. DISCO correctly penalises this.

---

## Experiment 4 — Complex9

| Property | Value |
|---|---|
| Source | `data/complex9.arff` |
| n | 3031 |
| Clusters | 9 (mixed shapes and densities) |
| DBSCAN | eps=15, minPts=5, Python labels |
| K-Means | k=9, Python labels |

| Algorithm | DISCO Score |
|---|---|
| DBSCAN | 0.4209464514 |
| K-Means | 0.0551096775 |

---

## Experiment 5 — Complex8

| Property | Value |
|---|---|
| Source | `data/complex8.arff` |
| n | 2551 |
| Clusters | 8 (varying density) |
| DBSCAN | eps=10, minPts=5, Python labels |
| K-Means | k=8, Python labels |

| Algorithm | DISCO Score |
|---|---|
| DBSCAN | 0.0718687652 |
| K-Means | 0.0122574749 |

Low overall scores reflect high density variation within clusters. Both
algorithms struggle with this dataset.

---

## Experiment 6 — Dartboard1

| Property | Value |
|---|---|
| Source | `data/dartboard1.arff` |
| n | 1000 |
| Clusters | 4 concentric rings (250 each) |
| DBSCAN | eps=0.08, minPts=5, Python labels |
| K-Means | k=4, Python labels |

| Algorithm | DISCO Score |
|---|---|
| DBSCAN | 0.8743426861 |
| K-Means | -0.0033636711 |

Highest DBSCAN score across all experiments (0.874). K-Means produces a
pizza-slice boundary which is maximally wrong on ring data, resulting in
a negative score.

---

## Experiment 7 — Blobs

| Property | Value |
|---|---|
| Source | Generated via `MASS::mvrnorm` |
| n | 450 (150 per cluster) |
| Clusters | 3 Gaussian blobs |
| Centres | (1.5, 7.0), (6.5, 7.0), (4.0, 2.5) |
| Std | 0.55, seed=42 |
| DBSCAN | eps=0.5, minPts=5, Python labels |
| K-Means | k=3, Python labels |

| Algorithm | DISCO Score |
|---|---|
| DBSCAN | 0.8548953163 |
| K-Means | 0.8575691834 |

Both algorithms score above 0.85. Convex Gaussian clusters are well-suited
to both density-based and centroid-based methods. K-Means scores slightly
higher because the tight, spherical clusters align perfectly with centroid
boundaries.

---

## Experiment 8 — Diagonal Blobs

| Property | Value |
|---|---|
| Source | Generated via `MASS::mvrnorm` |
| n | 600 (200 per cluster) |
| Clusters | 3 elongated diagonal blobs |
| Centres | (2.5, 5.0), (0.5, 1.8), (-1.5, -1.5) |
| Covariance | [[1.2, -1.0], [-1.0, 1.2]], seed=42 |
| DBSCAN | eps=0.8, minPts=5, Python labels |
| K-Means | k=3, Python labels |

| Algorithm | DISCO Score |
|---|---|
| DBSCAN | 0.7215536253 |
| K-Means | 0.7043253397 |

Elongated but linearly separable clusters. Both algorithms perform well.
The negative covariance in the data matrix creates diagonal streaks which
are still separable by both methods.

---

## Cross-Experiment Summary

| Dataset | n | Clusters | DBSCAN | K-Means | K-Means negative? |
|---|---|---|---|---|---|
| Concentric Circles | 300 | 2 | 0.6901 | 0.0270 | No |
| Two Moons | 1000 | 2 | 0.8180 | 0.2832 | No |
| 3-Spiral | 312 | 3 | 0.5837 | -0.0014 | Yes |
| Complex9 | 3031 | 9 | 0.4209 | 0.0551 | No |
| Complex8 | 2551 | 8 | 0.0719 | 0.0123 | No |
| Dartboard1 | 1000 | 4 | 0.8743 | -0.0034 | Yes |
| Blobs | 450 | 3 | 0.8549 | 0.8576 | No |
| Diagonal Blobs | 600 | 3 | 0.7216 | 0.7043 | No |

DISCO consistently rewards DBSCAN on non-convex datasets. Negative K-Means
scores on Dartboard1 and 3-Spiral reflect active misalignment between
centroid boundaries and density-connected structure. On convex datasets
(Blobs, Diagonal Blobs) both algorithms score comparably, confirming that
DISCO does not artificially favour density-based methods.

---

## Reproducibility

- Python runs clustering first and exports labels as CSV
- R loads Python labels to guarantee identical partitions
- `min_points = 5` used throughout (min_samples = 3 for 3-Spiral DBSCAN)
- All numerical differences are within IEEE 754 floating-point precision
  (absolute difference < 1e-14 in all cases)
