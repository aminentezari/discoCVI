#' disco: Density-Informed Clustering Scoring and Optimisation
#'
#' The DISCO metric evaluates the quality of a clustering result using
#' density-connectivity (DC) distances derived from the minimum spanning tree
#' of the mutual-reachability graph.  It generalises the silhouette coefficient
#' to density-based partitions and assigns a principled score to noise points.
#'
#' @keywords internal
"_PACKAGE"
#' @aliases disco
#'
# <- <- ' @importFrom FNN get.knn
#' @importFrom stats dist
NULL


# =============================================================================
#  SECTION 1 — DC-DISTANCE INFRASTRUCTURE
#  Translated from Python dctree.py (reference implementation)
# =============================================================================

# -----------------------------------------------------------------------------
#' Compute mutual-reachability (reachability) distances
#'
#' @description
#' For every pair of points \eqn{(i, j)}, the mutual-reachability distance is
#' \deqn{d_{\text{reach}}(i,j) =
#'   \max\bigl(\text{core}_k(i),\; \text{core}_k(j),\; d(i,j)\bigr)}
#' where \eqn{\text{core}_k(i)} is the distance from point \eqn{i} to its
#' \eqn{k}-th nearest neighbour (\eqn{k = \texttt{min\_points} - 1}) and
#' \eqn{d(i,j)} is the Euclidean distance.
#'
#' @param points A numeric matrix of shape \eqn{n \times p}.
#' @param min_points A positive integer \eqn{\geq 2} giving the neighbourhood size used for
#'   the core-distance calculation.  Corresponds to \code{MinPts} in HDBSCAN.
#'   Default is \code{5}.
#'
#' @return A symmetric \eqn{n \times n} numeric matrix of mutual-reachability
#'   distances with zeros on the diagonal.
#'
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' X <- matrix(rnorm(50), ncol = 2)
#' R <- calculate_reachability_distance(X, min_points = 5)
#' }
calculate_reachability_distance <- function(points, min_points = 5) {
  if (min_points < 2L)
    stop("`min_points` must be at least 2 for core-distance computation.")
  n          <- nrow(points)
  eucl_dists <- as.matrix(dist(points, method = "euclidean"))
  
  if (min_points > 1) {
    k           <- min_points - 1L
    knn_result  <- FNN::get.knn(points, k = k)
    reach_dists <- knn_result$nn.dist[, k]
    
    core_i     <- matrix(reach_dists, n, n, byrow = FALSE)
    core_j     <- matrix(reach_dists, n, n, byrow = TRUE)
    eucl_dists <- pmax(eucl_dists, core_i, core_j)
    diag(eucl_dists) <- 0
  }
  eucl_dists
}


# -----------------------------------------------------------------------------
#' Compute a minimum spanning tree via Prim's algorithm
#'
#' @description
#' Implements Prim's algorithm exactly as in the reference Python code
#' (\code{dctree.py}, lines 401–438), operating on a precomputed distance
#' matrix.
#'
#' @param dist_matrix A symmetric \eqn{n \times n} numeric distance matrix.
#'
#' @return A \code{data.frame} with \eqn{n-1} rows and three columns:
#'   \describe{
#'     \item{i}{Integer index of the first endpoint (1-based).}
#'     \item{j}{Integer index of the second endpoint (1-based).}
#'     \item{dist}{Edge weight.}
#'   }
#'
#' @keywords internal
get_mst_edges <- function(dist_matrix) {
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


# -----------------------------------------------------------------------------
#' Extract DC distances from an MST via BFS minimax-path traversal
#'
#' @description
#' Given the edges of a minimum spanning tree, computes the density-connectivity
#' (DC) distance matrix.  The DC distance between two points is the maximum
#' edge weight on the unique path connecting them in the MST (minimax path).
#' BFS is used to propagate these path maxima from every source node.
#'
#' @param mst_edges A \code{data.frame} with columns \code{i}, \code{j},
#'   \code{dist} as returned by \code{\link{get_mst_edges}}.
#' @param n Integer, total number of points.
#'
#' @return A symmetric \eqn{n \times n} numeric matrix of DC distances.
#'
#' @keywords internal
extract_dc_distances_from_mst <- function(mst_edges, n) {
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


# -----------------------------------------------------------------------------
#' Compute density-connectivity (DC) distances
#'
#' @description
#' The main entry point for constructing the DC-distance matrix used throughout
#' the DISCO metric.  The procedure is:
#' \enumerate{
#'   \item Compute mutual-reachability distances
#'     (\code{\link{calculate_reachability_distance}}).
#'   \item Build the minimum spanning tree of those distances
#'     (\code{\link{get_mst_edges}}).
#'   \item Extract pairwise DC distances as minimax-path weights in the MST
#'     (\code{\link{extract_dc_distances_from_mst}}).
#' }
#'
#' @param X A numeric matrix of shape \eqn{n \times p}, or a
#'   \code{data.frame} that will be coerced to a matrix.
#' @param min_points A positive integer for the core-distance neighbourhood
#'   size.  Default is \code{5}.
#'
#' @return A symmetric \eqn{n \times n} numeric matrix of DC distances.
#'
#' @export
#'
#' @examples
#' set.seed(1)
#' X <- matrix(rnorm(40), ncol = 2)
#' D <- compute_dc_distances(X, min_points = 5)
#' dim(D)   # 20 x 20
compute_dc_distances <- function(X, min_points = 5) {
  if (is.data.frame(X)) X <- as.matrix(X)
  n <- nrow(X)
  if (n == 0L) return(matrix(0, 0, 0))
  if (n == 1L) return(matrix(0, 1, 1))
  
  reach_dists <- calculate_reachability_distance(X, min_points)
  mst_edges   <- get_mst_edges(reach_dists)
  mst_edges   <- mst_edges[order(mst_edges$dist), ]
  extract_dc_distances_from_mst(mst_edges, n)
}


# =============================================================================
#  SECTION 2 — DISCO SCORING FUNCTIONS
#  Translated from Python disco.py (reference implementation)
# =============================================================================

# -----------------------------------------------------------------------------
#' Per-sample DISCO scores
#'
#' @description
#' Computes a pointwise DISCO score for every observation in \code{X}.  The
#' score lies in \eqn{[-1, 1]}:
#' \itemize{
#'   \item Values close to \eqn{1} indicate a well-placed point (either
#'     tightly within its cluster or a noise point far from all clusters).
#'   \item Values close to \eqn{0} indicate borderline placement.
#'   \item Values close to \eqn{-1} indicate a misplaced point (or a noise
#'     point that should belong to a cluster).
#' }
#'
#' Four cases are handled:
#' \enumerate{
#'   \item \strong{All noise} — every point labelled \code{-1}: all scores
#'     are \code{-1}.
#'   \item \strong{Single cluster with no noise} — all scores are \code{0}.
#'   \item \strong{One real cluster + noise} — cluster points are scored via
#'     \code{\link{p_cluster}}; noise points are scored via
#'     \code{\link{p_noise}}.
#'   \item \strong{Two or more clusters (optional noise)} — non-noise points
#'     use \code{\link{p_cluster}} on the non-noise sub-matrix; noise points
#'     use \code{\link{p_noise}}.
#' }
#'
#' @param X A numeric matrix (\eqn{n \times p}) or \code{data.frame}.
#' @param labels An integer vector of length \eqn{n} containing cluster labels.
#'   Use \code{-1} to denote noise/outlier points.
#' @param min_points A positive integer for the core-distance neighbourhood
#'   size.  Default is \code{5}.
#'
#' @return A numeric vector of length \eqn{n} with per-point DISCO scores.
#'
#' @export
#'
#' @seealso \code{\link{disco_score}}, \code{\link{p_cluster}},
#'   \code{\link{p_noise}}
#'
#' @examples
#' set.seed(42)
#' X <- matrix(rnorm(100), ncol = 2)
#' labels <- rep(c(0L, 1L), each = 25)
#' s <- disco_samples(X, labels)
#' hist(s, main = "Per-sample DISCO scores")
disco_samples <- function(X, labels, min_points = 5) {
  if (is.data.frame(X)) X <- as.matrix(X)
  if (nrow(X) == 0L) stop("Can't calculate DISCO score for empty dataset.")
  if (nrow(X) != length(labels))
    stop("Dataset size differs from label size.")
  
  labels    <- as.vector(labels)
  label_set <- unique(labels)
  
  if (length(label_set) == 1L && label_set[1L] == -1L)
    return(rep(-1, nrow(X)))
  if (length(label_set) == 1L && label_set[1L] != -1L)
    return(rep( 0, nrow(X)))
  
  dc_dists <- compute_dc_distances(X, min_points)
  
  # ── One real cluster + noise ──────────────────────────────────────────────
  if (length(label_set) == 2L && -1L %in% label_set) {
    l_         <- labels
    noise_mask <- labels == -1L
    n_noise    <- sum(noise_mask)
    l_[noise_mask] <- seq(-1L, -n_noise, by = -1L)
    
    disco_values <- numeric(nrow(X))
    cs <- p_cluster(dc_dists, l_, precomputed_dc_dists = TRUE)
    disco_values[!noise_mask] <- cs[!noise_mask]
    
    nr <- p_noise(X, labels, min_points = min_points, dc_dists = dc_dists)
    disco_values[noise_mask] <- pmin(nr$p_sparse, nr$p_far)
    return(disco_values)
  }
  
  # ── Two or more clusters (optional noise) ────────────────────────────────
  disco_values       <- numeric(nrow(X))
  non_noise_mask     <- labels != -1L
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


# -----------------------------------------------------------------------------
#' Overall DISCO score
#'
#' @description
#' Returns the mean of the per-sample DISCO scores produced by
#' \code{\link{disco_samples}}.  This is the single-number summary of
#' clustering quality used for model selection and comparison.
#'
#' @param X A numeric matrix (\eqn{n \times p}) or \code{data.frame}.
#' @param labels An integer vector of cluster labels (\code{-1} for noise).
#' @param min_points Positive integer; core-distance neighbourhood size.
#'   Default is \code{5}.
#'
#' @return A single numeric value in \eqn{[-1, 1]}.
#'
#' @export
#'
#' @seealso \code{\link{disco_samples}}
#'
#' @examples
#' set.seed(42)
#' X <- matrix(rnorm(100), ncol = 2)
#' labels <- rep(c(0L, 1L), each = 25)
#' disco_score(X, labels)
disco_score <- function(X, labels, min_points = 5) {
  mean(disco_samples(X, labels, min_points))
}


# -----------------------------------------------------------------------------
#' Silhouette-like cluster scores using DC distances
#'
#' @description
#' Computes a silhouette coefficient for each non-noise point using the
#' precomputed (or internally derived) DC-distance matrix rather than raw
#' Euclidean distances.  This matches the formula used by
#' \code{sklearn.metrics.silhouette_samples} with \code{metric="precomputed"}
#' (Python reference: \code{disco.py}, line 280):
#' \deqn{s(i) = \frac{b(i) - a(i)}{\max(a(i),\, b(i))}}
#' where \eqn{a(i)} is the mean DC distance from \eqn{i} to all other points
#' in the same cluster and \eqn{b(i)} is the minimum over other clusters of
#' the mean DC distance from \eqn{i} to that cluster.
#'
#' @param X Either (a) a numeric matrix of raw data (\eqn{n \times p}) when
#'   \code{precomputed_dc_dists = FALSE}, or (b) a precomputed \eqn{n \times n}
#'   DC-distance matrix when \code{precomputed_dc_dists = TRUE}.
#' @param labels An integer vector of cluster labels of length \eqn{n}.
#'   Noise labels (\code{-1}) should not be present; pass only the non-noise
#'   subset.
#' @param min_points Positive integer; used only when
#'   \code{precomputed_dc_dists = FALSE}.  Default is \code{5}.
#' @param precomputed_dc_dists Logical.  If \code{TRUE}, \code{X} is treated
#'   as an already-computed DC-distance matrix; no further distances are
#'   computed.  Default is \code{FALSE}.
#'
#' @return A numeric vector of length \eqn{n} with per-point silhouette-style
#'   scores in \eqn{[-1, 1]}.
#'
#' @export
#'
#' @seealso \code{\link{disco_samples}}, \code{\link{compute_dc_distances}}
#'
#' @examples
#' set.seed(7)
#' X <- matrix(rnorm(60), ncol = 2)
#' labels <- rep(c(0L, 1L, 2L), each = 10)
#' p_cluster(X, labels)
p_cluster <- function(X, labels, min_points = 5, precomputed_dc_dists = FALSE) {
  if (is.data.frame(X)) X <- as.matrix(X)
  if (!is.matrix(X))    X <- as.matrix(X)
  if (length(X) == 0L || nrow(X) == 0L) return(numeric(0))
  if (nrow(X) != length(labels))
    stop("Dataset size of `X` differs from label size of `labels`.")
  if (nrow(X) == 1L) return(0)
  
  unique_labels <- unique(labels)
  n_labels      <- length(unique_labels)
  if (n_labels == 1L || n_labels == nrow(X)) return(rep(0, nrow(X)))
  
  dc_dists <- if (precomputed_dc_dists) X else compute_dc_distances(X, min_points)
  
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


# -----------------------------------------------------------------------------
#' Noise-point scores
#'
#' @description
#' Assigns a quality score to each point labelled as noise (\code{-1}).  Two
#' complementary sub-scores are computed and the element-wise minimum is taken
#' as the final score:
#'
#' \describe{
#'   \item{\eqn{p_{\text{sparse}}}}{Measures whether the noise point is sparser
#'     (more peripheral in density) than the densest part of every real cluster.
#'     For cluster \eqn{c}, let \eqn{M_c} be the maximum core distance over
#'     all points in \eqn{c}.  Then
#'     \deqn{p_{\text{sparse}}(i) =
#'       \min_c \frac{\text{core}_k(i) - M_c}{\max(\text{core}_k(i),\, M_c)}.}}
#'   \item{\eqn{p_{\text{far}}}}{Measures whether the noise point is far from
#'     every cluster in DC-distance space.  For cluster \eqn{c}, let
#'     \eqn{d_{\min,c}(i)} be the minimum DC distance from \eqn{i} to any
#'     point in \eqn{c}.  Then
#'     \deqn{p_{\text{far}}(i) =
#'       \min_c \frac{d_{\min,c}(i) - M_c}{\max(d_{\min,c}(i),\, M_c)}.}}
#' }
#'
#' Both sub-scores lie in \eqn{[-1, 1]}: positive means the noise point is
#' legitimately sparse/far; negative means it is denser/closer than the cluster
#' boundary and might be a misclassified inlier.
#'
#' @param X A numeric matrix (\eqn{n \times p}) or \code{data.frame} of all
#'   points (including non-noise).
#' @param labels An integer vector of length \eqn{n}; \code{-1} denotes noise.
#' @param min_points Positive integer \eqn{\geq 2}; core-distance neighbourhood size.
#'   Default is \code{5}.
#' @param dc_dists Optional precomputed \eqn{n \times n} DC-distance matrix.
#'   If \code{NULL} (default), it is computed internally.
#'
#' @return A named list with two numeric vectors, each of length equal to the
#'   number of noise points:
#'   \describe{
#'     \item{p_sparse}{Sparsity-based noise scores.}
#'     \item{p_far}{DC-distance-based noise scores.}
#'   }
#'
#' @export
#'
#' @seealso \code{\link{disco_samples}}
#'
#' @examples
#' set.seed(3)
#' X      <- matrix(rnorm(60), ncol = 2)   # 30 rows x 2 cols
#' labels <- c(rep(0L, 10), rep(1L, 10), rep(-1L, 10))  # 30 labels
#' nr     <- p_noise(X, labels, min_points = 3)
#' str(nr)
p_noise <- function(X, labels, min_points = 5, dc_dists = NULL) {
  if (is.data.frame(X)) X <- as.matrix(X)
  if (min_points < 2L)
    stop("`min_points` must be at least 2 for core-distance computation.")
  if (nrow(X) == 0L) stop("Can't calculate noise score for empty dataset.")
  if (nrow(X) != length(labels))
    stop("Dataset size differs from label size.")
  
  label_set <- unique(labels)
  
  if (length(label_set) == 1L && label_set[1L] == -1L)
    return(list(p_sparse = rep(-1, nrow(X)), p_far = rep(-1, nrow(X))))
  if (!(-1L %in% label_set))
    return(list(p_sparse = numeric(0), p_far = numeric(0)))
  
  if (is.null(dc_dists)) dc_dists <- compute_dc_distances(X, min_points)
  
  k          <- min_points - 1L
  knn_result <- FNN::get.knn(X, k = k)
  core_dists <- knn_result$nn.dist[, k]
  
  cluster_ids   <- unique(labels[labels != -1L])
  max_core_dist <- sapply(cluster_ids, function(cid)
    max(core_dists[labels == cid]))
  
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