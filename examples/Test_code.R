# ============================================================================
# DISCO R Package - Test and Visualization Script
# Compare clustering algorithms and visualize results
# ============================================================================

# Load packages
library(disco)
library(dbscan)

# Set random seed for reproducibility
set.seed(42)

# ============================================================================
# 1. GENERATE TEST DATA
# ============================================================================

cat("Generating test datasets...\n")

# Two Moons dataset
moons_data <- make_moons(n_samples = 300, noise = 0.05, random_state = 42)
X_moons <- moons_data$X
y_true_moons <- moons_data$labels

# Circles dataset
circles_data <- make_circles(n_samples = 300, noise = 0.05, factor = 0.3, random_state = 42)
X_circles <- circles_data$X
y_true_circles <- circles_data$labels

cat("✓ Datasets generated\n\n")

# ============================================================================
# 2. APPLY CLUSTERING ALGORITHMS
# ============================================================================

cat("Applying clustering algorithms...\n")

# --- Two Moons ---
# DBSCAN
db_moons <- dbscan(X_moons, eps = 0.2, minPts = 5)
labels_db_moons <- db_moons$cluster - 1
labels_db_moons[labels_db_moons == -1] <- -1  # Keep noise as -1

# k-Means
km_moons <- kmeans(X_moons, centers = 2, nstart = 20)
labels_km_moons <- km_moons$cluster - 1

# Hierarchical Clustering
hc_moons <- hclust(dist(X_moons), method = "ward.D2")
labels_hc_moons <- cutree(hc_moons, k = 2) - 1

cat("✓ Clustering complete\n\n")

# ============================================================================
# 3. COMPUTE DISCO SCORES
# ============================================================================

cat("Computing DISCO scores...\n")

# Ground truth
disco_true_moons <- disco_score(X_moons, y_true_moons, min_points = 5)

# Clustering results
disco_db_moons <- disco_score(X_moons, labels_db_moons, min_points = 5)
disco_km_moons <- disco_score(X_moons, labels_km_moons, min_points = 5)
disco_hc_moons <- disco_score(X_moons, labels_hc_moons, min_points = 5)

# Get pointwise scores for DBSCAN
disco_samples_db <- disco_samples(X_moons, labels_db_moons, min_points = 5)

cat("✓ DISCO scores computed\n\n")

# ============================================================================
# 4. PRINT RESULTS
# ============================================================================

cat(strrep("=", 70), "\n")
cat("DISCO SCORE COMPARISON - Two Moons Dataset\n")
cat(strrep("=", 70), "\n\n")

results <- data.frame(
  Method = c("Ground Truth", "DBSCAN", "k-Means", "Hierarchical"),
  DISCO_Score = c(disco_true_moons, disco_db_moons, disco_km_moons, disco_hc_moons)
)
results <- results[order(-results$DISCO_Score), ]
rownames(results) <- NULL

print(results)

cat("\n")
cat("Interpretation:\n")
cat("  1.0 to 0.7  : Excellent clustering\n")
cat("  0.7 to 0.4  : Good clustering\n")
cat("  0.4 to 0.0  : Moderate clustering\n")
cat("  Below 0.0   : Poor clustering\n\n")

# ============================================================================
# 5. VISUALIZATION
# ============================================================================

cat("Creating visualizations...\n")

# Set up plotting area (2 rows, 4 columns)
par(mfrow = c(2, 4), mar = c(3, 3, 2, 1))

# --- Row 1: Clustering Results ---

# Ground Truth
plot(X_moons[, 1], X_moons[, 2], 
     col = y_true_moons + 2, pch = 19, cex = 0.8,
     main = sprintf("Ground Truth\nDISCO: %.3f", disco_true_moons),
     xlab = "", ylab = "")

# DBSCAN
plot(X_moons[, 1], X_moons[, 2], 
     col = ifelse(labels_db_moons == -1, 1, labels_db_moons + 2), 
     pch = ifelse(labels_db_moons == -1, 4, 19), cex = 0.8,
     main = sprintf("DBSCAN\nDISCO: %.3f", disco_db_moons),
     xlab = "", ylab = "")

# k-Means
plot(X_moons[, 1], X_moons[, 2], 
     col = labels_km_moons + 2, pch = 19, cex = 0.8,
     main = sprintf("k-Means\nDISCO: %.3f", disco_km_moons),
     xlab = "", ylab = "")

# Hierarchical
plot(X_moons[, 1], X_moons[, 2], 
     col = labels_hc_moons + 2, pch = 19, cex = 0.8,
     main = sprintf("Hierarchical\nDISCO: %.3f", disco_hc_moons),
     xlab = "", ylab = "")

# --- Row 2: DISCO Score Heatmaps ---

# Function to create heatmap
plot_disco_heatmap <- function(X, scores, title) {
  colors <- colorRampPalette(c("red", "yellow", "green"))(100)
  score_colors <- colors[cut(scores, breaks = 100, labels = FALSE)]
  score_colors[is.na(score_colors)] <- "gray"
  
  plot(X[, 1], X[, 2], 
       col = score_colors, pch = 19, cex = 0.8,
       main = title,
       xlab = "", ylab = "")
}

# Ground truth pointwise
disco_samples_true <- disco_samples(X_moons, y_true_moons, min_points = 5)
plot_disco_heatmap(X_moons, disco_samples_true, 
                   "Ground Truth\nPointwise Scores")

# DBSCAN pointwise
plot_disco_heatmap(X_moons, disco_samples_db, 
                   "DBSCAN\nPointwise Scores")

# k-Means pointwise
disco_samples_km <- disco_samples(X_moons, labels_km_moons, min_points = 5)
plot_disco_heatmap(X_moons, disco_samples_km, 
                   "k-Means\nPointwise Scores")

# Hierarchical pointwise
disco_samples_hc <- disco_samples(X_moons, labels_hc_moons, min_points = 5)
plot_disco_heatmap(X_moons, disco_samples_hc, 
                   "Hierarchical\nPointwise Scores")

cat("✓ Visualizations created\n\n")

# ============================================================================
# 6. DETAILED ANALYSIS FOR BEST METHOD (DBSCAN)
# ============================================================================

cat(strrep("=", 70), "\n")
cat("DETAILED ANALYSIS - DBSCAN (Best performing)\n")
cat(strrep("=", 70), "\n\n")

# Summary statistics
summary_stats <- summary_disco_scores(disco_samples_db)
cat("Summary Statistics:\n")
print(unlist(summary_stats))

cat("\n\nNoise Points Analysis:\n")
n_noise <- sum(labels_db_moons == -1)
cat(sprintf("  Total noise points: %d (%.1f%%)\n", 
            n_noise, 100 * n_noise / length(labels_db_moons)))

if (n_noise > 0) {
  noise_scores <- disco_samples_db[labels_db_moons == -1]
  cat(sprintf("  Mean noise score: %.3f\n", mean(noise_scores)))
  cat(sprintf("  Min noise score: %.3f\n", min(noise_scores)))
  cat(sprintf("  Max noise score: %.3f\n", max(noise_scores)))
}

# Cluster-wise scores
cat("\n\nCluster-wise Scores:\n")
for (cluster_id in unique(labels_db_moons[labels_db_moons != -1])) {
  cluster_scores <- disco_samples_db[labels_db_moons == cluster_id]
  cat(sprintf("  Cluster %d: mean=%.3f, size=%d\n", 
              cluster_id, mean(cluster_scores), length(cluster_scores)))
}

# ============================================================================
# 7. EXPORT RESULTS FOR PYTHON COMPARISON
# ============================================================================

cat("\n")
cat(strrep("=", 70), "\n")
cat("EXPORTING DATA FOR PYTHON COMPARISON\n")
cat(strrep("=", 70), "\n")

# Save data and labels for Python comparison
write.csv(X_moons, "test_data_moons.csv", row.names = FALSE)
write.csv(data.frame(labels = labels_db_moons), "test_labels_dbscan.csv", row.names = FALSE)
write.csv(data.frame(labels = y_true_moons), "test_labels_true.csv", row.names = FALSE)

# Save R results
results_r <- data.frame(
  dataset = "two_moons",
  method = c("ground_truth", "dbscan", "kmeans", "hierarchical"),
  disco_score = c(disco_true_moons, disco_db_moons, disco_km_moons, disco_hc_moons)
)
write.csv(results_r, "disco_results_R.csv", row.names = FALSE)

cat("\n✓ Files exported:\n")
cat("  - test_data_moons.csv\n")
cat("  - test_labels_dbscan.csv\n")
cat("  - test_labels_true.csv\n")
cat("  - disco_results_R.csv\n")

cat("\n")
cat(strrep("=", 70), "\n")
cat("TEST COMPLETE!\n")
cat(strrep("=", 70), "\n")