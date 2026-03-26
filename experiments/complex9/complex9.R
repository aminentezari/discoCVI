# =============================================================================
# DISCO Analysis: Complex9 — DBSCAN vs K-Means
# Dataset: complex9.arff
# =============================================================================

required_pkgs <- c("dbscan", "FNN", "ggplot2", "gridExtra", "foreign")
for (p in required_pkgs) {
  if (!requireNamespace(p, quietly = TRUE))
    install.packages(p, repos = "https://cloud.r-project.org", quiet = TRUE)
}

setwd("~/Desktop/R-projects/Disco-R/R")

source("disco.R")

options(digits = 20)

# =============================================================================
# LOAD DATA
# =============================================================================

cat("Loading complex9.arff ...\n")

arff_path <- "~/Desktop/R-projects/Disco-R/experiments/complex9/complex9.arff"
# change this path if your file is elsewhere

raw_data <- foreign::read.arff(path.expand(arff_path))

# Make sure column names are correct
str(raw_data)

# Expected columns: x, y, class
X <- as.matrix(raw_data[, c("x", "y")])
y_true <- as.integer(as.character(raw_data$class))

cat(sprintf("  -> %d points loaded\n", nrow(X)))
cat(sprintf("  -> %d true classes detected: %s\n\n",
            length(unique(y_true)),
            paste(sort(unique(y_true)), collapse = ", ")))

# =============================================================================
# EXPORT DATA CSV
# =============================================================================

out_dir <- "~/Desktop/R-projects/Disco-R/experiments/complex9"
dir.create(path.expand(out_dir), showWarnings = FALSE, recursive = TRUE)

data_csv <- data.frame(
  x = X[, 1],
  y = X[, 2],
  true_label = y_true
)

write.csv(data_csv,
          file.path(path.expand(out_dir), "complex9_data_points.csv"),
          row.names = FALSE)

cat("  -> complex9_data_points.csv exported\n\n")

# =============================================================================
# CLUSTERING
# =============================================================================

# ----------------------------
# DBSCAN
# ----------------------------
# You may need to tune eps depending on your dataset density.
# Start with eps = 15 (or try 10, 12, 18, 20, etc.)
cat("Running DBSCAN (eps=15, minPts=5)...\n")
db_result     <- dbscan::dbscan(X, eps = 15, minPts = 5)
db_labels     <- as.integer(db_result$cluster)
db_labels[db_labels == 0L] <- -1L
n_db_clusters <- length(unique(db_labels[db_labels != -1L]))
n_db_noise    <- sum(db_labels == -1L)

cat(sprintf("  -> %d cluster(s), %d noise point(s)\n", n_db_clusters, n_db_noise))

write.csv(data.frame(db_label = db_labels),
          file.path(path.expand(out_dir), "r_dbscan_labels.csv"),
          row.names = FALSE)

# ----------------------------
# K-Means
# ----------------------------
cat("Running K-Means (k=9, nstart=20, seed=42)...\n")
cat("Loading Python K-Means labels...\n")
km_labels <- as.integer(read.csv(
  file.path(path.expand(out_dir), "python_km_labels.csv")
)$km_label)
cat("  -> cluster sizes:\n"); print(table(km_labels))

cat("  -> cluster sizes:\n")
print(table(km_labels))

write.csv(data.frame(km_label = km_labels),
          file.path(path.expand(out_dir), "r_kmeans_labels.csv"),
          row.names = FALSE)

write.csv(as.data.frame(km_result$centers),
          file.path(path.expand(out_dir), "r_kmeans_centroids.csv"),
          row.names = FALSE)

cat("  -> r_dbscan_labels.csv, r_kmeans_labels.csv, r_kmeans_centroids.csv exported\n\n")

# =============================================================================
# DISCO SCORES
# =============================================================================

cat("Computing DISCO scores...\n")

scores_db <- disco_samples(X, db_labels, min_points = 5)
disco_db  <- mean(scores_db)

scores_km <- disco_samples(X, km_labels, min_points = 5)
disco_km  <- mean(scores_km)

scores_csv <- data.frame(
  x          = X[, 1],
  y          = X[, 2],
  true_label = y_true,
  db_label   = db_labels,
  km_label   = km_labels,
  disco_db   = scores_db,
  disco_km   = scores_km
)

write.csv(scores_csv,
          file.path(path.expand(out_dir), "disco_scores_full.csv"),
          row.names = FALSE)

sep <- paste(rep("=", 62), collapse = "")
cat("\n", sep, "\n", sep = "")
cat("  DISCO RESULTS — 10 decimal places\n")
cat(sep, "\n", sep = "")
cat(sprintf("\n  DISCO score — DBSCAN  : %.20f\n", disco_db))
cat(sprintf("  DISCO score — K-Means : %.20f\n",  disco_km))
cat("\n", sep, "\n", sep = "")

# =============================================================================
# VISUALIZATION
# =============================================================================

library(ggplot2)
library(gridExtra)

dark_theme <- theme_void() +
  theme(
    plot.background   = element_rect(fill = "#1e1e2e", color = NA),
    panel.background  = element_rect(fill = "#2a2a3e", color = NA),
    panel.border      = element_rect(fill = NA, color = "#444466", linewidth = 0.6),
    plot.title        = element_text(color = "white", size = 11, face = "bold",
                                     hjust = 0.5, margin = margin(b = 4)),
    plot.subtitle     = element_text(color = "#aaaacc", size = 8, hjust = 0.5,
                                     margin = margin(b = 6)),
    legend.background = element_rect(fill = "#2a2a3e", color = "#444466"),
    legend.text       = element_text(color = "white",  size = 7.5),
    legend.title      = element_text(color = "#aaaacc", size = 8),
    legend.key        = element_rect(fill = "#2a2a3e", color = NA),
    axis.title        = element_blank(),
    axis.text         = element_blank(),
    plot.margin       = margin(8, 8, 8, 8)
  )

# More colors because complex9 has many clusters
CLUSTER_COLS <- c(
  "-1" = "#888888",
  "0"  = "#4C9BE8",
  "1"  = "#F4831F",
  "2"  = "#50C878",
  "3"  = "#FF6B6B",
  "4"  = "#C77DFF",
  "5"  = "#FFD166",
  "6"  = "#06D6A0",
  "7"  = "#EF476F",
  "8"  = "#118AB2",
  "9"  = "#8338EC"
)

DISCO_GRAD <- scale_color_gradientn(
  colours = c("#d73027", "#f46d43", "#fdae61", "#ffffbf", "#a6d96a", "#1a9850"),
  limits  = c(-1, 1),
  name    = "DISCO\nscore",
  breaks  = c(-1, -0.5, 0, 0.5, 1)
)

plot_df <- data.frame(
  x            = X[, 1],
  y            = X[, 2],
  true_label   = factor(y_true),
  dbscan_label = factor(db_labels),
  kmeans_label = factor(km_labels),
  disco_db     = scores_db,
  disco_km     = scores_km,
  is_noise     = db_labels == -1
)

# Ground truth
p1 <- ggplot(plot_df, aes(x, y, color = true_label)) +
  geom_point(size = 1.5, alpha = 0.85) +
  scale_color_manual(values = CLUSTER_COLS, name = "True label") +
  labs(title = "Ground Truth",
       subtitle = sprintf("Complex9  |  n=%d  |  true classes=%d",
                          nrow(plot_df), length(unique(y_true)))) +
  dark_theme +
  theme(legend.position = "bottom", legend.direction = "horizontal")

# DBSCAN clusters
p2 <- ggplot(plot_df, aes(x, y, color = dbscan_label, shape = is_noise)) +
  geom_point(size = 1.5, alpha = 0.85) +
  scale_color_manual(values = CLUSTER_COLS, name = "DBSCAN") +
  scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 4), guide = "none") +
  labs(title = "DBSCAN Clustering",
       subtitle = sprintf("eps=15  minPts=5  |  %d clusters  %d noise",
                          n_db_clusters, n_db_noise)) +
  dark_theme +
  theme(legend.position = "bottom", legend.direction = "horizontal")

# K-Means clusters
p3 <- ggplot(plot_df, aes(x, y, color = kmeans_label)) +
  geom_point(size = 1.5, alpha = 0.85) +
  scale_color_manual(values = CLUSTER_COLS, name = "K-Means") +
  labs(title = "K-Means Clustering",
       subtitle = "k=9  |  nstart=20  |  seed=42") +
  dark_theme +
  theme(legend.position = "bottom", legend.direction = "horizontal")

# DISCO per-point for DBSCAN
p4 <- ggplot(plot_df, aes(x, y, color = disco_db, shape = is_noise)) +
  geom_point(size = 1.8, alpha = 0.9) +
  DISCO_GRAD +
  scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 4), guide = "none") +
  labs(title = "DISCO Point-wise — DBSCAN",
       subtitle = sprintf("Overall DISCO = %.10f", disco_db)) +
  dark_theme +
  theme(legend.position = "right")

# DISCO per-point for K-Means
p5 <- ggplot(plot_df, aes(x, y, color = disco_km)) +
  geom_point(size = 1.8, alpha = 0.9) +
  DISCO_GRAD +
  labs(title = "DISCO Point-wise — K-Means",
       subtitle = sprintf("Overall DISCO = %.10f", disco_km)) +
  dark_theme +
  theme(legend.position = "right")

# Distribution of point-wise DISCO scores
score_df <- data.frame(
  score     = c(scores_db, scores_km),
  algorithm = factor(rep(c("DBSCAN", "K-Means"), each = nrow(plot_df)))
)

p6 <- ggplot(score_df, aes(x = algorithm, y = score, fill = algorithm)) +
  geom_violin(alpha = 0.5, color = NA, trim = FALSE) +
  geom_boxplot(width = 0.15, color = "white", alpha = 0.85,
               outlier.size = 0.7, outlier.color = "#888888") +
  geom_hline(yintercept = 0, color = "#ff6666", linetype = "dashed", linewidth = 0.6) +
  annotate("text", x = 1, y = 0.92,
           label = sprintf("mean\n%.10f", disco_db),
           color = "#4C9BE8", size = 2.5, fontface = "bold", hjust = 0.5) +
  annotate("text", x = 2, y = 0.92,
           label = sprintf("mean\n%.10f", disco_km),
           color = "#F4831F", size = 2.5, fontface = "bold", hjust = 0.5) +
  scale_fill_manual(values = c("DBSCAN" = "#4C9BE8", "K-Means" = "#F4831F"), guide = "none") +
  scale_y_continuous(limits = c(-1.1, 1.1), breaks = seq(-1, 1, 0.5)) +
  labs(title = "DISCO Score Distribution",
       subtitle = "Violin + boxplot  |  dashed = 0 threshold") +
  dark_theme +
  theme(
    axis.text.x        = element_text(color = "white", size = 10, face = "bold"),
    axis.text.y        = element_text(color = "#aaaaaa", size = 8),
    panel.grid.major.y = element_line(color = "#333355", linewidth = 0.35)
  )

title_grob <- grid::textGrob(
  "Complex9: DBSCAN vs K-Means — DISCO Evaluation",
  gp = grid::gpar(col = "white", fontsize = 13, fontface = "bold")
)

final_plot <- gridExtra::arrangeGrob(
  p1, p2, p3, p4, p5, p6,
  ncol = 3,
  top = title_grob
)

out_path <- file.path(path.expand(out_dir), "disco_visualization.png")
ggsave(out_path, plot = final_plot,
       width = 15, height = 10, dpi = 150, bg = "#1e1e2e")

cat(sprintf("Visualization saved -> %s\n", out_path))
cat("Done.\n")
cat("\n--- Files exported ---\n")
cat("  complex9_data_points.csv\n")
cat("  r_dbscan_labels.csv\n")
cat("  r_kmeans_labels.csv\n")
cat("  r_kmeans_centroids.csv\n")
cat("  disco_scores_full.csv\n")
