# ============================================================================
# DISCO Analysis for 3-spiral Dataset
# ============================================================================
# Classic density-based clustering benchmark: 3 intertwined spirals
# ============================================================================

rm(list = ls())
gc()

setwd("C:/Users/Amin PC/Desktop/Disco-R")

cat("============================================================\n")
cat("DISCO ANALYSIS: 3-SPIRAL DATASET\n")
cat("============================================================\n\n")

# ============================================================================
# CONFIGURATION
# ============================================================================

USE_FULL_DATASET <- TRUE    # Use all 312 points

# DBSCAN parameters for 3-spiral
# Spirals are continuous curves, so we need small eps to avoid merging
OPTIMAL_EPS <- 1.5          # Good starting point for 3-spiral
MIN_PTS <- 5                # Standard value

cat("Configuration:\n")
cat(sprintf("  Dataset:    3-spiral\n"))
cat(sprintf("  Mode:       %s\n", ifelse(USE_FULL_DATASET, "FULL", "SUBSET")))
cat(sprintf("  DBSCAN eps: %.2f\n", OPTIMAL_EPS))
cat(sprintf("  DBSCAN minPts: %d\n", MIN_PTS))
cat("============================================================\n\n")

# ============================================================================
# LOAD LIBRARIES
# ============================================================================

cat("Loading libraries...\n")
library(foreign)
library(dbscan)

cat("Loading DISCO functions...\n")
source("R/disco.R")
source("R/dctree.R")
source("R/utils.R")

# ============================================================================
# LOAD DATASET
# ============================================================================

cat("\nLoading 3-spiral dataset...\n")
spiral_data <- read.arff("C:/Users/Amin PC/Downloads/3-spiral.arff")

# Extract features and labels
X <- as.matrix(spiral_data[, c("x", "y")])
true_labels <- as.numeric(as.character(spiral_data$class)) - 1  # Convert to 0, 1, 2

cat(sprintf("Dataset loaded:\n"))
cat(sprintf("  Samples:   %d\n", nrow(X)))
cat(sprintf("  Features:  %d\n", ncol(X)))
cat(sprintf("  Classes:   %d (%s)\n", 
            length(unique(true_labels)),
            paste(sort(unique(true_labels)), collapse = ", ")))

# Show class distribution
for (label in sort(unique(true_labels))) {
  n <- sum(true_labels == label)
  cat(sprintf("    Class %d: %d samples (%.1f%%)\n", 
              label, n, 100 * n / length(true_labels)))
}

# ============================================================================
# CREATE OUTPUT DIRECTORY
# ============================================================================

output_dir <- "results-spiral"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# ============================================================================
# VISUALIZE TRUE LABELS
# ============================================================================

cat("\n============================================================\n")
cat("STEP 1: VISUALIZING TRUE LABELS\n")
cat("============================================================\n")

cat("Creating visualization...\n")
png(file.path(output_dir, "3spiral_true_labels.png"), 
    width = 800, height = 800, res = 120)
par(mar = c(4, 4, 3, 1))

plot(X[, 1], X[, 2],
     col = rainbow(3)[true_labels + 1],
     pch = 19, cex = 1.2,
     main = sprintf("3-Spiral: True Labels (n=%d)", nrow(X)),
     xlab = "x coordinate",
     ylab = "y coordinate",
     asp = 1)  # Equal aspect ratio for spirals

legend("topright",
       legend = paste("Spiral", 0:2),
       col = rainbow(3), 
       pch = 19, 
       cex = 1.0, 
       bg = "white")

dev.off()
cat("✓ Saved: 3spiral_true_labels.png\n")

# ============================================================================
# CALCULATE DISCO FOR TRUE LABELS
# ============================================================================

cat("\n============================================================\n")
cat("STEP 2: DISCO SCORE FOR TRUE LABELS\n")
cat("============================================================\n")

cat("Computing DISCO score for ground truth clustering...\n")
cat("(This may take 1-2 minutes for 312 samples)\n")

start_time <- Sys.time()
disco_true <- disco_score(X, true_labels, min_points = 5)
elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

cat(sprintf("\n✓ DISCO score (true labels): %.4f\n", disco_true))
cat(sprintf("  Computation time: %.1f seconds\n", elapsed))

# ============================================================================
# DBSCAN PARAMETER EXPLORATION
# ============================================================================

cat("\n============================================================\n")
cat("STEP 3: DBSCAN PARAMETER EXPLORATION\n")
cat("============================================================\n")

cat("Testing different eps values to find optimal clustering...\n\n")

# Test these eps values
eps_values <- c(1.0, 1.2, 1.5, 1.8, 2.0, 2.5, 3.0)

# Create comparison plot
png(file.path(output_dir, "3spiral_dbscan_exploration.png"),
    width = 1600, height = 1200, res = 100)
par(mfrow = c(3, 3), mar = c(3, 3, 2, 1))

# Plot true labels first
plot(X[, 1], X[, 2],
     col = rainbow(3)[true_labels + 1],
     pch = 19, cex = 0.8,
     main = "TRUE LABELS (3 spirals)",
     xlab = "x", ylab = "y",
     asp = 1)

cat(sprintf("%-8s %-10s %-12s %-10s %-15s\n", 
            "eps", "Clusters", "Noise Pts", "DISCO", "Verdict"))
cat(strrep("-", 65), "\n")

results_summary <- data.frame(
  eps = numeric(),
  n_clusters = integer(),
  n_noise = integer(),
  disco_score = numeric(),
  stringsAsFactors = FALSE
)

for (eps in eps_values) {
  # Run DBSCAN
  db_result <- dbscan(X, eps = eps, minPts = MIN_PTS)
  db_labels <- db_result$cluster - 1  # Convert: 0 -> -1 (noise)
  
  # Count clusters and noise
  n_clusters <- length(unique(db_labels[db_labels >= 0]))
  n_noise <- sum(db_labels == -1)
  
  # Calculate DISCO
  if (n_clusters > 0) {
    disco_db <- disco_score(X, db_labels, min_points = 5)
  } else {
    disco_db <- -1.0  # All noise
  }
  
  # Determine verdict
  if (n_clusters == 3 && n_noise < 20) {
    verdict <- "✓ EXCELLENT"
  } else if (n_clusters == 3) {
    verdict <- "✓ GOOD"
  } else if (n_clusters < 3) {
    verdict <- "✗ TOO LARGE"
  } else {
    verdict <- "✗ TOO SMALL"
  }
  
  cat(sprintf("%.2f     %-10d %-12d %-10.4f %-15s\n", 
              eps, n_clusters, n_noise, disco_db, verdict))
  
  # Store results
  results_summary <- rbind(results_summary, 
                           data.frame(eps = eps, 
                                      n_clusters = n_clusters, 
                                      n_noise = n_noise,
                                      disco_score = disco_db))
  
  # Plot this clustering
  noise_mask <- db_labels == -1
  cluster_mask <- db_labels >= 0
  
  if (sum(cluster_mask) > 0) {
    plot(X[cluster_mask, 1], X[cluster_mask, 2],
         col = rainbow(max(db_labels) + 1)[db_labels[cluster_mask] + 1],
         pch = 19, cex = 0.8,
         main = sprintf("eps=%.2f: %d clusters\nDISCO=%.3f", 
                        eps, n_clusters, disco_db),
         xlab = "x", ylab = "y",
         asp = 1)
    
    if (sum(noise_mask) > 0) {
      points(X[noise_mask, 1], X[noise_mask, 2],
             col = "gray", pch = 4, cex = 0.8)
    }
  } else {
    plot.new()
    title(sprintf("eps=%.2f: ALL NOISE", eps))
  }
}

dev.off()
cat("\n✓ Saved: 3spiral_dbscan_exploration.png\n")

# Find best eps
good_eps <- results_summary$eps[results_summary$n_clusters == 3]
if (length(good_eps) > 0) {
  # Among eps values that give 3 clusters, pick one with highest DISCO
  best_idx <- which(results_summary$eps %in% good_eps)[
    which.max(results_summary$disco_score[results_summary$eps %in% good_eps])
  ]
  OPTIMAL_EPS <- results_summary$eps[best_idx]
  cat(sprintf("\n✓ Recommended eps: %.2f\n", OPTIMAL_EPS))
}

# ============================================================================
# RUN DBSCAN WITH OPTIMAL PARAMETERS
# ============================================================================

cat("\n============================================================\n")
cat("STEP 4: DBSCAN WITH OPTIMAL PARAMETERS\n")
cat("============================================================\n")

cat(sprintf("Using: eps=%.2f, minPts=%d\n", OPTIMAL_EPS, MIN_PTS))

# Run DBSCAN
db_best <- dbscan(X, eps = OPTIMAL_EPS, minPts = MIN_PTS)
best_labels <- db_best$cluster - 1

n_clusters <- length(unique(best_labels[best_labels >= 0]))
n_noise <- sum(best_labels == -1)

cat(sprintf("Results:\n"))
cat(sprintf("  Clusters: %d\n", n_clusters))
cat(sprintf("  Noise:    %d points\n", n_noise))

# Calculate DISCO
cat("\nComputing DISCO score for DBSCAN clustering...\n")
start_time <- Sys.time()
disco_dbscan <- disco_score(X, best_labels, min_points = 5)
elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

cat(sprintf("✓ DISCO score (DBSCAN): %.4f\n", disco_dbscan))
cat(sprintf("  Computation time: %.1f seconds\n", elapsed))

# Compare with true labels
cat("\nComparison:\n")
cat(sprintf("  True labels: %.4f\n", disco_true))
cat(sprintf("  DBSCAN:      %.4f\n", disco_dbscan))
cat(sprintf("  Difference:  %.4f\n", abs(disco_true - disco_dbscan)))

# Visualize DBSCAN result
cat("\nCreating DBSCAN visualization...\n")
png(file.path(output_dir, "3spiral_dbscan_best.png"),
    width = 800, height = 800, res = 120)
par(mar = c(4, 4, 3, 1))

noise_mask <- best_labels == -1
cluster_mask <- best_labels >= 0

if (sum(cluster_mask) > 0) {
  plot(X[cluster_mask, 1], X[cluster_mask, 2],
       col = rainbow(max(best_labels) + 1)[best_labels[cluster_mask] + 1],
       pch = 19, cex = 1.2,
       main = sprintf("3-Spiral: DBSCAN\neps=%.2f, %d clusters, %d noise\nDISCO=%.4f", 
                      OPTIMAL_EPS, n_clusters, n_noise, disco_dbscan),
       xlab = "x coordinate",
       ylab = "y coordinate",
       asp = 1)
  
  if (sum(noise_mask) > 0) {
    points(X[noise_mask, 1], X[noise_mask, 2],
           col = "gray", pch = 4, cex = 1.5, lwd = 2)
  }
  
  if (n_clusters > 0) {
    legend("topright",
           legend = c(paste("Cluster", 0:(n_clusters-1)), 
                      if(n_noise > 0) "Noise" else NULL),
           col = c(rainbow(n_clusters), 
                   if(n_noise > 0) "gray" else NULL),
           pch = c(rep(19, n_clusters), 
                   if(n_noise > 0) 4 else NULL),
           cex = 1.0, bg = "white")
  }
}

dev.off()
cat("✓ Saved: 3spiral_dbscan_best.png\n")

# ============================================================================
# COMPARE WITH k-MEANS
# ============================================================================

cat("\n============================================================\n")
cat("STEP 5: COMPARISON WITH k-MEANS\n")
cat("============================================================\n")

cat("Running k-Means (k=3)...\n")
set.seed(42)
kmeans_result <- kmeans(X, centers = 3, nstart = 25)
kmeans_labels <- kmeans_result$cluster - 1

cat("Computing DISCO score for k-Means...\n")
start_time <- Sys.time()
disco_kmeans <- disco_score(X, kmeans_labels, min_points = 5)
elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

cat(sprintf("✓ DISCO score (k-Means): %.4f\n", disco_kmeans))
cat(sprintf("  Computation time: %.1f seconds\n", elapsed))

# Visualize k-Means
cat("\nCreating k-Means visualization...\n")
png(file.path(output_dir, "3spiral_kmeans.png"),
    width = 800, height = 800, res = 120)
par(mar = c(4, 4, 3, 1))

plot(X[, 1], X[, 2],
     col = rainbow(3)[kmeans_labels + 1],
     pch = 19, cex = 1.2,
     main = sprintf("3-Spiral: k-Means\nDISCO=%.4f", disco_kmeans),
     xlab = "x coordinate",
     ylab = "y coordinate",
     asp = 1)

# Add cluster centers
points(kmeans_result$centers[, 1], 
       kmeans_result$centers[, 2],
       col = rainbow(3),
       pch = 4, cex = 3, lwd = 3)

legend("topright",
       legend = c(paste("Cluster", 0:2), "Centroids"),
       col = c(rainbow(3), "black"),
       pch = c(rep(19, 3), 4),
       cex = 1.0, bg = "white")

dev.off()
cat("✓ Saved: 3spiral_kmeans.png\n")

# ============================================================================
# CREATE COMPREHENSIVE COMPARISON
# ============================================================================

cat("\n============================================================\n")
cat("STEP 6: COMPREHENSIVE COMPARISON\n")
cat("============================================================\n")

cat("Creating comparison plot...\n")
png(file.path(output_dir, "3spiral_comparison.png"),
    width = 2000, height = 650, res = 100)
par(mfrow = c(1, 3), mar = c(4, 4, 3, 1))

# True labels
plot(X[, 1], X[, 2],
     col = rainbow(3)[true_labels + 1],
     pch = 19, cex = 1.0,
     main = sprintf("True Labels\nDISCO=%.4f", disco_true),
     xlab = "x", ylab = "y",
     asp = 1)

# DBSCAN
if (sum(cluster_mask) > 0) {
  plot(X[cluster_mask, 1], X[cluster_mask, 2],
       col = rainbow(max(best_labels) + 1)[best_labels[cluster_mask] + 1],
       pch = 19, cex = 1.0,
       main = sprintf("DBSCAN (eps=%.2f)\nDISCO=%.4f, %d clusters", 
                      OPTIMAL_EPS, disco_dbscan, n_clusters),
       xlab = "x", ylab = "y",
       asp = 1)
  
  if (sum(noise_mask) > 0) {
    points(X[noise_mask, 1], X[noise_mask, 2],
           col = "gray", pch = 4, cex = 1.2)
  }
}

# k-Means
plot(X[, 1], X[, 2],
     col = rainbow(3)[kmeans_labels + 1],
     pch = 19, cex = 1.0,
     main = sprintf("k-Means\nDISCO=%.4f", disco_kmeans),
     xlab = "x", ylab = "y",
     asp = 1)

dev.off()
cat("✓ Saved: 3spiral_comparison.png\n")

# Create DISCO comparison bar chart
png(file.path(output_dir, "3spiral_disco_comparison.png"),
    width = 800, height = 600, res = 100)
par(mar = c(5, 6, 4, 2))

disco_scores <- c(disco_true, disco_dbscan, disco_kmeans)
method_names <- c("True\nLabels", "DBSCAN", "k-Means")
bar_colors <- c("darkgreen", "steelblue", "coral")

bp <- barplot(disco_scores,
              names.arg = method_names,
              col = bar_colors,
              main = "DISCO Score Comparison\n3-Spiral Dataset",
              ylab = "DISCO Score",
              ylim = c(0, max(disco_scores) * 1.2),
              las = 1,
              cex.names = 1.2,
              cex.lab = 1.2)

# Add value labels on bars
text(bp, disco_scores + 0.02,
     labels = sprintf("%.4f", disco_scores),
     pos = 3, cex = 1.1, font = 2)

# Add grid
grid(NA, NULL, lty = 2, col = "gray80")

dev.off()
cat("✓ Saved: 3spiral_disco_comparison.png\n")

# ============================================================================
# FINAL SUMMARY
# ============================================================================

cat("\n============================================================\n")
cat("FINAL SUMMARY: 3-SPIRAL DATASET\n")
cat("============================================================\n")

cat(sprintf("Dataset: %d samples, 3 spiral-shaped clusters\n", nrow(X)))
cat(sprintf("DBSCAN parameters: eps=%.2f, minPts=%d\n\n", OPTIMAL_EPS, MIN_PTS))

cat("DISCO Scores:\n")
cat(sprintf("  True labels:    %.4f  (ground truth)\n", disco_true))
cat(sprintf("  DBSCAN:         %.4f  (%d clusters, %d noise)\n", 
            disco_dbscan, n_clusters, n_noise))
cat(sprintf("  k-Means:        %.4f  (3 clusters, 0 noise)\n", disco_kmeans))

cat("\nInterpretation:\n")
if (n_clusters == 3 && abs(disco_dbscan - disco_true) < 0.05) {
  cat("  ✓✓ EXCELLENT: DBSCAN perfectly recovered the spiral structure!\n")
  cat("     DISCO scores are nearly identical.\n")
} else if (n_clusters == 3) {
  cat("  ✓ GOOD: DBSCAN found 3 clusters\n")
  cat("    Some boundary differences vs ground truth.\n")
} else {
  cat("  ⚠ ISSUE: DBSCAN did not find 3 clusters\n")
  cat("    Try different eps values (see exploration plot)\n")
}

cat("\nWhy k-Means fails:\n")
cat("  k-Means assumes spherical clusters with centroids.\n")
cat("  Spirals are highly non-convex - k-Means cuts across spirals.\n")
cat(sprintf("  DISCO is lower (%.4f) showing poor cluster quality.\n", disco_kmeans))

cat("\nOutput files in 'results/' directory:\n")
cat("  - 3spiral_true_labels.png (ground truth)\n")
cat("  - 3spiral_dbscan_exploration.png (parameter search)\n")
cat("  - 3spiral_dbscan_best.png (best DBSCAN result)\n")
cat("  - 3spiral_kmeans.png (k-Means result)\n")
cat("  - 3spiral_comparison.png (side-by-side comparison)\n")
cat("  - 3spiral_disco_comparison.png (DISCO scores bar chart)\n")

cat("\n============================================================\n")
cat("ANALYSIS COMPLETE!\n")
cat("============================================================\n")

# Save workspace
save(X, true_labels, best_labels, kmeans_labels,
     disco_true, disco_dbscan, disco_kmeans,
     OPTIMAL_EPS, MIN_PTS,
     file = file.path(output_dir, "3spiral_results.RData"))

cat("\n✓ Results saved to: 3spiral_results.RData\n")
cat("\nTo reload results later:\n")
cat("  load('results/3spiral_results.RData')\n")