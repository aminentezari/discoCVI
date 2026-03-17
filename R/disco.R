# DISCO Evaluation Metric
# Translated from Python disco.py — Python is the reference implementation

library(FNN)

source("dctree.R")


# ── disco_score ───────────────────────────────────────────────────────────────
disco_score <- function(X, labels, min_points = 5) {
  mean(disco_samples(X, labels, min_points))
}


# ── disco_samples — Python disco.py lines 166-200 ────────────────────────────
disco_samples <- function(X, labels, min_points = 5) {
  if (is.data.frame(X)) X <- as.matrix(X)
  if (nrow(X) == 0) stop("Can't calculate DISCO score for empty dataset.")
  if (nrow(X) != length(labels)) stop("Dataset size differs from label size.")
  
  labels    <- as.vector(labels)
  label_set <- unique(labels)
  
  if (length(label_set) == 1 && label_set[1] == -1) return(rep(-1, nrow(X)))
  if (length(label_set) == 1 && label_set[1] != -1) return(rep( 0, nrow(X)))
  
  dc_dists <- compute_dc_distances(X, min_points)
  
  # One cluster with noise
  if (length(label_set) == 2 && -1 %in% label_set) {
    l_         <- labels
    noise_mask <- labels == -1
    n_noise    <- sum(noise_mask)
    l_[noise_mask] <- seq(-1, -n_noise, by = -1)
    disco_values <- numeric(nrow(X))
    cs <- p_cluster(dc_dists, l_, precomputed_dc_dists = TRUE)
    disco_values[!noise_mask] <- cs[!noise_mask]
    nr <- p_noise(X, labels, min_points = min_points, dc_dists = dc_dists)
    disco_values[noise_mask] <- pmin(nr$p_sparse, nr$p_far)
    return(disco_values)
  }
  
  # More than one cluster with optional noise
  disco_values       <- numeric(nrow(X))
  non_noise_mask     <- labels != -1
  non_noise_dc_dists <- dc_dists[non_noise_mask, non_noise_mask, drop = FALSE]
  non_noise_labels   <- labels[non_noise_mask]
  disco_values[non_noise_mask] <- p_cluster(
    non_noise_dc_dists, non_noise_labels, precomputed_dc_dists = TRUE
  )
  if (any(!non_noise_mask)) {
    nr <- p_noise(X, labels, min_points = min_points, dc_dists = dc_dists)
    disco_values[!non_noise_mask] <- pmin(nr$p_sparse, nr$p_far)
  }
  disco_values
}


# ── p_cluster — Python disco.py line 280 ─────────────────────────────────────
# Python: return silhouette_samples(dc_dists, labels, metric="precomputed")
# sklearn silhouette_samples formula for each point i:
#   a(i) = mean distance to all OTHER points in same cluster
#   b(i) = min over other clusters of mean distance to that cluster
#   s(i) = (b - a) / max(a, b)
p_cluster <- function(X, labels, min_points = 5, precomputed_dc_dists = FALSE) {
  if (is.data.frame(X)) X <- as.matrix(X)
  if (!is.matrix(X)) X <- as.matrix(X)
  if (length(X) == 0 || nrow(X) == 0) return(numeric(0))
  if (nrow(X) != length(labels))
    stop("Dataset size of `X` differs from label size of `labels`.")
  if (nrow(X) == 1) return(0)
  
  unique_labels <- unique(labels)
  n_labels      <- length(unique_labels)
  if (n_labels == 1 || n_labels == nrow(X)) return(rep(0, nrow(X)))
  
  dc_dists <- if (precomputed_dc_dists) X else compute_dc_distances(X, min_points)
  
  n      <- nrow(dc_dists)
  scores <- numeric(n)
  
  for (i in seq_len(n)) {
    cl <- labels[i]
    
    # a: mean intra-cluster distance excluding self
    same_idx <- which(labels == cl)
    same_idx <- same_idx[same_idx != i]
    a <- if (length(same_idx) > 0) mean(dc_dists[i, same_idx]) else 0
    
    # b: mean distance to each other cluster, take minimum
    b <- Inf
    for (ol in unique_labels[unique_labels != cl]) {
      other_idx <- which(labels == ol)
      if (length(other_idx) > 0)
        b <- min(b, mean(dc_dists[i, other_idx]))
    }
    
    denom     <- max(a, b)
    scores[i] <- if (is.finite(b) && denom != 0) (b - a) / denom else 0
  }
  scores
}


# ── p_noise — Python disco.py lines 344-400 ──────────────────────────────────
# KDTree(X).query(X, k=min_points) includes self (dist=0)
# .max(axis=1) = (min_points-1)-th actual neighbor
# FNN::get.knn excludes self → use k = min_points - 1
p_noise <- function(X, labels, min_points = 5, dc_dists = NULL) {
  if (is.data.frame(X)) X <- as.matrix(X)
  if (nrow(X) == 0) stop("Can't calculate noise score for empty dataset.")
  if (nrow(X) != length(labels)) stop("Dataset size differs from label size.")
  
  label_set <- unique(labels)
  if (length(label_set) == 1 && label_set[1] == -1)
    return(list(p_sparse = rep(-1, nrow(X)), p_far = rep(-1, nrow(X))))
  if (!(-1 %in% label_set))
    return(list(p_sparse = numeric(0), p_far = numeric(0)))
  
  if (is.null(dc_dists)) dc_dists <- compute_dc_distances(X, min_points)
  
  k          <- min_points - 1
  knn_result <- FNN::get.knn(X, k = k)
  core_dists <- knn_result$nn.dist[, k]
  
  cluster_ids   <- unique(labels[labels != -1])
  max_core_dist <- sapply(cluster_ids, function(cid) max(core_dists[labels == cid]))
  
  noise_mask <- labels == -1
  noise_idx  <- which(noise_mask)
  noise_cd   <- core_dists[noise_mask]
  
  p_sparse <- rep(Inf, sum(noise_mask))
  for (i in seq_along(cluster_ids)) {
    mc       <- max_core_dist[i]
    num      <- noise_cd - mc
    den      <- pmax(noise_cd, mc)
    p_sparse <- pmin(p_sparse, ifelse(den != 0, num / den, 0))
  }
  
  p_far <- rep(Inf, sum(noise_mask))
  for (i in seq_along(cluster_ids)) {
    mc     <- max_core_dist[i]
    cidx   <- which(labels == cluster_ids[i])
    min_dc <- apply(dc_dists[noise_idx, cidx, drop = FALSE], 1, min)
    num    <- min_dc - mc
    den    <- pmax(min_dc, mc)
    p_far  <- pmin(p_far, ifelse(den != 0, num / den, 0))
  }
  
  list(p_sparse = p_sparse, p_far = p_far)
}