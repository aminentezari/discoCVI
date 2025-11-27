# ============================================================================
# DISCO R Package - Comprehensive Test and Visualization Script
# Author: Amin Entezari
# Purpose: Compare clustering algorithms and demonstrate DISCO evaluation
# ============================================================================

# Load required packages
suppressPackageStartupMessages({
  devtools::load_all()
  library(dbscan)
})

# Set random seed for reproducibility
set.seed(42)

cat("\n")
cat("╔════════════════════════════════════════════════════════════════════╗\n")
cat("║     DISCO R Package - Comprehensive Clustering Evaluation         ║\n")
cat("╚════════════════════════════════════════════════════════════════════╝\n")
cat("\n")

# ============================================================================
# 1. GENERATE TEST DATASETS
# ============================================================================

cat("STEP 1: Generating Test Datasets\n")
cat(strrep("─", 70), "\n")

# Two Moons dataset
moons_data <- make_moons(n_samples = 300, noise = 0.05, random_state = 42)
X_moons <- moons_data$X
y_true_moons <- moons_data$labels

# Circles dataset
circles_data <- make_circles(n_samples = 300, noise = 0.05, factor = 0.3, random_state = 42)
X_circles <- circles_data$X
y_true_circles <- circles_data$labels

cat(sprintf("✓ Two Moons:  %d samples, %d features\n", 
            nrow(X_moons), ncol(X_moons)))
cat(sprintf("✓ Circles:    %d samples, %d features\n", 
            nrow(X_circles), ncol(X_circles)))
cat("\n")

# ============================================================================
# 2. APPLY CLUSTERING ALGORITHMS
# ============================================================================

cat("STEP 2: Applying Clustering Algorithms\n")
cat(strrep("─", 70), "\n")

# ──────────────────────────────────────────────────────────────────────────
# DBSCAN with OPTIMAL parameters (should match ground truth)
# ──────────────────────────────────────────────────────────────────────────
db_optimal <- dbscan(X_moons, eps = 0.2, minPts = 5)
labels_db_optimal <- db_optimal$cluster - 1
cat(sprintf("✓ DBSCAN (eps=0.2, minPts=5):  %d clusters, %d noise\n", 
            length(unique(labels_db_optimal[labels_db_optimal != -1])),
            sum(labels_db_optimal == -1)))

# ──────────────────────────────────────────────────────────────────────────
# DBSCAN with SUBOPTIMAL parameters (to show difference)
# ──────────────────────────────────────────────────────────────────────────
db_suboptimal <- dbscan(X_moons, eps = 0.35, minPts = 5)
labels_db_suboptimal <- db_suboptimal$cluster - 1
cat(sprintf("✓ DBSCAN (eps=0.35, minPts=5): %d clusters, %d noise\n", 
            length(unique(labels_db_suboptimal[labels_db_suboptimal != -1])),
            sum(labels_db_suboptimal == -1)))

# ──────────────────────────────────────────────────────────────────────────
# k-Means (centroid-based, should perform poorly on non-convex data)
# ──────────────────────────────────────────────────────────────────────────
km_moons <- kmeans(X_moons, centers = 2, nstart = 20)
labels_km_moons <- km_moons$cluster - 1
cat(sprintf("✓ k-Means (k=2):               %d clusters, %d noise\n", 
            length(unique(labels_km_moons)),
            sum(labels_km_moons == -1)))

# ──────────────────────────────────────────────────────────────────────────
# Hierarchical Clustering (distance-based, should also perform poorly)
# ──────────────────────────────────────────────────────────────────────────
hc_moons <- hclust(dist(X_moons), method = "ward.D2")
labels_hc_moons <- cutree(hc_moons, k = 2) - 1
cat(sprintf("✓ Hierarchical (Ward, k=2):    %d clusters, %d noise\n", 
            length(unique(labels_hc_moons)),
            sum(labels_hc_moons == -1)))

cat("\n")

# ============================================================================
# 3. COMPUTE DISCO SCORES
# ============================================================================

cat("STEP 3: Computing DISCO Scores\n")
cat(strrep("─", 70), "\n")

# Ground truth
disco_true_moons <- disco_score(X_moons, y_true_moons, min_points = 5)
cat(sprintf("✓ Ground Truth computed: %.4f\n", disco_true_moons))

# DBSCAN optimal
disco_db_optimal <- disco_score(X_moons, labels_db_optimal, min_points = 5)
cat(sprintf("✓ DBSCAN (optimal) computed: %.4f\n", disco_db_optimal))

# DBSCAN suboptimal
disco_db_suboptimal <- disco_score(X_moons, labels_db_suboptimal, min_points = 5)
cat(sprintf("✓ DBSCAN (suboptimal) computed: %.4f\n", disco_db_suboptimal))

# k-Means
disco_km_moons <- disco_score(X_moons, labels_km_moons, min_points = 5)
cat(sprintf("✓ k-Means computed: %.4f\n", disco_km_moons))

# Hierarchical
disco_hc_moons <- disco_score(X_moons, labels_hc_moons, min_points = 5)
cat(sprintf("✓ Hierarchical computed: %.4f\n", disco_hc_moons))

# Get pointwise scores for all methods
disco_samples_true <- disco_samples(X_moons, y_true_moons, min_points = 5)
disco_samples_db_opt <- disco_samples(X_moons, labels_db_optimal, min_points = 5)
disco_samples_db_sub <- disco_samples(X_moons, labels_db_suboptimal, min_points = 5)
disco_samples_km <- disco_samples(X_moons, labels_km_moons, min_points = 5)
disco_samples_hc <- disco_samples(X_moons, labels_hc_moons, min_points = 5)

cat("\n")

# ============================================================================
# 4. DISPLAY RESULTS SUMMARY
# ============================================================================

cat(strrep("═", 70), "\n")
cat("DISCO SCORE COMPARISON - Two Moons Dataset\n")
cat(strrep("═", 70), "\n\n")

results <- data.frame(
  Method = c("Ground Truth", 
             "DBSCAN (eps=0.2, optimal)", 
             "DBSCAN (eps=0.35, suboptimal)",
             "k-Means (k=2)", 
             "Hierarchical (Ward)"),
  DISCO_Score = c(disco_true_moons, 
                  disco_db_optimal, 
                  disco_db_suboptimal,
                  disco_km_moons, 
                  disco_hc_moons),
  n_Clusters = c(2, 
                 length(unique(labels_db_optimal[labels_db_optimal != -1])),
                 length(unique(labels_db_suboptimal[labels_db_suboptimal != -1])),
                 2, 
                 2),
  n_Noise = c(0, 
              sum(labels_db_optimal == -1),
              sum(labels_db_suboptimal == -1),
              0, 
              0)
)

# Sort by DISCO score
results <- results[order(-results$DISCO_Score), ]
rownames(results) <- NULL

print(results)

cat("\n")
cat("Score Interpretation:\n")
cat("  ┌─────────────────────────────────────────┐\n")
cat("  │  1.0 to 0.7  : Excellent clustering    │\n")
cat("  │  0.7 to 0.4  : Good clustering         │\n")
cat("  │  0.4 to 0.0  : Moderate clustering     │\n")
cat("  │  Below 0.0   : Poor clustering         │\n")
cat("  └─────────────────────────────────────────┘\n")
cat("\n")

# ============================================================================
# 5. CREATE COMPREHENSIVE VISUALIZATIONS
# ============================================================================

cat("STEP 4: Creating Visualizations\n")
cat(strrep("─", 70), "\n")

# Save plot to file
png("disco_comparison_comprehensive.png", 
    width = 2800, height = 1800, res = 150)

# Set up plotting area (3 rows, 5 columns)
par(mfrow = c(3, 5), mar = c(3, 3, 3, 1), oma = c(0, 0, 3, 0))

# Helper function for heatmap
plot_disco_heatmap <- function(X, scores, title) {
  colors <- colorRampPalette(c("red", "yellow", "green"))(100)
  score_colors <- colors[cut(scores, breaks = 100, labels = FALSE)]
  score_colors[is.na(score_colors)] <- "gray"
  
  plot(X[, 1], X[, 2], 
       col = score_colors, pch = 19, cex = 0.8,
       main = title,
       xlab = "", ylab = "",
       xlim = range(X[, 1]), ylim = range(X[, 2]))
}

# ──────────────────────────────────────────────────────────────────────────
# ROW 1: Clustering Results
# ──────────────────────────────────────────────────────────────────────────

# Ground Truth
plot(X_moons[, 1], X_moons[, 2], 
     col = y_true_moons + 2, pch = 19, cex = 1,
     main = sprintf("Ground Truth\nDISCO: %.3f | Clusters: %d | Noise: %d", 
                    disco_true_moons, 2, 0),
     xlab = "", ylab = "")
legend("topright", legend = c("Cluster 0", "Cluster 1"), 
       col = c(2, 3), pch = 19, cex = 0.7)

# DBSCAN Optimal
n_clusters_opt <- length(unique(labels_db_optimal[labels_db_optimal != -1]))
n_noise_opt <- sum(labels_db_optimal == -1)
plot(X_moons[, 1], X_moons[, 2], 
     col = ifelse(labels_db_optimal == -1, 1, labels_db_optimal + 2), 
     pch = ifelse(labels_db_optimal == -1, 4, 19), cex = 1,
     main = sprintf("DBSCAN (eps=0.2)\nDISCO: %.3f | Clusters: %d | Noise: %d", 
                    disco_db_optimal, n_clusters_opt, n_noise_opt),
     xlab = "", ylab = "")
if (n_noise_opt > 0) {
  legend("topright", legend = c("Cluster 0", "Cluster 1", "Noise"), 
         col = c(2, 3, 1), pch = c(19, 19, 4), cex = 0.7)
} else {
  legend("topright", legend = c("Cluster 0", "Cluster 1"), 
         col = c(2, 3), pch = 19, cex = 0.7)
}

# DBSCAN Suboptimal
n_clusters_sub <- length(unique(labels_db_suboptimal[labels_db_suboptimal != -1]))
n_noise_sub <- sum(labels_db_suboptimal == -1)
plot(X_moons[, 1], X_moons[, 2], 
     col = ifelse(labels_db_suboptimal == -1, 1, labels_db_suboptimal + 2), 
     pch = ifelse(labels_db_suboptimal == -1, 4, 19), cex = 1,
     main = sprintf("DBSCAN (eps=0.35)\nDISCO: %.3f | Clusters: %d | Noise: %d", 
                    disco_db_suboptimal, n_clusters_sub, n_noise_sub),
     xlab = "", ylab = "")
if (n_clusters_sub > 1) {
  legend("topright", legend = c("Cluster 0", "Cluster 1", "Noise"), 
         col = c(2, 3, 1), pch = c(19, 19, 4), cex = 0.7)
} else {
  legend("topright", legend = c("Cluster 0", "Noise"), 
         col = c(2, 1), pch = c(19, 4), cex = 0.7)
}

# k-Means
plot(X_moons[, 1], X_moons[, 2], 
     col = labels_km_moons + 2, pch = 19, cex = 1,
     main = sprintf("k-Means (k=2)\nDISCO: %.3f | Clusters: %d | Noise: %d", 
                    disco_km_moons, 2, 0),
     xlab = "", ylab = "")
legend("topright", legend = c("Cluster 0", "Cluster 1"), 
       col = c(2, 3), pch = 19, cex = 0.7)

# Hierarchical
plot(X_moons[, 1], X_moons[, 2], 
     col = labels_hc_moons + 2, pch = 19, cex = 1,
     main = sprintf("Hierarchical (Ward)\nDISCO: %.3f | Clusters: %d | Noise: %d", 
                    disco_hc_moons, 2, 0),
     xlab = "", ylab = "")
legend("topright", legend = c("Cluster 0", "Cluster 1"), 
       col = c(2, 3), pch = 19, cex = 0.7)

# ──────────────────────────────────────────────────────────────────────────
# ROW 2: DISCO Score Heatmaps (Pointwise Scores)
# ──────────────────────────────────────────────────────────────────────────

plot_disco_heatmap(X_moons, disco_samples_true, 
                   sprintf("Ground Truth\nPointwise Scores\nMean: %.3f", 
                           mean(disco_samples_true)))

plot_disco_heatmap(X_moons, disco_samples_db_opt, 
                   sprintf("DBSCAN (eps=0.2)\nPointwise Scores\nMean: %.3f", 
                           mean(disco_samples_db_opt)))

plot_disco_heatmap(X_moons, disco_samples_db_sub, 
                   sprintf("DBSCAN (eps=0.35)\nPointwise Scores\nMean: %.3f", 
                           mean(disco_samples_db_sub)))

plot_disco_heatmap(X_moons, disco_samples_km, 
                   sprintf("k-Means\nPointwise Scores\nMean: %.3f", 
                           mean(disco_samples_km)))

plot_disco_heatmap(X_moons, disco_samples_hc, 
                   sprintf("Hierarchical\nPointwise Scores\nMean: %.3f", 
                           mean(disco_samples_hc)))

# ──────────────────────────────────────────────────────────────────────────
# ROW 3: Score Distributions (Histograms)
# ──────────────────────────────────────────────────────────────────────────

hist(disco_samples_true, breaks = 30, col = "skyblue", border = "white",
     main = "Ground Truth\nScore Distribution", 
     xlab = "DISCO Score", xlim = c(-1, 1))
abline(v = mean(disco_samples_true), col = "red", lwd = 2, lty = 2)

hist(disco_samples_db_opt, breaks = 30, col = "lightgreen", border = "white",
     main = "DBSCAN (eps=0.2)\nScore Distribution", 
     xlab = "DISCO Score", xlim = c(-1, 1))
abline(v = mean(disco_samples_db_opt), col = "red", lwd = 2, lty = 2)

hist(disco_samples_db_sub, breaks = 30, col = "lightyellow", border = "white",
     main = "DBSCAN (eps=0.35)\nScore Distribution", 
     xlab = "DISCO Score", xlim = c(-1, 1))
abline(v = mean(disco_samples_db_sub), col = "red", lwd = 2, lty = 2)

hist(disco_samples_km, breaks = 30, col = "lightcoral", border = "white",
     main = "k-Means\nScore Distribution", 
     xlab = "DISCO Score", xlim = c(-1, 1))
abline(v = mean(disco_samples_km), col = "red", lwd = 2, lty = 2)

hist(disco_samples_hc, breaks = 30, col = "plum", border = "white",
     main = "Hierarchical\nScore Distribution", 
     xlab = "DISCO Score", xlim = c(-1, 1))
abline(v = mean(disco_samples_hc), col = "red", lwd = 2, lty = 2)

# Add overall title
mtext("DISCO Evaluation: Comprehensive Comparison of Clustering Algorithms", 
      outer = TRUE, cex = 1.5, font = 2)

dev.off()

cat("✓ Comprehensive plot saved: disco_comparison_comprehensive.png\n")
cat("\n")

# ============================================================================
# 6. DETAILED ANALYSIS
# ============================================================================

cat(strrep("═", 70), "\n")
cat("DETAILED ANALYSIS - Method Comparison\n")
cat(strrep("═", 70), "\n\n")

# ──────────────────────────────────────────────────────────────────────────
# Analysis for DBSCAN Optimal
# ──────────────────────────────────────────────────────────────────────────
cat("DBSCAN (eps=0.2, optimal):\n")
cat(strrep("─", 40), "\n")
summary_opt <- summary_disco_scores(disco_samples_db_opt)
cat(sprintf("  Mean Score:   %.4f\n", summary_opt$mean))
cat(sprintf("  Median Score: %.4f\n", summary_opt$median))
cat(sprintf("  Std Dev:      %.4f\n", summary_opt$sd))
cat(sprintf("  Range:        [%.4f, %.4f]\n", summary_opt$min, summary_opt$max))
cat(sprintf("  Clusters:     %d\n", n_clusters_opt))
cat(sprintf("  Noise points: %d (%.1f%%)\n\n", 
            n_noise_opt, 100 * n_noise_opt / length(labels_db_optimal)))

# ──────────────────────────────────────────────────────────────────────────
# Analysis for DBSCAN Suboptimal
# ──────────────────────────────────────────────────────────────────────────
cat("DBSCAN (eps=0.35, suboptimal):\n")
cat(strrep("─", 40), "\n")
summary_sub <- summary_disco_scores(disco_samples_db_sub)
cat(sprintf("  Mean Score:   %.4f\n", summary_sub$mean))
cat(sprintf("  Median Score: %.4f\n", summary_sub$median))
cat(sprintf("  Std Dev:      %.4f\n", summary_sub$sd))
cat(sprintf("  Range:        [%.4f, %.4f]\n", summary_sub$min, summary_sub$max))
cat(sprintf("  Clusters:     %d\n", n_clusters_sub))
cat(sprintf("  Noise points: %d (%.1f%%)\n\n", 
            n_noise_sub, 100 * n_noise_sub / length(labels_db_suboptimal)))

# ──────────────────────────────────────────────────────────────────────────
# Analysis for k-Means
# ──────────────────────────────────────────────────────────────────────────
cat("k-Means (k=2):\n")
cat(strrep("─", 40), "\n")
summary_km <- summary_disco_scores(disco_samples_km)
cat(sprintf("  Mean Score:   %.4f\n", summary_km$mean))
cat(sprintf("  Median Score: %.4f\n", summary_km$median))
cat(sprintf("  Std Dev:      %.4f\n", summary_km$sd))
cat(sprintf("  Range:        [%.4f, %.4f]\n\n", summary_km$min, summary_km$max))

# ──────────────────────────────────────────────────────────────────────────
# Confusion Matrix: Ground Truth vs DBSCAN Optimal
# ──────────────────────────────────────────────────────────────────────────
cat("Label Agreement Analysis:\n")
cat(strrep("─", 40), "\n")

# Check agreement between ground truth and DBSCAN optimal
# Account for possible label swapping (0<->1)
agreement1 <- sum(y_true_moons == labels_db_optimal) / length(y_true_moons)
agreement2 <- sum(y_true_moons == (1 - labels_db_optimal)) / length(y_true_moons)
max_agreement <- max(agreement1, agreement2)

cat("\nGround Truth vs DBSCAN (eps=0.2):\n")
cat(sprintf("  Label Agreement: %.1f%%\n", max_agreement * 100))

if (max_agreement > 0.99) {
  cat("  ✓ Nearly perfect match!\n")
  cat("  → This explains why DISCO scores are identical\n")
} else {
  cat("  ✗ Significant differences exist\n")
  cat(sprintf("  → DISCO scores differ by %.4f\n", 
              abs(disco_true_moons - disco_db_optimal)))
}

cat("\nGround Truth vs DBSCAN (eps=0.35):\n")
agreement_sub1 <- sum(y_true_moons == labels_db_suboptimal) / length(y_true_moons)
agreement_sub2 <- sum(y_true_moons == (1 - labels_db_suboptimal)) / length(y_true_moons)
max_agreement_sub <- max(agreement_sub1, agreement_sub2)
cat(sprintf("  Label Agreement: %.1f%%\n", max_agreement_sub * 100))
cat(sprintf("  → DISCO scores differ by %.4f\n", 
            abs(disco_true_moons - disco_db_suboptimal)))

cat("\n")

# ============================================================================
# 7. EXPORT RESULTS
# ============================================================================

cat(strrep("═", 70), "\n")
cat("EXPORTING RESULTS FOR FURTHER ANALYSIS\n")
cat(strrep("═", 70), "\n")

# Save all results to CSV
results_export <- data.frame(
  dataset = rep("two_moons", 5),
  method = c("ground_truth", "dbscan_optimal", "dbscan_suboptimal", 
             "kmeans", "hierarchical"),
  disco_score = c(disco_true_moons, disco_db_optimal, disco_db_suboptimal,
                  disco_km_moons, disco_hc_moons),
  n_clusters = results$n_Clusters,
  n_noise = results$n_Noise,
  mean_pointwise = c(mean(disco_samples_true), 
                     mean(disco_samples_db_opt),
                     mean(disco_samples_db_sub),
                     mean(disco_samples_km),
                     mean(disco_samples_hc)),
  sd_pointwise = c(sd(disco_samples_true), 
                   sd(disco_samples_db_opt),
                   sd(disco_samples_db_sub),
                   sd(disco_samples_km),
                   sd(disco_samples_hc))
)

write.csv(results_export, "disco_results_comprehensive.csv", row.names = FALSE)
write.csv(X_moons, "data_two_moons.csv", row.names = FALSE)
write.csv(data.frame(labels = y_true_moons), "labels_ground_truth.csv", row.names = FALSE)
write.csv(data.frame(labels = labels_db_optimal), "labels_dbscan_optimal.csv", row.names = FALSE)
write.csv(data.frame(labels = labels_db_suboptimal), "labels_dbscan_suboptimal.csv", row.names = FALSE)

cat("\n✓ Files exported:\n")
cat("  - disco_results_comprehensive.csv\n")
cat("  - data_two_moons.csv\n")
cat("  - labels_ground_truth.csv\n")
cat("  - labels_dbscan_optimal.csv\n")
cat("  - labels_dbscan_suboptimal.csv\n")
cat("\n")

# ============================================================================
# 8. FINAL SUMMARY
# ============================================================================

cat(strrep("═", 70), "\n")
cat("SUMMARY AND CONCLUSIONS\n")
cat(strrep("═", 70), "\n\n")

cat("Key Findings:\n")
cat(strrep("─", 70), "\n")
cat(sprintf("1. Ground Truth score:           %.4f (baseline)\n", disco_true_moons))
cat(sprintf("2. DBSCAN (optimal) score:       %.4f (%+.4f vs GT)\n", 
            disco_db_optimal, disco_db_optimal - disco_true_moons))
cat(sprintf("3. DBSCAN (suboptimal) score:    %.4f (%+.4f vs GT)\n", 
            disco_db_suboptimal, disco_db_suboptimal - disco_true_moons))
cat(sprintf("4. k-Means score:                %.4f (%+.4f vs GT)\n", 
            disco_km_moons, disco_km_moons - disco_true_moons))
cat(sprintf("5. Hierarchical score:           %.4f (%+.4f vs GT)\n", 
            disco_hc_moons, disco_hc_moons - disco_true_moons))

cat("\nInterpretation:\n")
cat(strrep("─", 70), "\n")

# Determine best method
best_method <- results$Method[1]
best_score <- results$DISCO_Score[1]

cat(sprintf("✓ Best Method: %s (DISCO: %.4f)\n", best_method, best_score))

if (disco_db_optimal == disco_true_moons) {
  cat("\n✓ DBSCAN (optimal) perfectly recovered the ground truth structure!\n")
  cat("  This is why their DISCO scores are identical.\n")
} else {
  cat(sprintf("\n✗ DBSCAN (optimal) differs from ground truth by %.4f\n", 
              abs(disco_db_optimal - disco_true_moons)))
}

cat("\n✗ k-Means and Hierarchical perform poorly on non-convex clusters\n")
cat("  DISCO correctly identifies their limitations for this dataset.\n")

if (disco_db_suboptimal < disco_db_optimal) {
  cat("\n✗ Suboptimal DBSCAN parameters reduce clustering quality\n")
  cat(sprintf("  Quality decreases by %.4f when eps is too large\n", 
              disco_db_optimal - disco_db_suboptimal))
}

cat("\n")
cat(strrep("═", 70), "\n")
cat("✓ ANALYSIS COMPLETE!\n")
cat(strrep("═", 70), "\n")
cat("\n")
cat("Next Steps:\n")
cat("  1. Review the comprehensive plot: disco_comparison_comprehensive.png\n")
cat("  2. Examine exported CSV files for detailed statistics\n")
cat("  3. Compare with Python DISCO implementation (if available)\n")
cat("\n")