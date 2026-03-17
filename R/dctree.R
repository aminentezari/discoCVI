# DC-Distance (Density-Connectivity Distance) Computation
# Translated from Python dctree.py — Python is the reference implementation
# MST uses exact Prim's algorithm matching Python's _get_mst_edges() line-by-line


# ── calculate_reachability_distance ──────────────────────────────────────────
# Python dctree.py lines 704-713 — translated verbatim
#
# np.partition(row, k)[:k] gives the k smallest values INCLUDING self (dist=0)
# so max of those k values = (k-1)-th nearest neighbor distance
# FNN::get.knn excludes self → use k = min_points - 1
calculate_reachability_distance <- function(points, min_points = 5) {
  n          <- nrow(points)
  eucl_dists <- as.matrix(dist(points, method = "euclidean"))
  
  if (min_points > 1) {
    k           <- min_points - 1
    knn_result  <- FNN::get.knn(points, k = k)
    reach_dists <- knn_result$nn.dist[, k]
    
    core_i     <- matrix(reach_dists, n, n, byrow = FALSE)
    core_j     <- matrix(reach_dists, n, n, byrow = TRUE)
    eucl_dists <- pmax(eucl_dists, core_i, core_j)
    diag(eucl_dists) <- 0
  }
  eucl_dists
}


# ── get_mst_edges — exact Prim's matching Python dctree.py lines 401-438 ─────
#
# Python (0-indexed):
#   nodes_min_dist = full(n, inf);  parent = full(n, 0)
#   not_in_mst = full(n, True);  u = 0;  nodes_min_dist[0] = 0; not_in_mst[0] = False
#   for i in range(n-1):
#       v = where(not_in_mst & (dist_matrix[u] < nodes_min_dist))
#       nodes_min_dist[v] = dist_matrix[u,v];  parent[v] = u
#       arg = argmin(nodes_min_dist[not_in_mst])
#       u   = arange(n)[not_in_mst][arg]
#       mst_edges[i] = (parent[u], u, nodes_min_dist[u])
#       not_in_mst[u] = False
get_mst_edges <- function(dist_matrix) {
  n              <- nrow(dist_matrix)
  nodes_min_dist <- rep(Inf, n)
  parent         <- rep(1L, n)
  not_in_mst     <- rep(TRUE, n)
  
  u                 <- 1L            # start node (Python uses 0, R uses 1)
  nodes_min_dist[u] <- 0
  not_in_mst[u]     <- FALSE
  
  mst_i    <- integer(n - 1)
  mst_j    <- integer(n - 1)
  mst_dist <- numeric(n - 1)
  
  for (step in seq_len(n - 1)) {
    # v = where(not_in_mst & (dist_matrix[u] < nodes_min_dist))
    update_mask <- not_in_mst & (dist_matrix[u, ] < nodes_min_dist)
    if (any(update_mask)) {
      nodes_min_dist[update_mask] <- dist_matrix[u, update_mask]
      parent[update_mask]         <- u
    }
    
    # arg = argmin(nodes_min_dist[not_in_mst])
    # u   = arange(n)[not_in_mst][arg]
    candidates <- which(not_in_mst)
    u          <- candidates[which.min(nodes_min_dist[candidates])]
    
    mst_i[step]    <- parent[u]
    mst_j[step]    <- u
    mst_dist[step] <- nodes_min_dist[u]
    not_in_mst[u]  <- FALSE
  }
  
  data.frame(i = mst_i, j = mst_j, dist = mst_dist)
}


# ── extract_dc_distances_from_mst — BFS minimax path ─────────────────────────
extract_dc_distances_from_mst <- function(mst_edges, n) {
  adj <- vector("list", n)
  for (k in seq_len(nrow(mst_edges))) {
    u <- mst_edges$i[k]; v <- mst_edges$j[k]; w <- mst_edges$dist[k]
    adj[[u]] <- c(adj[[u]], list(c(v, w)))
    adj[[v]] <- c(adj[[v]], list(c(u, w)))
  }
  
  dc_dists <- matrix(0, n, n)
  for (start in seq_len(n)) {
    visited  <- rep(FALSE, n)
    max_edge <- rep(0.0, n)
    visited[start] <- TRUE
    queue <- list(start)
    while (length(queue) > 0) {
      cur <- queue[[1]]; queue <- queue[-1]
      for (nb_w in adj[[cur]]) {
        nb <- nb_w[1]; w <- nb_w[2]
        if (!visited[nb]) {
          visited[nb]  <- TRUE
          max_edge[nb] <- max(max_edge[cur], w)
          queue[[length(queue) + 1]] <- nb
        }
      }
    }
    dc_dists[start, ] <- max_edge
  }
  dc_dists
}


# ── compute_dc_distances — main entry point ───────────────────────────────────
compute_dc_distances <- function(X, min_points = 5) {
  if (is.data.frame(X)) X <- as.matrix(X)
  n <- nrow(X)
  if (n == 0) return(matrix(0, 0, 0))
  if (n == 1) return(matrix(0, 1, 1))
  
  reach_dists <- calculate_reachability_distance(X, min_points)
  mst_edges   <- get_mst_edges(reach_dists)
  # Python sorts edges by dist before building DCTree — match that here
  mst_edges   <- mst_edges[order(mst_edges$dist), ]
  extract_dc_distances_from_mst(mst_edges, n)
}