# 03 — Experiments

## Overview

This document records all experiments run with the DISCO R package.
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
| DBSCAN | **0.6900921813** |
| K-Means | **0.0270091908** |

K-Means cuts through rings with a vertical boundary — near-zero score.

---

## Experiment 2 — Two Moons

| Property | Value |
|---|---|
| Source | `make_moons()` |
| n | 300 |
| Clusters | 2 crescents |
| DBSCAN | eps=0.2, minPts=5 |
| K-Means | k=2, Python labels |

| Algorithm | DISCO Score |
|---|---|
| DBSCAN | **0.7012281111** |
| K-Means | **0.2230356624** |

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
| DBSCAN | **0.5836514046** |
| K-Means | **-0.0014176359** |

Negative K-Means: spiral structure impossible for centroid-based clustering.

---

## Experiment 4 — Complex9

| Property | Value |
|---|---|
| Source | `data/complex9.arff` |
| n | 3031 |
| Clusters | 9 (mixed shapes) |
| DBSCAN | eps=15, minPts=5, Python labels |
| K-Means | k=9, Python labels |

| Algorithm | DISCO Score |
|---|---|
| DBSCAN | **0.4209464514** |
| K-Means | **0.0551096775** |

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
| DBSCAN | **0.0718687652** |
| K-Means | **0.0122574749** |

Low overall scores reflect density variation within clusters.

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
| DBSCAN | **0.8743426861** |
| K-Means | **-0.0033636711** |

Highest DBSCAN score (0.87). Lowest K-Means score (-0.003) — pizza-slice
boundary is maximally wrong on ring data.

---

## Cross-Experiment Summary

| Dataset | n | Clusters | DBSCAN | K-Means |
|---|---|---|---|---|
| Concentric Circles | 300 | 2 | 0.6901 | 0.0270 |
| Two Moons | 300 | 2 | 0.7012 | 0.2230 |
| 3-Spiral | 312 | 3 | 0.5837 | **-0.0014** |
| Complex9 | 3031 | 9 | 0.4209 | 0.0551 |
| Complex8 | 2551 | 8 | 0.0719 | 0.0123 |
| Dartboard1 | 1000 | 4 | **0.8743** | **-0.0034** |

DISCO consistently rewards DBSCAN. Negative K-Means scores on ring and spiral
datasets are correct — they reflect active misalignment between centroid
boundaries and density-connected structure.

---

## Reproducibility

- Python runs clustering first, exports labels as CSV
- R loads Python labels — guarantees identical partitions
- `min_points = 5` used throughout
