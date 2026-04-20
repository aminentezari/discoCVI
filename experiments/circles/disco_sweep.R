#!/usr/bin/env Rscript
# =============================================================================
# DISCO Hyperparameter Sweep
# Usage:
#   Rscript disco_sweep.R --dataset complex9
#   Rscript disco_sweep.R --dataset circles
#   Rscript disco_sweep.R --dataset moons
#   Rscript disco_sweep.R --dataset dartboard1
#   Rscript disco_sweep.R --dataset complex8
#   Rscript disco_sweep.R --dataset spiral3
#   Rscript disco_sweep.R --dataset blobs
#   Rscript disco_sweep.R --dataset diagonal_blobs
#
# Sweeps DBSCAN eps x min_points grid and reports DISCO scores
# =============================================================================

# ── Parse argument ────────────────────────────────────────────────────────────
args    <- commandArgs(trailingOnly = TRUE)
dataset <- "circles"   # default
for (i in seq_along(args)) {
  if (args[i] == "--dataset" && i < length(args))
    dataset <- args[i + 1]
}

# ── Packages ──────────────────────────────────────────────────────────────────
required <- c("dbscan", "FNN", "foreign", "MASS")
for (p in required) {
  if (!requireNamespace(p, quietly = TRUE))
    install.packages(p, repos = "https://cloud.r-project.org", quiet = TRUE)
}

setwd("~/Desktop/R-projects/Disco-R/R")
source("disco.R")

options(digits = 10)

base <- "~/Desktop/R-projects/Disco-R"

# =============================================================================
# LOAD DATASET
# =============================================================================

cat(sprintf("\n=== DISCO Hyperparameter Sweep: %s ===\n\n", dataset))

if (dataset == "circles") {
  data   <- make_circles(n_samples = 300, noise = 0.05, factor = 0.4,
                         random_state = 42)
  X      <- data$X
  y_true <- data$labels
  k_km   <- 2
  eps_grid <- c(0.1, 0.15, 0.2, 0.25, 0.3, 0.4)
  
} else if (dataset == "moons") {
  data   <- make_moons(n_samples = 300, noise = 0.05, random_state = 42)
  X      <- data$X
  y_true <- data$labels
  k_km   <- 2
  eps_grid <- c(0.1, 0.15, 0.2, 0.25, 0.3, 0.4)
  
} else if (dataset == "complex9") {
  raw    <- foreign::read.arff(path.expand(
    file.path(base, "data/complex9.arff")))
  X      <- as.matrix(raw[, c("x","y")])
  y_true <- as.integer(as.character(raw$class))
  k_km   <- 9
  eps_grid <- c(8, 10, 12, 15, 18, 20)
  
} else if (dataset == "complex8") {
  raw    <- foreign::read.arff(path.expand(
    file.path(base, "data/complex8.arff")))
  X      <- as.matrix(raw[, c("x","y")])
  y_true <- as.integer(as.character(raw$class))
  k_km   <- 8
  eps_grid <- c(6, 8, 10, 12, 15, 18)
  
} else if (dataset == "dartboard1") {
  raw    <- foreign::read.arff(path.expand(
    file.path(base, "data/dartboard1.arff")))
  X      <- as.matrix(raw[, c("a0","a1")])
  y_true <- as.integer(as.character(raw$class))
  k_km   <- 4
  eps_grid <- c(0.05, 0.06, 0.07, 0.08, 0.10, 0.12)
  
} else if (dataset == "spiral3") {
  raw    <- foreign::read.arff(path.expand(
    file.path(base, "data/3-spiral.arff")))
  X      <- as.matrix(raw[, c("x","y")])
  y_true <- as.integer(as.character(raw$class)) - 1L
  k_km   <- 3
  eps_grid <- c(1.0, 1.5, 2.0, 2.5, 3.0, 4.0)
  
} else if (dataset == "blobs") {
  set.seed(42)
  sigma   <- diag(2) * 0.55^2
  centres <- list(c(1.5,7.0), c(6.5,7.0), c(4.0,2.5))
  X       <- do.call(rbind, lapply(centres, function(mu)
    MASS::mvrnorm(n=150, mu=mu, Sigma=sigma)))
  y_true  <- rep(0:2, each=150)
  k_km    <- 3
  eps_grid <- c(0.3, 0.4, 0.5, 0.6, 0.7, 0.8)
  
} else if (dataset == "diagonal_blobs") {
  set.seed(42)
  sigma   <- matrix(c(1.2,-1.0,-1.0,1.2), nrow=2)
  centres <- list(c(2.5,5.0), c(0.5,1.8), c(-1.5,-1.5))
  X       <- do.call(rbind, lapply(centres, function(mu)
    MASS::mvrnorm(n=200, mu=mu, Sigma=sigma)))
  y_true  <- rep(0:2, each=200)
  k_km    <- 3
  eps_grid <- c(0.4, 0.5, 0.6, 0.8, 1.0, 1.2)
  
} else {
  stop(sprintf("Unknown dataset: '%s'\nAvailable: circles, moons, complex9,
complex8, dartboard1, spiral3, blobs, diagonal_blobs", dataset))
}

cat(sprintf("Loaded: n=%d  k_kmeans=%d\n\n", nrow(X), k_km))

# =============================================================================
# SWEEP GRID
# =============================================================================

min_pts_grid <- c(3, 5, 7, 10)

# Header
sep  <- paste(rep("-", 80), collapse="")
sep2 <- paste(rep("=", 80), collapse="")

cat(sep2, "\n")
cat(sprintf("%-6s %-8s %-6s %-8s %-12s %-12s\n",
            "eps", "minPts", "n_cl", "n_noise", "DISCO_DBSCAN", "DISCO_KM"))
cat(sep, "\n")

results <- list()

for (eps in eps_grid) {
  for (mp in min_pts_grid) {
    
    # DBSCAN
    db        <- dbscan::dbscan(X, eps = eps, minPts = mp)
    db_labels <- as.integer(db$cluster)
    db_labels[db_labels == 0L] <- -1L
    n_cl    <- length(unique(db_labels[db_labels != -1L]))
    n_noise <- sum(db_labels == -1L)
    
    # K-Means (fixed partition, only DISCO min_points varies)
    set.seed(42)
    km        <- kmeans(X, centers = k_km, nstart = 10, iter.max = 300)
    km_labels <- as.integer(km$cluster) - 1L
    
    # DISCO with current min_points
    s_db <- tryCatch(
      mean(disco_samples(X, db_labels, min_points = mp)),
      error = function(e) NA_real_
    )
    s_km <- tryCatch(
      mean(disco_samples(X, km_labels, min_points = mp)),
      error = function(e) NA_real_
    )
    
    cat(sprintf("%-6.3f %-8d %-6d %-8d %-12.6f %-12.6f\n",
                eps, mp, n_cl, n_noise,
                ifelse(is.na(s_db), -99, s_db),
                ifelse(is.na(s_km), -99, s_km)))
    
    results[[length(results)+1]] <- data.frame(
      dataset   = dataset,
      eps       = eps,
      min_pts   = mp,
      n_clusters = n_cl,
      n_noise   = n_noise,
      disco_dbscan = ifelse(is.na(s_db), NA, s_db),
      disco_kmeans = ifelse(is.na(s_km), NA, s_km)
    )
  }
  cat(sep, "\n")
}

cat(sep2, "\n")

# =============================================================================
# BEST CONFIGURATIONS
# =============================================================================

df_all <- do.call(rbind, results)

cat("\n--- Best DBSCAN configuration (highest DISCO) ---\n")
best_db <- df_all[which.max(df_all$disco_dbscan), ]
cat(sprintf("  eps=%.3f  min_points=%d  n_clusters=%d  n_noise=%d  DISCO=%.10f\n",
            best_db$eps, best_db$min_pts,
            best_db$n_clusters, best_db$n_noise,
            best_db$disco_dbscan))

cat("\n--- Best K-Means configuration (highest DISCO) ---\n")
best_km <- df_all[which.max(df_all$disco_kmeans), ]
cat(sprintf("  min_points=%d  DISCO=%.10f\n",
            best_km$min_pts, best_km$disco_kmeans))

# =============================================================================
# SAVE RESULTS
# =============================================================================

out_dir <- file.path(path.expand(base), "experiments", dataset)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
out_csv <- file.path(out_dir, paste0("sweep_results_", dataset, ".csv"))
write.csv(df_all, out_csv, row.names = FALSE)
cat(sprintf("\nFull results saved -> %s\n", out_csv))
cat("Done.\n\n")