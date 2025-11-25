# DISCO: Density-based Internal Score for Clustering Outcomes
## Complete Algorithm & Implementation Guide

---

## 📋 Table of Contents
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

## 1. Overview {#overview}

**DISCO** is a **Cluster Validity Index (CVI)** that evaluates the quality of density-based clustering results **without needing ground truth labels**.

### Key Innovation
Unlike traditional CVIs (like Silhouette Coefficient), DISCO:
- ✅ Handles **arbitrary-shaped clusters** (not just spherical)
- ✅ Evaluates **noise point quality** explicitly
- ✅ Uses **density-connectivity distance** instead of Euclidean distance
- ✅ Returns scores between **-1 (worst)** and **1 (best)**

### Paper Reference
- **Authors**: Beer, Krieger, Weber, Ritzert, Assent, Plant (2025)
- **Title**: "DISCO: Internal Evaluation of Density-Based Clustering"
- **ArXiv**: 2503.00127v1

---

## 2. The Problem DISCO Solves {#the-problem}

### Traditional CVI Limitations

**Problem 1: Shape Assumption**
```
Traditional CVIs (Silhouette, Davies-Bouldin) assume:
- Clusters are convex (spherical/elliptical)
- Distance = Euclidean

Example: Two Moons Dataset
┌─────────────────────────────┐
│    ●●●●●                    │  ← Two crescent shapes
│  ●●    ●●                   │     (density-connected)
│ ●        ●     ●●●●●        │
│●          ●  ●●    ●●       │
│●          ● ●        ●      │
│ ●        ●●          ●      │
│  ●●    ●●  ●        ●       │
│    ●●●●     ●●    ●●        │
│              ●●●●●          │
└─────────────────────────────┘

k-Means would cut through the moons → BAD
Silhouette would rate k-Means HIGHER than DBSCAN!
```

**Problem 2: Noise Handling**
```
Existing CVIs:
- Ignore noise points → Can't evaluate noise quality
- Treat noise as cluster → Artificially lowers score
- Filter noise → Misses the point of density-based clustering
```

### DISCO's Solution

```
DISCO uses:
1. Density-Connectivity Distance (dc-distance)
   → Captures density-based cluster structure
   
2. Explicit Noise Evaluation
   → p_sparse: Is noise in sparse regions?
   → p_far: Is noise far from clusters?
```

---

## 3. Core Concepts {#core-concepts}

### 3.1 Core Distance

**Definition**: Distance to the k-th nearest neighbor

```
For point x with parameter µ (min_points):
κ(x) = distance to µ-th nearest neighbor

Visual:
        x₃
       /
      /  x₂
     /  /
    / x₁     ← These are k-nearest neighbors
   x ←────────── Core distance = distance to x_µ
    \
     \
      x₄...xₙ
      
Low core distance  → Dense region
High core distance → Sparse region
```

**Formula**:
```
κ(x) = d_euclidean(x, x_µ)
```

---

### 3.2 Mutual Reachability Distance (MRD)

**Purpose**: Smooth out density variations

```
Between points x and y:
dm(x, y) = max(κ(x), κ(y), d_euclidean(x, y))

Intuition:
- If x or y is in sparse area → large dm
- Both must be dense for small dm
- "Mutual" = considers both points' density
```

**Example**:
```
Dense cluster:  ●●●●x●●●●
                      ↓ κ(x) = 0.1
                      
Sparse point:   y           κ(y) = 2.5
                ↓
                
d_euclidean(x,y) = 3.0

dm(x, y) = max(0.1, 2.5, 3.0) = 3.0
```

---

### 3.3 Density-Connectivity Distance (dc-distance)

**Key Idea**: Minimax path distance through dense regions

```
Steps:
1. Build complete graph with dm as edge weights
2. Compute Minimum Spanning Tree (MST)
3. dc-distance = maximum edge weight on unique path

Visual Example:
    a ─0.5─ b ─0.3─ c
    │       │       │
   0.8     0.4     0.6
    │       │       │
    d ─0.7─ e ─0.9─ f

MST keeps lightest edges maintaining connectivity:
    a ─0.5─ b ─0.3─ c
            │       │
           0.4     0.6
            │       │
            e ─────┘ f
            │
           0.7
            │
            d

dc(a, f) = max(0.5, 0.4, 0.6) = 0.6
         (path: a→b→e→c→f, max edge = 0.6)
```

**Why This Works**:
- Path through **dense regions** → small maximum edge
- Path must cross **sparse gap** → large maximum edge
- Captures **density-connectivity** structure

---

## 4. Mathematical Foundation {#mathematical-foundation}

### 4.1 DISCO Score for Cluster Points: ρ_cluster(x)

**Similar to Silhouette Coefficient, but with dc-distance**

```
For point x in cluster C_x:

a = average dc-distance to other points in C_x (compactness)
b = average dc-distance to nearest other cluster (separation)

         b - a
ρ(x) = ─────────
       max(a, b)

Range: [-1, 1]
- ρ = +1: Perfect (b >> a, well-separated)
- ρ =  0: Overlapping (a ≈ b)
- ρ = -1: Wrong cluster (a >> b, should be in other cluster)
```

**Example**:
```
Cluster 1: ●●●●●x●●●●  Cluster 2: ■■■■■■■
           ↑              (far away)
          point x

a = avg dc-dist within cluster 1 = 0.2
b = avg dc-dist to cluster 2     = 0.8

ρ(x) = (0.8 - 0.2) / 0.8 = 0.75 ← Good clustering!
```

---

### 4.2 DISCO Score for Noise Points: ρ_noise(x_n)

**Two conditions for good noise**:

#### Condition 1: p_sparse (Sparseness)
```
Is the noise point in a sparse region?

For noise point x_n:
κ(C) = max core distance in cluster C (density threshold)

         κ(x_n) - κ(C)
p_sparse = ────────────────
           max(κ(x_n), κ(C))

Take minimum over all clusters:
p_sparse(x_n) = min over all C

High p_sparse → x_n is indeed sparse (good noise label)
Low p_sparse  → x_n is dense (bad noise label)
```

**Visual**:
```
Cluster C: ●●●●●●●
           κ(C) = 0.3 (max core distance in cluster)
           
Noise point far away: n₁        κ(n₁) = 2.0
                      
p_sparse(n₁) = (2.0 - 0.3) / 2.0 = 0.85 ✅ Good!

Noise in dense area:  n₂ (among cluster points)
                      κ(n₂) = 0.2
                      
p_sparse(n₂) = (0.2 - 0.3) / 0.3 = -0.33 ❌ Bad! Should be cluster point!
```

---

#### Condition 2: p_far (Remoteness)
```
Is the noise point far from all clusters?

For noise point x_n and cluster C:
d_min = minimum dc-distance from x_n to any point in C
κ(C)  = cluster's density threshold

       d_min - κ(C)
p_far = ───────────────
        max(d_min, κ(C))

Take minimum over all clusters:
p_far(x_n) = min over all C

High p_far → x_n is far from clusters (good)
Low p_far  → x_n is close to cluster (should be included)
```

**Combined Noise Score**:
```
ρ_noise(x_n) = min(p_sparse(x_n), p_far(x_n))

Both conditions must be satisfied for good noise label!
```

---

### 4.3 Overall DISCO Score

```
             1
DISCO = ───────── Σ ρ(x_i)
           n    i=1

Where ρ(x_i) = { ρ_cluster(x_i)  if x_i is cluster point
               { ρ_noise(x_i)    if x_i is noise point
```

---

## 5. Algorithm Workflow {#algorithm-workflow}

### Main Algorithm: `disco_score(X, labels, min_points)`

```
┌────────────────────────────────────────────────────────────┐
│ INPUT:                                                     │
│   X          : n × d data matrix                          │
│   labels     : n-dimensional vector (cluster IDs + noise) │
│   min_points : parameter µ for density computation        │
│                                                            │
│ OUTPUT:                                                    │
│   score      : Single number in [-1, 1]                   │
└────────────────────────────────────────────────────────────┘

STEP 1: Handle Edge Cases
─────────────────────────
if only noise:
    return -1 for all points
    
if one cluster (no noise):
    return 0 for all points  (no separation to measure)
    
if one cluster + noise:
    → Special case (see below)
    
STEP 2: Compute DC-Distances
──────────────────────────────
dc_dists ← compute_dc_distances(X, min_points)
│
├─ Step 2a: Compute core distances
│   κ(x) ← distance to µ-th nearest neighbor for all x
│
├─ Step 2b: Compute mutual reachability distances
│   dm(x,y) ← max(κ(x), κ(y), d_euclidean(x,y)) for all pairs
│
├─ Step 2c: Build Minimum Spanning Tree
│   MST ← Prim's algorithm on dm graph
│
└─ Step 2d: Extract dc-distances
    dc(x,y) ← max edge weight on path from x to y in MST

STEP 3: Compute Scores for Cluster Points
───────────────────────────────────────────
for each cluster point x:
    cluster_scores[x] ← p_cluster(x, labels, dc_dists)
    │
    ├─ a ← avg dc-dist to same cluster
    ├─ b ← avg dc-dist to nearest other cluster
    └─ score ← (b - a) / max(a, b)

STEP 4: Compute Scores for Noise Points
─────────────────────────────────────────
for each noise point x_n:
    (p_sparse, p_far) ← p_noise(x_n, labels, dc_dists)
    │
    ├─ p_sparse: Compare κ(x_n) with max κ in clusters
    ├─ p_far: Compare min dc-dist to clusters
    └─ noise_scores[x_n] ← min(p_sparse, p_far)

STEP 5: Aggregate
──────────────────
DISCO ← mean(all scores)

return DISCO
```

---

### Detailed Sub-Algorithm: `compute_dc_distances(X, min_points)`

```
┌─────────────────────────────────────────────────────────┐
│ PURPOSE: Compute density-connectivity distance matrix  │
└─────────────────────────────────────────────────────────┘

INPUT: X (n × d matrix), µ (min_points)
OUTPUT: dc_dists (n × n matrix)

ALGORITHM:
──────────

1. COMPUTE CORE DISTANCES
   ┌─────────────────────────────────────┐
   │ for i = 1 to n:                    │
   │   neighbors ← k-NN(X[i], k=µ)      │
   │   κ[i] ← distance to µ-th neighbor │
   └─────────────────────────────────────┘
   
   Implementation: Use FNN::get.knn()
   Time: O(n log n) with KD-tree

2. COMPUTE MUTUAL REACHABILITY DISTANCE
   ┌─────────────────────────────────────────────┐
   │ dm ← n × n matrix                           │
   │ for i = 1 to n:                            │
   │   for j = 1 to n:                          │
   │     if i ≠ j:                              │
   │       d_eucl ← ||X[i] - X[j]||₂           │
   │       dm[i,j] ← max(κ[i], κ[j], d_eucl)   │
   └─────────────────────────────────────────────┘
   
   Time: O(n²)

3. COMPUTE MINIMUM SPANNING TREE
   ┌──────────────────────────────────────────┐
   │ Create weighted graph G from dm         │
   │ MST ← Prim's algorithm on G              │
   └──────────────────────────────────────────┘
   
   Implementation: igraph::mst()
   Time: O(n² log n)

4. EXTRACT DC-DISTANCES FROM MST
   ┌────────────────────────────────────────────┐
   │ dc_dists ← n × n matrix                    │
   │ for i = 1 to n:                           │
   │   for j = 1 to n:                         │
   │     path ← unique path from i to j in MST │
   │     dc_dists[i,j] ← max edge on path      │
   └────────────────────────────────────────────┘
   
   Implementation: igraph::shortest_paths()
   Time: O(n³) naive, O(n²) optimized

TOTAL TIME COMPLEXITY: O(n³)
SPACE COMPLEXITY: O(n²)
```

---

## 6. Implementation Structure {#implementation-structure}

### File Organization

```
Disco-R/
├── R/
│   ├── disco.R       ← Main DISCO functions
│   ├── dctree.R      ← DC-distance computation
│   └── utils.R       ← Helper functions
├── man/              ← Documentation (auto-generated)
├── examples/
│   └── Test_code.R   ← Test script
├── DESCRIPTION       ← Package metadata
├── NAMESPACE         ← Exported functions
└── README.md         ← Package documentation
```

---

## 7. Function Descriptions {#function-descriptions}

### 7.1 Main Functions (disco.R)

#### `disco_score(X, labels, min_points = 5)`
```r
Purpose: Compute mean DISCO score for entire clustering
Input:
  - X: n×d data matrix
  - labels: cluster labels (use -1 for noise)
  - min_points: parameter µ (default 5)
Output: Single score in [-1, 1]

Example:
  data <- make_moons(n_samples = 300)
  db <- dbscan(data$X, eps = 0.2, minPts = 5)
  score <- disco_score(data$X, db$cluster - 1)
  # score = 0.684 (good!)
```

#### `disco_samples(X, labels, min_points = 5)`
```r
Purpose: Compute pointwise DISCO scores
Input: Same as disco_score
Output: Vector of n scores (one per point)

Use case: Identify problematic points
  scores <- disco_samples(X, labels)
  bad_points <- which(scores < 0.3)
```

#### `p_cluster(X, labels, min_points, precomputed_dc_dists)`
```r
Purpose: Silhouette-like score using dc-distance
Input:
  - X: Data or dc-distance matrix
  - labels: Cluster labels (-1 treated as cluster!)
  - precomputed_dc_dists: TRUE if X is dc-distance matrix
Output: Vector of scores

Note: This is internal, called by disco_samples
```

#### `p_noise(X, labels, min_points, dc_dists)`
```r
Purpose: Evaluate noise point quality
Input:
  - X: Data matrix
  - labels: Labels with -1 for noise
  - dc_dists: Optional precomputed dc-distances
Output: List with p_sparse and p_far vectors

Returns:
  list(
    p_sparse = c(0.85, 0.92, ...),  # Sparseness scores
    p_far    = c(0.78, 0.81, ...)   # Remoteness scores
  )
```

---

### 7.2 DC-Distance Functions (dctree.R)

#### `compute_dc_distances(X, min_points = 5)`
```r
Purpose: Main function to compute dc-distance matrix
Algorithm:
  1. Core distances → FNN::get.knn()
  2. Mutual reachability distance → element-wise max
  3. MST → igraph::mst()
  4. Extract dc-distances → shortest paths in MST

Output: n×n symmetric distance matrix
```

#### `compute_core_distances(X, min_points)`
```r
Purpose: Distance to µ-th nearest neighbor
Implementation: Uses FNN package for efficient k-NN
Time: O(n log n)
```

#### `compute_mutual_reachability_distance(X, core_dists)`
```r
Purpose: Smooth distance considering local density
Formula: dm(i,j) = max(κ(i), κ(j), d_euclidean(i,j))
Time: O(n²)
```

#### `compute_mst(dist_matrix)`
```r
Purpose: Minimum spanning tree via Prim's algorithm
Implementation: Uses igraph package
Output: igraph MST object
```

#### `extract_dc_distances_from_mst(mst_graph, n)`
```r
Purpose: Compute minimax path distances from MST
Method: For each pair, find unique path, take max edge
Time: O(n³) but runs once per dataset
```

---

### 7.3 Utility Functions (utils.R)

#### `make_moons(n_samples, noise, random_state)`
```r
Purpose: Generate two interleaving half-circles
Parameters:
  - n_samples: Total points (split between moons)
  - noise: Gaussian noise std dev
  - random_state: Seed for reproducibility
  
Output: list(X = matrix, labels = vector)

Use: Test density-based clustering
```

#### `make_circles(n_samples, noise, factor, random_state)`
```r
Purpose: Generate concentric circles
Parameters:
  - factor: Inner/outer circle radius ratio
  
Use: Another non-convex test case
```

#### `plot_disco_scores(X, labels, scores, main)`
```r
Purpose: Visualize clustering with color-coded scores
Features:
  - Red = bad scores
  - Yellow = moderate
  - Green = good scores
  - X symbol for noise
```

#### `compare_clusterings(X, clustering_list, min_points)`
```r
Purpose: Rank multiple clustering algorithms
Input: Named list of labelings
Output: Data frame sorted by DISCO score

Example:
  results <- compare_clusterings(X, list(
    DBSCAN = db_labels,
    KMeans = km_labels,
    Hierarchical = hc_labels
  ))
```

#### `summary_disco_scores(scores)`
```r
Purpose: Statistical summary of pointwise scores
Output:
  - Mean, median, min, max, sd
  - Quartiles
  - Count of negative/positive/near-zero scores
```

---

## 8. Example Usage {#example-usage}

### Complete Workflow Example

```r
# ============================================================
# EXAMPLE: Comparing Clustering Algorithms
# ============================================================

library(disco)
library(dbscan)

# 1. GENERATE DATA
# ────────────────
data <- make_moons(n_samples = 300, noise = 0.05, random_state = 42)
X <- data$X
y_true <- data$labels

# Visualize
plot(X, col = y_true + 1, pch = 19, main = "Ground Truth")

# 2. APPLY CLUSTERING ALGORITHMS
# ───────────────────────────────

# DBSCAN (density-based)
db <- dbscan(X, eps = 0.2, minPts = 5)
labels_db <- db$cluster - 1  # Convert to 0-based

# k-Means (centroid-based)
km <- kmeans(X, centers = 2, nstart = 20)
labels_km <- km$cluster - 1

# Hierarchical (distance-based)
hc <- hclust(dist(X), method = "ward.D2")
labels_hc <- cutree(hc, k = 2) - 1

# 3. EVALUATE WITH DISCO
# ───────────────────────

disco_db <- disco_score(X, labels_db, min_points = 5)
disco_km <- disco_score(X, labels_km, min_points = 5)
disco_hc <- disco_score(X, labels_hc, min_points = 5)

# Results:
# DBSCAN:       0.684 ✅ Excellent
# k-Means:      0.215 ❌ Poor (cuts through moons)
# Hierarchical: 0.227 ❌ Poor (also cuts)

# 4. VISUALIZE RESULTS
# ────────────────────

par(mfrow = c(1, 3))

# DBSCAN
plot(X, col = labels_db + 2, pch = 19,
     main = sprintf("DBSCAN\nDISCO: %.3f", disco_db))

# k-Means
plot(X, col = labels_km + 2, pch = 19,
     main = sprintf("k-Means\nDISCO: %.3f", disco_km))

# Hierarchical
plot(X, col = labels_hc + 2, pch = 19,
     main = sprintf("Hierarchical\nDISCO: %.3f", disco_hc))

# 5. POINTWISE ANALYSIS
# ─────────────────────

scores_db <- disco_samples(X, labels_db)

# Plot with score colors
par(mfrow = c(1, 1))
plot_disco_scores(X, labels_db, scores_db, 
                  main = "DBSCAN - Pointwise DISCO Scores")

# Find problematic points
problematic <- which(scores_db < 0.3)
cat("Problematic points:", length(problematic), "\n")

# Summary statistics
summary_disco_scores(scores_db)
# Output:
# $mean:   0.684
# $median: 0.692
# $min:    0.467
# $max:    0.700
```

---

### Noise Evaluation Example

```r
# ============================================================
# EXAMPLE: Evaluating Noise Detection
# ============================================================

# Generate data with noise
set.seed(42)
X_clean <- make_moons(n_samples = 200, noise = 0.05)$X
X_noise <- matrix(runif(20 * 2, min = -1, max = 2), ncol = 2)
X_combined <- rbind(X_clean, X_noise)

# Apply DBSCAN
db <- dbscan(X_combined, eps = 0.2, minPts = 5)
labels <- db$cluster - 1

# Count noise points
n_noise <- sum(labels == -1)
cat("Noise points detected:", n_noise, "\n")

# Evaluate noise quality
noise_results <- p_noise(X_combined, labels, min_points = 5)

# Extract noise point scores
noise_mask <- labels == -1
p_sparse_vals <- noise_results$p_sparse
p_far_vals <- noise_results$p_far

# Analyze
cat("\nNoise Quality:\n")
cat("  p_sparse - mean:", mean(p_sparse_vals), "\n")
cat("  p_far    - mean:", mean(p_far_vals), "\n")

# High values = good noise labels
# Low/negative = should be cluster points

# Overall DISCO including noise
disco_total <- disco_score(X_combined, labels)
cat("\nOverall DISCO:", disco_total, "\n")
```

---

## 9. Results Interpretation {#results-interpretation}

### Score Ranges

```
┌─────────────────────────────────────────────────────┐
│ DISCO Score Interpretation                          │
├─────────────────────────────────────────────────────┤
│                                                     │
│  1.0  ────────────────────  Perfect                │
│         ↑                                           │
│  0.7  ──┤─────────────────  Excellent              │
│         │  Well-separated                           │
│  0.4  ──┤─────────────────  Good                   │
│         │  Clear structure                          │
│  0.0  ──┤─────────────────  Moderate/Overlapping   │
│         │  Clusters touch                           │
│ -0.3  ──┤─────────────────  Poor                   │
│         │  Misassigned                              │
│ -1.0  ──┴─────────────────  Very Poor              │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

### Comparison with Other CVIs

```
┌────────────────────────────────────────────────────────────┐
│ Dataset: Two Moons (Non-convex, density-based clusters)   │
├────────────────────────────────────────────────────────────┤
│                                                            │
│ Method        │ Silhouette │ Davies-Bouldin │ DISCO       │
│───────────────┼────────────┼────────────────┼─────────────│
│ DBSCAN        │ -0.16 ❌   │  2.8 (bad) ❌  │  0.68 ✅    │
│ (density)     │            │                │             │
│───────────────┼────────────┼────────────────┼─────────────│
│ k-Means       │  0.37 ✅   │  0.6 (good) ✅ │  0.22 ❌    │
│ (centroid)    │            │                │             │
└────────────────────────────────────────────────────────────┘

Observation:
- Silhouette & Davies-Bouldin prefer k-Means (WRONG!)
- DISCO correctly identifies DBSCAN as better
- Traditional CVIs fail on non-convex clusters
```

---

### Practical Guidelines

#### When to Use DISCO

✅ **Use DISCO when:**
- Clusters have arbitrary shapes
- Using density-based algorithms (DBSCAN, HDBSCAN, OPTICS)
- Noise points are important
- Need to compare different clustering approaches
- Hyperparameter tuning (eps, minPts)

❌ **Don't use DISCO when:**
- Clusters are clearly convex (k-Means is fine, use Silhouette)
- No noise in data
- Need very fast computation (DISCO is O(n³))

---

#### Hyperparameter Selection

**`min_points` (µ) parameter:**
```
Typical values: 5-10

- Too small (µ=2,3): Sensitive to noise, many small clusters
- Too large (µ>20): May miss small but valid clusters
- Rule of thumb: µ = 5 is good default
- For very small datasets: µ = 3 or 4
- For very large datasets: µ = 10-15
```

**Effect on scores:**
```
Higher µ → Smoother core distances → More stable scores
Lower µ  → Captures finer density variations
```

---

### Common Pitfalls

#### Pitfall 1: Wrong Label Convention
```r
# ❌ WRONG: dbscan returns 0 for noise
labels <- dbscan(X, eps=0.2)$cluster  
# → 0, 1, 2 (0 = noise)

# ✅ CORRECT: Convert to -1 for noise
labels <- dbscan(X, eps=0.2)$cluster - 1
# → -1, 0, 1 (-1 = noise)

disco_score(X, labels)  # Now works!
```

#### Pitfall 2: No Noise but Using -1
```r
# k-Means doesn't produce noise
labels_km <- kmeans(X, 3)$cluster - 1
# → 0, 1, 2 (all cluster points)

# This is fine! DISCO handles it
disco_score(X, labels_km)  # Works
```

#### Pitfall 3: Only Noise Points
```r
# If DBSCAN finds no clusters
db <- dbscan(X, eps=0.01, minPts=100)  # Too strict
all(db$cluster == 0)  # TRUE

labels <- db$cluster - 1  # All -1

disco_score(X, labels)  # Returns -1 (correct!)
```

---

### Debugging Low Scores

```
If DISCO score is unexpectedly low:

1. Check label range
   ✓ Noise should be -1
   ✓ Clusters should be 0, 1, 2, ...

2. Visualize the clustering
   plot(X, col = labels + 2, pch = 19)
   
3. Check pointwise scores
   scores <- disco_samples(X, labels)
   hist(scores)
   
4. Identify problematic points
   bad_idx <- which(scores < 0)
   plot(X, col = "gray", pch = 19)
   points(X[bad_idx, ], col = "red", pch = 19, cex = 2)

5. Try different min_points
   for (µ in c(3, 5, 7, 10)) {
     score <- disco_score(X, labels, min_points = µ)
     cat("µ =", µ, "→ DISCO =", score, "\n")
   }
```

---

## Summary

### What DISCO Does

1. **Evaluates density-based clusterings** using density-connectivity
2. **Scores cluster quality** via compactness & separation
3. **Explicitly evaluates noise** via sparseness & remoteness
4. **Returns interpretable scores** in [-1, 1] range
5. **Works on arbitrary shapes** unlike traditional CVIs

### Key Strengths

- ✅ Handles non-convex clusters
- ✅ Evaluates noise quality
- ✅ Based on solid mathematical foundation
- ✅ Comparable to Silhouette for convex cases
- ✅ Deterministic and reproducible

### Key Limitations

- ⚠️ O(n³) time complexity (slow for large n)
- ⚠️ Requires tuning min_points parameter
- ⚠️ Not suitable for very high dimensions (curse of dimensionality)

---

## References

1. **Original Paper**
   - Beer, A., Krieger, L., Weber, P., Ritzert, M., Assent, I., Plant, C. (2025)
   - "DISCO: Internal Evaluation of Density-Based Clustering"
   - arXiv:2503.00127v1 [cs.LG]

2. **Related Methods**
   - DBCV: Moulavi et al. (2014) - Density-Based Cluster Validation
   - Silhouette: Rousseeuw (1987) - Original silhouette coefficient
   - DBSCAN: Ester et al. (1996) - Density-based clustering

3. **R Implementation**
   - Package: `disco`
   - GitHub: https://github.com/aminentezari/Disco-R
   - Authors: Amin Entezari (R translation), Beer et al. (original Python)

---

**END OF DOCUMENTATION**

For questions or issues, contact: amin_entezari@outlook.com
