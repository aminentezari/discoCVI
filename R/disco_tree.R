# =============================================================================
#  SECTION 3 — FAST, MEMORY-LIGHT DISCO (v0.2.0)
#
#  DISCO is computed without ever storing an n x n matrix:
#    1. core distances from k-nearest neighbours (as in v0.1.1);
#    2. Prim's MST on mutual-reachability distances, computed on the fly in
#       C++ (.prim_mrd_cpp, src/prim_mrd.cpp);
#    3. the single-linkage merge tree obtained from the sorted MST edges;
#    4. one top-down pass over that tree.  The DC distance between two points
#       equals the weight of the merge at which they first become connected,
#       so for every point we can accumulate
#         - the SUM of DC distances to each cluster   (silhouette a, b)
#         - the MIN DC distance to each cluster        (noise score p_far)
#         - the MIN DC distance to any noise point     (one cluster + noise)
#  Time O(n^2 p) for the MST plus O(n K) for the rest; memory O(n K), where K
#  is the number of clusters.  Results are identical to the matrix-based
#  v0.1.1 implementation up to floating-point rounding.
# =============================================================================

#' Core distances (distance to the (min_points - 1)-th nearest neighbour)
#' @noRd
.core_distances <- function(X, min_points) {
  if (min_points < 2L)
    stop("`min_points` must be at least 2 for core-distance computation.")
  k <- min_points - 1L
  FNN::get.knn(X, k = k)$nn.dist[, k]
}

#' MST edges of the mutual-reachability graph, without an n x n matrix
#' @noRd
.mst_edges_mrd <- function(X, core) {
  e <- .prim_mrd_cpp(t(X), as.double(core))
  data.frame(i = e$i, j = e$j, dist = e$dist)
}

#' Per-sample DISCO scores via the merge tree (internal engine)
#' @noRd
.disco_samples_tree <- function(X, labels, min_points = 5) {
  X <- as.matrix(X)
  storage.mode(X) <- "double"
  n <- nrow(X)

  # ---- 1-2. core distances and MST ---------------------------------------
  core <- .core_distances(X, min_points)
  mst  <- .mst_edges_mrd(X, core)

  # ---- 3. merge tree (union by size); leaves 1..n, internal n+1..2n-1 ----
  o  <- order(mst$dist)
  ei <- mst$i[o]; ej <- mst$j[o]; wt <- mst$dist[o]
  uf_parent <- seq_len(n); uf_size <- rep(1L, n); top <- seq_len(n)
  left <- integer(n - 1L); right <- integer(n - 1L)
  for (s in seq_len(n - 1L)) {
    ra <- ei[s]; while (uf_parent[ra] != ra) ra <- uf_parent[ra]
    rb <- ej[s]; while (uf_parent[rb] != rb) rb <- uf_parent[rb]
    left[s] <- top[ra]; right[s] <- top[rb]
    if (uf_size[ra] < uf_size[rb]) { tmp <- ra; ra <- rb; rb <- tmp }
    uf_parent[rb] <- ra
    uf_size[ra]   <- uf_size[ra] + uf_size[rb]
    top[ra]       <- n + s
  }
  N <- 2L * n - 1L

  # ---- 4a. bottom-up: cluster and noise counts in every subtree ----------
  noise <- labels == -1L
  cids  <- unique(labels[!noise])
  K     <- length(cids)
  cl    <- match(labels, cids)                    # NA for noise points
  cnt   <- matrix(0, K, N)                        # one column per tree node
  cnt[cbind(cl[!noise], which(!noise))] <- 1
  nz    <- numeric(N); nz[which(noise)] <- 1
  for (s in seq_len(n - 1L)) {
    cnt[, n + s] <- cnt[, left[s]] + cnt[, right[s]]
    nz[n + s]    <- nz[left[s]] + nz[right[s]]
  }

  # ---- 4b. top-down: sums and minima of DC distances ---------------------
  S  <- matrix(0,   K, N)    # sum of DC distances to each cluster
  MF <- matrix(Inf, K, N)    # min DC distance to each cluster
  MN <- rep(Inf, N)          # min DC distance to any noise point
  for (s in (n - 1L):1L) {
    p <- n + s; w <- wt[s]; lc <- left[s]; rc <- right[s]
    S[, lc]  <- S[, p] + w * cnt[, rc]
    S[, rc]  <- S[, p] + w * cnt[, lc]
    MF[, lc] <- ifelse(cnt[, rc] > 0, pmin(MF[, p], w), MF[, p])
    MF[, rc] <- ifelse(cnt[, lc] > 0, pmin(MF[, p], w), MF[, p])
    MN[lc]   <- if (nz[rc] > 0) min(MN[p], w) else MN[p]
    MN[rc]   <- if (nz[lc] > 0) min(MN[p], w) else MN[p]
  }

  # ---- 5. cluster points: silhouette on DC distances ---------------------
  sz      <- cnt[, N]                              # cluster sizes
  out     <- numeric(n)
  ci      <- which(!noise)
  own     <- cl[ci]
  n_noise <- sum(noise)
  nn      <- length(ci)

  if (K == 1L && n_noise > 0L) {
    # One cluster + noise: each noise point acts as its own singleton
    # cluster (as in v0.1.1), so b = min DC distance to any noise point.
    if (1L + n_noise != n) {
      a   <- if (sz[1L] > 1) S[1L, ci] / (sz[1L] - 1) else rep(0, nn)
      b   <- MN[ci]
      den <- pmax(a, b)
      out[ci] <- ifelse(is.finite(b) & den != 0, (b - a) / den, 0)
    }
  } else if (!(nn == 1L || K == 1L || K == nn)) {
    Sc  <- S[, ci, drop = FALSE]                   # K x nn
    pos <- cbind(own, seq_len(nn))
    msz <- sz[own]
    a   <- ifelse(msz > 1, Sc[pos] / pmax(msz - 1, 1), 0)
    Mb  <- Sc / sz                                 # mean DC distance to each cluster
    Mb[pos] <- Inf
    b   <- do.call(pmin, lapply(seq_len(K), function(r) Mb[r, ]))
    den <- pmax(a, b)
    sc  <- ifelse(is.finite(b) & den != 0, (b - a) / den, 0)
    sc[msz == 1] <- 0                              # singleton clusters score 0
    out[ci] <- sc
  }

  # ---- 6. noise points: p_sparse and p_far -------------------------------
  if (n_noise > 0L) {
    ni  <- which(noise)
    ncd <- core[ni]
    mcd <- vapply(cids, function(cc) max(core[labels == cc]), numeric(1))
    ps  <- rep(Inf, n_noise); pf <- rep(Inf, n_noise)
    for (j in seq_len(K)) {
      mc  <- mcd[j]
      den <- pmax(ncd, mc)
      ps  <- pmin(ps, ifelse(den != 0, (ncd - mc) / den, 0))
      md  <- MF[j, ni]
      den <- pmax(md, mc)
      pf  <- pmin(pf, ifelse(den != 0, (md - mc) / den, 0))
    }
    out[ni] <- pmin(ps, pf)
  }
  out
}
