# DISCO R Package - File Structure Explanation

## Overview of the 3 Core Files

Your package has 3 main R source files in the `R/` folder:

```
R/
├── disco.R    ← Main user-facing functions (what YOU use)
├── dctree.R   ← DC-distance computation (internal, automatic)
└── utils.R    ← Helper functions (data generation, plotting)
```

---

##  disco.R - Main DISCO Functions

###  Purpose
Contains the **core clustering evaluation functions** - these are what you actually use to score clusterings.

###  Functions You USE Directly:

####  `disco_score(X, labels, min_points = 5)`
**What it does:** Computes the overall DISCO score (single number)

**When to use:** When you want **one number** to evaluate clustering quality

```r
# Example: Evaluate DBSCAN clustering
db <- dbscan(X, eps = 0.2, minPts = 5)
labels <- db$cluster - 1

score <- disco_score(X, labels, min_points = 5)
# Returns: 0.684 (one number)
```

**Returns:** Single number between -1 (worst) and 1 (best)

---

####  `disco_samples(X, labels, min_points = 5)`
**What it does:** Computes DISCO score **for each individual point**

**When to use:** When you want to find **which specific points** are problematic

```r
# Example: Find bad points
scores <- disco_samples(X, labels, min_points = 5)
# Returns: [0.68, 0.69, 0.47, ..., 0.70]  (300 scores)

# Find problematic points
bad_points <- which(scores < 0.3)
plot(X[bad_points, ], col = "red", pch = 19, cex = 2)
```

**Returns:** Vector of n scores (one per data point)

---

###  Internal Functions (You DON'T Call These Directly):

#### `p_cluster(X, labels, min_points, precomputed_dc_dists)`
**What it does:** Computes cluster quality score (like Silhouette but with dc-distance)

**Used by:** `disco_samples()` calls this automatically

**You don't use directly because:** `disco_samples()` handles this for you

```r
# You DON'T do this:
# p_cluster(X, labels)  

# disco_samples() calls p_cluster internally 
scores <- disco_samples(X, labels)
```

---

#### `p_noise(X, labels, min_points, dc_dists)`
**What it does:** Evaluates noise point quality (p_sparse and p_far)

**Used by:** `disco_samples()` calls this automatically for noise points

**You don't use directly because:** `disco_samples()` handles this for you

```r
# You DON'T do this:
# p_noise(X, labels)  

# disco_samples() handles noise automatically 
scores <- disco_samples(X, labels)  # Includes noise scores
```

---

###  How They Work Together:

```
┌─────────────────────────────────────────────────────────┐
│ YOU CALL:                                               │
│   disco_score(X, labels)                                │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ↓
         ┌────────────────────┐
         │ disco_samples()     │  ← Computes per-point scores
         └────────┬────────────┘
                  │
        ┌─────────┴─────────┐
        ↓                   ↓
  ┌──────────────┐   ┌─────────────┐
  │ p_cluster()  │   │ p_noise()   │  ← Internal workers
  │ (clusters)   │   │ (noise pts) │
  └──────────────┘   └─────────────┘
        │                   │
        └─────────┬─────────┘
                  ↓
         Average all scores
                  ↓
            Return 0.684
```

---

###  Summary of disco.R:

| Function | You Use? | Purpose | Output |
|----------|----------|---------|--------|
| `disco_score()` |  YES | Overall quality | One number |
| `disco_samples()` |  YES | Per-point quality | n numbers |
| `p_cluster()` |  NO | Internal: cluster scores | Auto-called |
| `p_noise()` |  NO | Internal: noise scores | Auto-called |

---

##  dctree.R - DC-Distance Computation

###  Purpose
Computes the **density-connectivity distance matrix** - the mathematical engine behind DISCO.

###  You DON'T Use These Directly

All functions in `dctree.R` are **internal** - they're automatically called by `disco_score()` and `disco_samples()`.

###  Functions (All Automatic):

#### `compute_dc_distances(X, min_points = 5)`
**What it does:** Computes full dc-distance matrix

**Called by:** `disco_samples()` automatically

**Algorithm:**
```
1. Core distances (κ)
   ↓
2. Mutual reachability distance (dm)
   ↓
3. Minimum spanning tree (MST)
   ↓
4. Extract dc-distances (minimax paths)
   ↓
   Returns: n×n distance matrix
```

**You don't call because:** Happens automatically inside DISCO functions

```r
# You DON'T do this:
# dc_dists <- compute_dc_distances(X)  

# It happens automatically:
disco_score(X, labels)  # ← Computes dc_dists internally 
```

---

#### `compute_core_distances(X, min_points)`
**What it does:** Distance to k-th nearest neighbor for each point

**Uses:** FNN package for efficient k-NN search

**Called by:** `compute_dc_distances()`

---

#### `compute_mutual_reachability_distance(X, core_dists)`
**What it does:** Smooths distances based on local density

**Formula:** `dm(x,y) = max(κ(x), κ(y), euclidean(x,y))`

**Called by:** `compute_dc_distances()`

---

#### `compute_mst(dist_matrix)`
**What it does:** Builds minimum spanning tree using Prim's algorithm

**Uses:** igraph package

**Called by:** `compute_dc_distances()`

---

#### `extract_dc_distances_from_mst(mst_graph, n)`
**What it does:** Finds minimax path between all point pairs

**Called by:** `compute_dc_distances()`

---

#### `DCTree()` and `dc_distances()`
**What it does:** Wrapper class for Python API compatibility

**You might use:** Only if you want to precompute dc-distances once

```r
# Advanced usage (optional):
dctree <- DCTree(X, min_points = 5)
dc_dists <- dc_distances(dctree)

# Then reuse for multiple labelings:
score1 <- disco_score(dc_dists, labels1, precomputed_dc_dists = TRUE)
score2 <- disco_score(dc_dists, labels2, precomputed_dc_dists = TRUE)

# But usually you just do:
disco_score(X, labels)  # ← Easier!
```

---

###  How dctree.R Functions Work Together:

```
┌──────────────────────────────────────────────────────────┐
│ disco_samples() calls:                                   │
│   compute_dc_distances(X, min_points)                    │
└─────────────────┬────────────────────────────────────────┘
                  │
                  ↓
    ┌─────────────────────────────┐
    │ compute_core_distances()    │  ← Step 1: k-NN distances
    └─────────────┬───────────────┘
                  ↓
    ┌─────────────────────────────────────────┐
    │ compute_mutual_reachability_distance()  │  ← Step 2: dm matrix
    └─────────────┬───────────────────────────┘
                  ↓
    ┌─────────────────────────────┐
    │ compute_mst()                │  ← Step 3: MST via Prim
    └─────────────┬───────────────┘
                  ↓
    ┌─────────────────────────────────┐
    │ extract_dc_distances_from_mst() │  ← Step 4: Minimax paths
    └─────────────┬───────────────────┘
                  ↓
            dc_dists matrix
              (n × n)
```

---

###  Summary of dctree.R:

| Function | You Use? | Purpose |
|----------|----------|---------|
| `compute_dc_distances()` | ❌ NO | Main dc-distance computation |
| `compute_core_distances()` | ❌ NO | k-NN distances |
| `compute_mutual_reachability_distance()` | ❌ NO | Density-aware distances |
| `compute_mst()` | ❌ NO | Minimum spanning tree |
| `extract_dc_distances_from_mst()` | ❌ NO | Minimax path distances |
| `DCTree()` |  RARELY | Optional: precompute dc-dists |

**Key Point:** You don't call these! They run automatically inside `disco_score()`.

---

## 3️⃣ utils.R - Utility Functions

###  Purpose
**Helper functions** for data generation, visualization, and analysis.

###  Functions You USE:

####  `make_moons(n_samples, noise, random_state)`
**What it does:** Generates two interleaving half-circles (synthetic data)

**When to use:** Testing, demonstrations, tutorials

```r
# Example: Generate test data
data <- make_moons(n_samples = 300, noise = 0.05, random_state = 42)
X <- data$X          # 300×2 matrix
labels <- data$labels # Ground truth labels

plot(X, col = labels + 1, pch = 19)
```

**Returns:** List with `X` (data matrix) and `labels` (true clusters)

**Use case:** Perfect for testing density-based algorithms

---

####  `make_circles(n_samples, noise, factor, random_state)`
**What it does:** Generates concentric circles (another synthetic dataset)

**When to use:** Another non-convex test case

```r
# Example: Generate circles
data <- make_circles(n_samples = 300, noise = 0.05, factor = 0.3)
X <- data$X
labels <- data$labels

plot(X, col = labels + 1, pch = 19)
```

**Returns:** List with `X` and `labels`

---

####  `plot_disco_scores(X, labels, scores, main, ...)`
**What it does:** Visualizes clustering with **color-coded DISCO scores**

**When to use:** Want to see where good/bad points are

```r
# Example: Visualize pointwise scores
scores <- disco_samples(X, labels)

plot_disco_scores(X, labels, scores, 
                  main = "DBSCAN with DISCO Scores")

# Color scheme:
#  Red    = bad scores (< -0.5)
#  Yellow = moderate scores (0 to 0.5)
#  Green  = good scores (> 0.5)
```

**Creates:** Scatter plot with points colored by score quality

---

####  `compare_clusterings(X, clustering_list, min_points)`
**What it does:** Compares multiple clustering algorithms at once

**When to use:** Want to rank different algorithms

```r
# Example: Compare 3 methods
clusterings <- list(
  DBSCAN = db_labels,
  KMeans = km_labels,
  Hierarchical = hc_labels
)

results <- compare_clusterings(X, clusterings, min_points = 5)
print(results)

# Output:
#    Clustering DISCO_Score
# 1      DBSCAN      0.6838
# 2 Hierarchical      0.2272
# 3      k-Means      0.2153
```

**Returns:** Data frame sorted by DISCO score (best first)

---

####  `summary_disco_scores(scores)`
**What it does:** Statistical summary of pointwise scores

**When to use:** Want detailed statistics

```r
# Example: Get statistics
scores <- disco_samples(X, labels)
summary_disco_scores(scores)

# Output:
# $mean:       0.684
# $median:     0.692
# $min:        0.467
# $max:        0.700
# $sd:         0.027
# $q25:        0.686
# $q75:        0.695
# $n_negative: 0
# $n_positive: 300
# $n_near_zero: 0
```

**Returns:** List with detailed statistics

---

#### `validate_disco_input(X, labels, min_points)`
**What it does:** Checks if inputs are valid

**Used by:** Internal validation in DISCO functions



---

###  Summary of utils.R:

| Function | You Use? | Purpose |
|----------|----------|---------|
| `make_moons()` |  YES | Generate test data (moons) |
| `make_circles()` |  YES | Generate test data (circles) |
| `plot_disco_scores()` |  YES | Visualize scores with colors |
| `compare_clusterings()` |  YES | Rank multiple algorithms |
| `summary_disco_scores()` |  YES | Get detailed statistics |
| `validate_disco_input()` |  NO | Internal validation |

---



### Typical Workflow:

```r
library(disco)
library(dbscan)

# ──────────────────────────────────────
# STEP 1: Get data
# ──────────────────────────────────────

# Option A: Use synthetic data
data <- make_moons(n_samples = 300, noise = 0.05)  # ← utils.R
X <- data$X
y_true <- data$labels

# Option B: Use your own data
# X <- your_data_matrix

# ──────────────────────────────────────
# STEP 2: Apply clustering
# ──────────────────────────────────────

db <- dbscan(X, eps = 0.2, minPts = 5)
labels <- db$cluster - 1  # Convert to 0-based with -1 for noise

# ──────────────────────────────────────
# STEP 3: Evaluate with DISCO
# ──────────────────────────────────────

# Get overall score
score <- disco_score(X, labels, min_points = 5)  # ← disco.R
print(score)  # 0.684

# Get per-point scores
scores <- disco_samples(X, labels, min_points = 5)  # ← disco.R
print(summary_disco_scores(scores))  # ← utils.R

# ──────────────────────────────────────
# STEP 4: Visualize
# ──────────────────────────────────────

plot_disco_scores(X, labels, scores,  # ← utils.R
                  main = "DBSCAN Results")

# ──────────────────────────────────────
# STEP 5: Compare methods (optional)
# ──────────────────────────────────────

km <- kmeans(X, centers = 2)
hc <- hclust(dist(X), method = "ward.D2")

results <- compare_clusterings(X, list(  # ← utils.R
  DBSCAN = labels,
  KMeans = km$cluster - 1,
  Hierarchical = cutree(hc, k = 2) - 1
), min_points = 5)

print(results)
```

---

## Function Usage Summary Table

| Title | Function to Use | Which File |
|---------------|-----------------|------------|
| **Score entire clustering** | `disco_score()` | disco.R |
| **Score each point** | `disco_samples()` | disco.R |
| **Generate test data (moons)** | `make_moons()` | utils.R |
| **Generate test data (circles)** | `make_circles()` | utils.R |
| **Visualize with colors** | `plot_disco_scores()` | utils.R |
| **Compare algorithms** | `compare_clusterings()` | utils.R |
| **Get statistics** | `summary_disco_scores()` | utils.R |
| **Compute dc-distances** | (automatic) | dctree.R |

---

## The Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    USER INTERFACE                           │
│  (Functions you actually call)                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  disco.R:                                                   │
│    • disco_score()      ← Main evaluation function         │
│    • disco_samples()    ← Per-point scores                 │
│                                                             │
│  utils.R:                                                   │
│    • make_moons()       ← Data generation                  │
│    • plot_disco_scores() ← Visualization                   │
│    • compare_clusterings() ← Algorithm comparison          │
│                                                             │
└────────────────────┬────────────────────────────────────────┘
                     │
        Automatically calls ↓
                     │
┌────────────────────┴────────────────────────────────────────┐
│                INTERNAL ENGINE                              │
│  (Runs automatically, you don't call)                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  disco.R:                                                   │
│    • p_cluster()  ← Cluster point evaluation               │
│    • p_noise()    ← Noise point evaluation                 │
│                                                             │
│  dctree.R:                                                  │
│    • compute_dc_distances()           ← Main dc-dist       │
│    • compute_core_distances()         ← k-NN              │
│    • compute_mutual_reachability_distance() ← Density     │
│    • compute_mst()                    ← MST via Prim      │
│    • extract_dc_distances_from_mst()  ← Minimax paths     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

##  Key Takeaway



1. `disco_score()` - Overall quality score
2. `disco_samples()` - Per-point scores
3. `make_moons()` - Generate test data
4. `plot_disco_scores()` - Visualize results
5. `compare_clusterings()` - Compare methods




## Summary



1. **User Interface** (disco.R + utils.R)
   - Simple functions: `disco_score()`, `make_moons()`, `plot_disco_scores()`
   - You call these directly

2. **Internal Engine** (dctree.R)
   - Complex math: dc-distances, MST, minimax paths
   - Runs automatically - you never call these




