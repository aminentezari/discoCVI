# =============================================================================
# DISCO Analysis: Concentric Circles — DBSCAN vs K-Means
# =============================================================================

required_pkgs <- c("dbscan", "FNN", "ggplot2", "gridExtra", "grid")
for (p in required_pkgs) {
  if (!requireNamespace(p, quietly = TRUE))
    install.packages(p, repos = "https://cloud.r-project.org", quiet = TRUE)
}

setwd("~/Desktop/R-projects/Disco-R/R")
source("disco.R")   # final single-file implementation

options(digits = 20)


# =============================================================================
# DATA
# =============================================================================

df     <- read.csv("~/Desktop/R-projects/Disco-R/experiments/sklearn-circle/circles_data_points.csv")
X      <- as.matrix(df[, c("x1", "x2")])
y_true <- df$true_label


# =============================================================================
# CLUSTERING
# =============================================================================

cat("Running DBSCAN (eps=0.2, minPts=5)...\n")
db_result     <- dbscan::dbscan(X, eps = 0.2, minPts = 5)
db_labels     <- as.integer(db_result$cluster)
db_labels[db_labels == 0L] <- -1L
n_db_clusters <- length(unique(db_labels[db_labels != -1L]))
n_db_noise    <- sum(db_labels == -1L)
cat(sprintf("  -> %d cluster(s), %d noise point(s)\n", n_db_clusters, n_db_noise))

cat("Loading Python K-Means labels...\n")
km_df     <- read.csv("~/Desktop/R-projects/Disco-R/experiments/sklearn-circle/python_km_labels.csv")
km_labels <- as.integer(km_df$km_label)
cat("  -> cluster sizes — 0:", sum(km_labels == 0), " 1:", sum(km_labels == 1), "\n")


# =============================================================================
# DISCO SCORES
# =============================================================================

cat("\nComputing DISCO scores...\n")
scores_db <- disco_samples(X, db_labels, min_points = 5)
disco_db  <- mean(scores_db)

scores_km <- disco_samples(X, km_labels, min_points = 5)
disco_km  <- mean(scores_km)

sep <- paste(rep("=", 62), collapse = "")
cat("\n", sep, "\n", sep = "")
cat("  DISCO RESULTS — 10 decimal places\n")
cat(sep, "\n", sep = "")
cat(sprintf("\n  DISCO score — DBSCAN  : %.20f\n", disco_db))
cat(sprintf("  DISCO score — K-Means : %.20f\n",  disco_km))
cat("\n", sep, "\n", sep = "")


# =============================================================================
# THEME & COLOUR PALETTE
# =============================================================================

library(ggplot2)
library(gridExtra)
library(grid)

dark_theme <- theme_void() +
  theme(
    plot.background   = element_rect(fill = "#1e1e2e", color = NA),
    panel.background  = element_rect(fill = "#13131f", color = NA),
    panel.border      = element_rect(fill = NA, color = "#3a3a5c", linewidth = 0.7),
    plot.title        = element_text(color = "#ffffff", size = 12, face = "bold",
                                     hjust = 0.5, margin = margin(b = 3)),
    plot.subtitle     = element_text(color = "#9999bb", size = 8.5, hjust = 0.5,
                                     margin = margin(b = 8)),
    legend.background = element_rect(fill = "#1e1e2e", color = "#3a3a5c",
                                     linewidth = 0.4),
    legend.text       = element_text(color = "#ddddee", size = 8),
    legend.title      = element_text(color = "#9999bb", size = 8.5, face = "bold"),
    legend.key        = element_rect(fill = "#1e1e2e", color = NA),
    legend.margin     = margin(5, 8, 5, 8),
    axis.title        = element_blank(),
    axis.text         = element_blank(),
    plot.margin       = margin(10, 10, 10, 10)
  )

# Cluster colours — noise grey, clusters vivid
CLUSTER_COLS <- c(
  "-1" = "#555577",   # noise
  "0"  = "#4C9BE8",   # blue
  "1"  = "#F4831F",   # orange
  "2"  = "#50C878",   # green
  "3"  = "#FF6B6B"    # red
)

# DISCO gradient: red → yellow → green
DISCO_GRAD <- scale_color_gradientn(
  colours = c("#d73027", "#f46d43", "#fdae61", "#ffffbf", "#74c476", "#1a9850"),
  limits  = c(-1, 1),
  name    = "DISCO\nscore",
  breaks  = c(-1, -0.5, 0, 0.5, 1),
  labels  = c("-1.0", "-0.5", "0.0", "+0.5", "+1.0"),
  guide   = guide_colorbar(barwidth = 0.8, barheight = 6,
                           ticks.colour = "#555577",
                           frame.colour = "#3a3a5c")
)


# =============================================================================
# BUILD PLOT DATA FRAME
# =============================================================================

plot_df <- data.frame(
  x1           = X[, 1],
  x2           = X[, 2],
  true_label   = factor(y_true),
  dbscan_label = factor(db_labels),
  kmeans_label = factor(km_labels),
  disco_db     = scores_db,
  disco_km     = scores_km,
  is_noise     = db_labels == -1L
)

# Bring noise points to front so they are not hidden under cluster points
plot_df_db_sorted <- plot_df[order(plot_df$is_noise), ]


# =============================================================================
# PANEL 1 — Ground Truth
# =============================================================================

p1 <- ggplot(plot_df, aes(x1, x2, color = true_label)) +
  geom_point(size = 1.8, alpha = 0.88) +
  scale_color_manual(
    values = CLUSTER_COLS,
    labels = c("0" = "Outer ring", "1" = "Inner ring"),
    name   = "True label"
  ) +
  labs(
    title    = "Ground Truth",
    subtitle = "Concentric circles  |  n = 300  |  noise = 0.05  |  factor = 0.4"
  ) +
  dark_theme +
  theme(legend.position = "bottom", legend.direction = "horizontal")


# =============================================================================
# PANEL 2 — DBSCAN Clustering
# =============================================================================

p2 <- ggplot(plot_df_db_sorted,
             aes(x1, x2, color = dbscan_label, shape = is_noise, size = is_noise)) +
  geom_point(alpha = 0.88) +
  scale_color_manual(
    values = CLUSTER_COLS,
    labels = c("-1" = "Noise", "1" = "Cluster 1", "2" = "Cluster 2"),
    name   = "DBSCAN"
  ) +
  scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 4),  guide = "none") +
  scale_size_manual( values = c("FALSE" = 1.8, "TRUE" = 2.4), guide = "none") +
  labs(
    title    = "DBSCAN Clustering",
    subtitle = sprintf("eps = 0.2   minPts = 5   |   %d clusters   %d noise points",
                       n_db_clusters, n_db_noise)
  ) +
  dark_theme +
  theme(legend.position = "bottom", legend.direction = "horizontal")


# =============================================================================
# PANEL 3 — K-Means Clustering
# =============================================================================

p3 <- ggplot(plot_df, aes(x1, x2, color = kmeans_label)) +
  geom_point(size = 1.8, alpha = 0.88) +
  scale_color_manual(
    values = CLUSTER_COLS,
    labels = c("0" = "Cluster 1", "1" = "Cluster 2"),
    name   = "K-Means"
  ) +
  labs(
    title    = "K-Means Clustering",
    subtitle = "k = 2   |   labels loaded from Python for numerical equivalence"
  ) +
  dark_theme +
  theme(legend.position = "bottom", legend.direction = "horizontal")


# =============================================================================
# PANEL 4 — DISCO Point-wise: DBSCAN
# =============================================================================

# Sort so high-score points render on top
plot_df_db_disco <- plot_df[order(plot_df$disco_db), ]

p4 <- ggplot(plot_df_db_disco,
             aes(x1, x2, color = disco_db, shape = is_noise, size = is_noise)) +
  geom_point(alpha = 0.92) +
  DISCO_GRAD +
  scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 4),  guide = "none") +
  scale_size_manual( values = c("FALSE" = 1.9, "TRUE" = 2.5), guide = "none") +
  annotate("text",
           x = min(X[, 1]) + 0.02,
           y = max(X[, 2]) - 0.02,
           label  = sprintf("DISCO = %.10f", disco_db),
           color  = "#ffffff", size = 3, fontface = "bold", hjust = 0) +
  labs(
    title    = "DISCO Point-wise Scores — DBSCAN",
    subtitle = "× = noise point   |   red = poor   green = well-placed"
  ) +
  dark_theme +
  theme(legend.position = "right")


# =============================================================================
# PANEL 5 — DISCO Point-wise: K-Means
# =============================================================================

plot_df_km_disco <- plot_df[order(plot_df$disco_km), ]

p5 <- ggplot(plot_df_km_disco, aes(x1, x2, color = disco_km)) +
  geom_point(size = 1.9, alpha = 0.92) +
  DISCO_GRAD +
  annotate("text",
           x = min(X[, 1]) + 0.02,
           y = max(X[, 2]) - 0.02,
           label  = sprintf("DISCO = %.10f", disco_km),
           color  = "#ffffff", size = 3, fontface = "bold", hjust = 0) +
  labs(
    title    = "DISCO Point-wise Scores — K-Means",
    subtitle = "red = poor fit   green = well-placed   (K-Means cuts across rings)"
  ) +
  dark_theme +
  theme(legend.position = "right")


# =============================================================================
# ASSEMBLE — 2-ROW LAYOUT
#   Row 1: Ground Truth | DBSCAN clusters   | K-Means clusters
#   Row 2: (empty)      | DISCO DBSCAN      | DISCO K-Means
# =============================================================================

title_grob <- textGrob(
  "Concentric Circles: DBSCAN vs K-Means — DISCO Evaluation",
  gp = gpar(col = "#ffffff", fontsize = 14, fontface = "bold")
)

# Empty placeholder to keep the 3-column grid balanced in row 2
blank <- rectGrob(gp = gpar(fill = "#1e1e2e", col = NA))

final_plot <- arrangeGrob(
  p1, p2, p3,
  blank, p4, p5,
  ncol   = 3,
  nrow   = 2,
  heights = c(1, 1),
  top    = title_grob
)

out_path <- "~/Desktop/R-projects/Disco-R/experiments/sklearn-circle/disco_visualization.png"
ggsave(out_path,
       plot   = final_plot,
       width  = 15,
       height = 10,
       dpi    = 150,
       bg     = "#1e1e2e")

cat(sprintf("\nVisualization saved -> %s\n", out_path))
cat("Done.\n")