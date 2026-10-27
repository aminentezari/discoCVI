# Reference implementation: discoCVI v0.1.1 (matrix-based, BFS minimax),
# kept verbatim (functions renamed with the ref_ prefix) so that the tests
# can check that v0.2.0 gives identical results.

ref_calculate_reachability_distance <- function(points, min_points = 5) {
  if (min_points < 2L)
    stop("`min_points` must be at least 2 for core-distance computation.")
  n          <- nrow(points)
  eucl_dists <- as.matrix(stats::dist(points, method = "euclidean"))
  k           <- min_points - 1L
  reach_dists <- FNN::get.knn(points, k = k)$nn.dist[, k]
  core_i     <- matrix(reach_dists, n, n, byrow = FALSE)
  core_j     <- matrix(reach_dists, n, n, byrow = TRUE)
  eucl_dists <- pmax(eucl_dists, core_i, core_j)
  diag(eucl_dists) <- 0
  eucl_dists
}

ref_get_mst_edges <- function(dist_matrix) {
  n              <- nrow(dist_matrix)
  nodes_min_dist <- rep(Inf, n)
  parent         <- rep(1L, n)
  not_in_mst     <- rep(TRUE, n)
  u                 <- 1L
  nodes_min_dist[u] <- 0
  not_in_mst[u]     <- FALSE
  mst_i    <- integer(n - 1L)
  mst_j    <- integer(n - 1L)
  mst_dist <- numeric(n - 1L)
  for (step in seq_len(n - 1L)) {
    update_mask <- not_in_mst & (dist_matrix[u, ] < nodes_min_dist)
    if (any(update_mask)) {
      nodes_min_dist[update_mask] <- dist_matrix[u, update_mask]
      parent[update_mask]         <- u
    }
    candidates <- which(not_in_mst)
    u          <- candidates[which.min(nodes_min_dist[candidates])]
    mst_i[step]    <- parent[u]
    mst_j[step]    <- u
    mst_dist[step] <- nodes_min_dist[u]
    not_in_mst[u]  <- FALSE
  }
  data.frame(i = mst_i, j = mst_j, dist = mst_dist)
}

ref_extract_dc_distances_from_mst <- function(mst_edges, n) {
  adj <- vector("list", n)
  for (k in seq_len(nrow(mst_edges))) {
    u <- mst_edges$i[k]; v <- mst_edges$j[k]; w <- mst_edges$dist[k]
    adj[[u]] <- c(adj[[u]], list(c(v, w)))
    adj[[v]] <- c(adj[[v]], list(c(u, w)))
  }
  dc_dists <- matrix(0, n, n)
  for (start in seq_len(n)) {
    visited        <- rep(FALSE, n)
    max_edge       <- rep(0.0, n)
    visited[start] <- TRUE
    queue          <- list(start)
    while (length(queue) > 0L) {
      cur   <- queue[[1L]]; queue <- queue[-1L]
      for (nb_w in adj[[cur]]) {
        nb <- nb_w[1L]; w <- nb_w[2L]
        if (!visited[nb]) {
          visited[nb]  <- TRUE
          max_edge[nb] <- max(max_edge[cur], w)
          queue[[length(queue) + 1L]] <- nb
        }
      }
    }
    dc_dists[start, ] <- max_edge
  }
  dc_dists
}

ref_compute_dc_distances <- function(X, min_points = 5) {
  if (is.data.frame(X)) X <- as.matrix(X)
  n <- nrow(X)
  if (n == 0L) return(matrix(0, 0, 0))
  if (n == 1L) return(matrix(0, 1, 1))
  reach_dists <- ref_calculate_reachability_distance(X, min_points)
  mst_edges   <- ref_get_mst_edges(reach_dists)
  mst_edges   <- mst_edges[order(mst_edges$dist), ]
  ref_extract_dc_distances_from_mst(mst_edges, n)
}

ref_p_cluster <- function(X, labels, min_points = 5, precomputed_dc_dists = FALSE) {
  if (is.data.frame(X)) X <- as.matrix(X)
  if (!is.matrix(X))    X <- as.matrix(X)
  if (length(X) == 0L || nrow(X) == 0L) return(numeric(0))
  if (nrow(X) == 1L) return(0)
  unique_labels <- unique(labels)
  n_labels      <- length(unique_labels)
  if (n_labels == 1L || n_labels == nrow(X)) return(rep(0, nrow(X)))
  dc_dists <- if (precomputed_dc_dists) X else ref_compute_dc_distances(X, min_points)
  n      <- nrow(dc_dists)
  scores <- numeric(n)
  for (i in seq_len(n)) {
    cl       <- labels[i]
    same_idx <- which(labels == cl)
    same_idx <- same_idx[same_idx != i]
    a        <- if (length(same_idx) > 0L) mean(dc_dists[i, same_idx]) else 0
    b <- Inf
    for (ol in unique_labels[unique_labels != cl]) {
      other_idx <- which(labels == ol)
      if (length(other_idx) > 0L)
        b <- min(b, mean(dc_dists[i, other_idx]))
    }
    denom     <- max(a, b)
    scores[i] <- if (is.finite(b) && denom != 0) (b - a) / denom else 0
  }
  scores
}

ref_p_noise <- function(X, labels, min_points = 5, dc_dists = NULL) {
  if (is.data.frame(X)) X <- as.matrix(X)
  label_set <- unique(labels)
  if (length(label_set) == 1L && label_set[1L] == -1L)
    return(list(p_sparse = rep(-1, nrow(X)), p_far = rep(-1, nrow(X))))
  if (!(-1L %in% label_set))
    return(list(p_sparse = numeric(0), p_far = numeric(0)))
  if (is.null(dc_dists)) dc_dists <- ref_compute_dc_distances(X, min_points)
  k          <- min_points - 1L
  core_dists <- FNN::get.knn(X, k = k)$nn.dist[, k]
  cluster_ids   <- unique(labels[labels != -1L])
  max_core_dist <- sapply(cluster_ids, function(cid) max(core_dists[labels == cid]))
  noise_mask <- labels == -1L
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
    min_dc <- apply(dc_dists[noise_idx, cidx, drop = FALSE], 1L, min)
    num    <- min_dc - mc
    den    <- pmax(min_dc, mc)
    p_far  <- pmin(p_far, ifelse(den != 0, num / den, 0))
  }
  list(p_sparse = p_sparse, p_far = p_far)
}

ref_disco_samples <- function(X, labels, min_points = 5) {
  if (is.data.frame(X)) X <- as.matrix(X)
  labels    <- as.vector(labels)
  label_set <- unique(labels)
  if (length(label_set) == 1L && label_set[1L] == -1L) return(rep(-1, nrow(X)))
  if (length(label_set) == 1L && label_set[1L] != -1L) return(rep( 0, nrow(X)))
  dc_dists <- ref_compute_dc_distances(X, min_points)
  if (length(label_set) == 2L && -1L %in% label_set) {
    l_         <- labels
    noise_mask <- labels == -1L
    n_noise    <- sum(noise_mask)
    l_[noise_mask] <- seq(-1L, -n_noise, by = -1L)
    disco_values <- numeric(nrow(X))
    cs <- ref_p_cluster(dc_dists, l_, precomputed_dc_dists = TRUE)
    disco_values[!noise_mask] <- cs[!noise_mask]
    nr <- ref_p_noise(X, labels, min_points = min_points, dc_dists = dc_dists)
    disco_values[noise_mask] <- pmin(nr$p_sparse, nr$p_far)
    return(disco_values)
  }
  disco_values       <- numeric(nrow(X))
  non_noise_mask     <- labels != -1L
  non_noise_dc_dists <- dc_dists[non_noise_mask, non_noise_mask, drop = FALSE]
  non_noise_labels   <- labels[non_noise_mask]
  disco_values[non_noise_mask] <- ref_p_cluster(
    non_noise_dc_dists, non_noise_labels, precomputed_dc_dists = TRUE)
  if (any(!non_noise_mask)) {
    nr <- ref_p_noise(X, labels, min_points = min_points, dc_dists = dc_dists)
    disco_values[!non_noise_mask] <- pmin(nr$p_sparse, nr$p_far)
  }
  disco_values
}

# Synthetic data: k Gaussian blobs plus uniform noise, with generating labels
make_blobs <- function(n, p = 2, noise_frac = 0.1, k = 3) {
  n_noise <- round(n * noise_frac); n_cl <- n - n_noise
  centers <- matrix(stats::rnorm(k * p, sd = 6), k, p)
  id <- sample(seq_len(k), n_cl, replace = TRUE)
  X <- rbind(centers[id, , drop = FALSE] + matrix(stats::rnorm(n_cl * p), ncol = p),
             matrix(stats::runif(n_noise * p, -12, 12), ncol = p))
  list(X = X, labels = c(id, rep(-1L, n_noise)))
}
