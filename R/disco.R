#' @keywords internal
"_PACKAGE"

# Main DISCO Functions --------------------------------------------------------

#' Compute the mean DISCO score of all samples
#'
#' @description
#' The DISCO score measures how well samples are clustered with similar samples.
#' It evaluates both cluster quality (compactness and separation) and noise 
#' label quality (sparseness and remoteness from clusters).
#'
#' @param X A numeric matrix or data.frame where rows are samples and columns 
#'   are features.
#' @param labels Integer vector of cluster labels. Use -1 for noise points.
#' @param min_points Integer, minimum number of points for dc-distance 
#'   calculation. Default is 5.
#' 
#' @return A numeric value between -1 and 1. Higher values indicate better 
#'   clustering. The best value is 1, the worst is -1. Values near 0 indicate 
#'   overlapping clusters.
#' 
#' @details
#' DISCO evaluates clustering using density-connectivity distance (dc-distance).
#' For cluster points, it computes a silhouette-like score. For noise points,
#' it evaluates whether they are in sparse regions (p_sparse) and far from 
#' clusters (p_far).
#' 
#' @export
#' @examples
#' \dontrun{
#' # Generate synthetic data
#' library(dbscan)
#' data <- make_moons(n_samples = 300, noise = 0.05)
#' X <- data$X
#' 
#' # Apply DBSCAN
#' db <- dbscan(X, eps = 0.2, minPts = 5)
#' labels <- db$cluster - 1
#' labels[labels == 0] <- -1  # Convert 0 to -1 for noise
#' 
#' # Calculate DISCO score
#' score <- disco_score(X, labels)
#' print(score)
#' }
#' 
#' @seealso \code{\link{disco_samples}}, \code{\link{p_cluster}}, \code{\link{p_noise}}
disco_score <- function(X, labels, min_points = 5) {
  sample_scores <- disco_samples(X, labels, min_points)
  return(mean(sample_scores))
}


#' Compute the DISCO score for each sample
#'
#' @description
#' Returns pointwise DISCO scores, allowing identification of problematic 
#' samples in the clustering.
#'
#' @param X A numeric matrix or data.frame where rows are samples and columns 
#'   are features.
#' @param labels Integer vector of cluster labels. Use -1 for noise points.
#' @param min_points Integer, minimum number of points for dc-distance 
#'   calculation. Default is 5.
#' 
#' @return A numeric vector of DISCO scores, one for each sample, with values 
#'   between -1 and 1.
#' 
#' @export
#' @examples
#' \dontrun{
#' data <- make_moons(n_samples = 200, noise = 0.05)
#' X <- data$X
#' labels <- data$labels
#' 
#' # Get pointwise scores
#' scores <- disco_samples(X, labels, min_points = 5)
#' 
#' # Identify problematic points
#' problematic <- which(scores < 0.3)
#' }
#' 
#' @seealso \code{\link{disco_score}}
disco_samples <- function(X, labels, min_points = 5) {
  # Convert to matrix if needed
  if (is.data.frame(X)) {
    X <- as.matrix(X)
  }
  
  # Basic validation
  if (nrow(X) == 0) {
    stop("Can't calculate DISCO score for empty dataset.")
  }
  if (nrow(X) != length(labels)) {
    stop("Dataset size differs from label size.")
  }
  
  # Reshape labels to vector
  labels <- as.vector(labels)
  label_set <- unique(labels)
  
  # Case 1: Only noise
  if (length(label_set) == 1 && label_set[1] == -1) {
    return(rep(-1, nrow(X)))
  }
  
  # Case 2: One cluster without noise
  if (length(label_set) == 1 && label_set[1] != -1) {
    return(rep(0, nrow(X)))
  }
  
  # Compute dc-distances
  dc_dists <- compute_dc_distances(X, min_points)
  
  # Initialize result vector
  disco_values <- numeric(nrow(X))
  
  # Case 3: One cluster with noise
  if (length(label_set) == 2 && -1 %in% label_set) {
    # Create temporary labels where each noise point gets unique label
    l_temp <- labels
    noise_mask <- labels == -1
    n_noise <- sum(noise_mask)
    if (n_noise > 0) {
      l_temp[noise_mask] <- seq(-1, -n_noise, by = -1)
    }
    
    # Compute cluster scores
    cluster_scores <- p_cluster(dc_dists, l_temp, precomputed_dc_dists = TRUE)
    disco_values[!noise_mask] <- cluster_scores[!noise_mask]
    
    # Compute noise scores
    noise_results <- p_noise(X, labels, min_points, dc_dists)
    disco_values[noise_mask] <- pmin(noise_results$p_sparse, noise_results$p_far)
    
    return(disco_values)
  }
  
  # Case 4: More than one cluster with optional noise
  non_noise_mask <- labels != -1
  non_noise_dc_dists <- dc_dists[non_noise_mask, non_noise_mask, drop = FALSE]
  non_noise_labels <- labels[non_noise_mask]
  
  # Compute scores for non-noise points
  disco_values[non_noise_mask] <- p_cluster(
    non_noise_dc_dists, 
    non_noise_labels, 
    precomputed_dc_dists = TRUE
  )
  
  # Compute scores for noise points
  if (any(!non_noise_mask)) {
    noise_results <- p_noise(X, labels, min_points, dc_dists)
    disco_values[!non_noise_mask] <- pmin(noise_results$p_sparse, noise_results$p_far)
  }
  
  return(disco_values)
}


#' Compute p_cluster score for cluster points
#'
#' @description
#' p_cluster is similar to the Silhouette Coefficient but uses dc-distance metric.
#' It evaluates cluster compactness and separation.
#' 
#' Note: -1 is NOT handled as noise here, but as a valid cluster label!
#'
#' @param X Either a numeric matrix/data.frame of features, or a distance matrix 
#'   if precomputed_dc_dists=TRUE
#' @param labels Integer vector of cluster labels
#' @param min_points Integer, minimum number of points for dc-distance. Default is 5.
#' @param precomputed_dc_dists Logical, whether X is already a dc-distance matrix. 
#'   Default is FALSE.
#' 
#' @return A numeric vector of p_cluster scores for each sample
#' 
#' @export
p_cluster <- function(X, labels, min_points = 5, precomputed_dc_dists = FALSE) {
  if (length(X) == 0 || (is.matrix(X) && nrow(X) == 0)) {
    return(numeric(0))
  }
  
  if (!is.matrix(X)) {
    X <- as.matrix(X)
  }
  
  if (nrow(X) != length(labels)) {
    stop("Dataset size of `X` differs from label size of `labels`.")
  }
  
  if (nrow(X) == 1) {
    return(0)
  }
  
  # Get unique labels
  unique_labels <- unique(labels)
  n_labels <- length(unique_labels)
  
  # Edge cases
  if (n_labels == 1 || n_labels == nrow(X)) {
    return(rep(0, nrow(X)))
  }
  
  # Get or compute dc-distances
  if (precomputed_dc_dists) {
    if (ncol(X) != nrow(X)) {
      stop("`X` needs to be a distance matrix if `precomputed_dc_dists` is TRUE.")
    }
    dc_dists <- X
  } else {
    dc_dists <- compute_dc_distances(X, min_points)
  }
  
  # Compute silhouette-like scores on dc-distances
  scores <- numeric(nrow(X))
  
  for (i in 1:nrow(X)) {
    current_label <- labels[i]
    same_cluster <- labels == current_label
    
    # Intra-cluster distance (a)
    if (sum(same_cluster) > 1) {
      a <- mean(dc_dists[i, same_cluster & (1:length(labels) != i)])
    } else {
      a <- 0
    }
    
    # Inter-cluster distance (b) - minimum over other clusters
    other_labels <- unique_labels[unique_labels != current_label]
    b <- Inf
    
    for (other_label in other_labels) {
      other_cluster <- labels == other_label
      if (sum(other_cluster) > 0) {
        b_temp <- mean(dc_dists[i, other_cluster])
        b <- min(b, b_temp)
      }
    }
    
    # Compute score
    if (is.finite(b)) {
      scores[i] <- (b - a) / max(a, b)
    } else {
      scores[i] <- 0
    }
  }
  
  return(scores)
}


#' Compute (p_sparse, p_far) for noise points
#'
#' @description
#' Evaluates quality of noise labels by checking if points are in sparse regions
#' (p_sparse) and far from clusters (p_far).
#'
#' @param X A numeric matrix or data.frame where rows are samples and columns 
#'   are features
#' @param labels Integer vector of cluster labels. -1 indicates noise.
#' @param min_points Integer, minimum number of points for dc-distance. Default is 5.
#' @param dc_dists Optional precomputed dc-distance matrix
#' 
#' @return A list with two components:
#'   \item{p_sparse}{Numeric vector of p_sparse scores for noise points}
#'   \item{p_far}{Numeric vector of p_far scores for noise points}
#' 
#' @export
p_noise <- function(X, labels, min_points = 5, dc_dists = NULL) {
  # Convert to matrix if needed
  if (is.data.frame(X)) {
    X <- as.matrix(X)
  }
  
  # Basic validation
  if (nrow(X) == 0) {
    stop("Can't calculate noise score for empty dataset.")
  }
  if (nrow(X) != length(labels)) {
    stop("Dataset size differs from label size.")
  }
  
  label_set <- unique(labels)
  
  # Case 1: Only noise
  if (length(label_set) == 1 && label_set[1] == -1) {
    n <- nrow(X)
    return(list(p_sparse = rep(-1, n), p_far = rep(-1, n)))
  }
  
  # Case 2: No noise
  if (!(-1 %in% label_set)) {
    return(list(p_sparse = numeric(0), p_far = numeric(0)))
  }
  
  # At least one cluster and noise
  if (is.null(dc_dists)) {
    dc_dists <- compute_dc_distances(X, min_points)
  }
  
  # Compute core distances using k-NN
  library(FNN)
  knn_result <- get.knn(X, k = min_points)
  core_dists <- knn_result$nn.dist[, min_points]
  
  # Get cluster IDs (excluding noise)
  cluster_ids <- unique(labels[labels != -1])
  noise_mask <- labels == -1
  n_noise <- sum(noise_mask)
  
  # Get maximum core distance per cluster
  max_core_dist <- numeric(length(cluster_ids))
  for (i in seq_along(cluster_ids)) {
    cluster_mask <- labels == cluster_ids[i]
    max_core_dist[i] <- max(core_dists[cluster_mask])
  }
  
  # Initialize scores
  p_sparse <- rep(Inf, n_noise)
  p_far <- rep(Inf, n_noise)
  
  # Get indices of noise points
  noise_indices <- which(noise_mask)
  
  # Compute p_sparse
  for (i in seq_along(cluster_ids)) {
    numerator <- core_dists[noise_mask] - max_core_dist[i]
    denominator <- pmax(core_dists[noise_mask], max_core_dist[i])
    
    p_sparse_i <- ifelse(denominator != 0, numerator / denominator, 0)
    p_sparse <- pmin(p_sparse, p_sparse_i)
  }
  
  # Compute p_far
  for (i in seq_along(cluster_ids)) {
    cluster_mask <- labels == cluster_ids[i]
    cluster_indices <- which(cluster_mask)
    
    # Minimum dc-distance from each noise point to this cluster
    min_dist_to_cluster <- apply(
      dc_dists[noise_indices, cluster_indices, drop = FALSE], 
      1, 
      min
    )
    
    numerator <- min_dist_to_cluster - max_core_dist[i]
    denominator <- pmax(min_dist_to_cluster, max_core_dist[i])
    
    p_far_i <- ifelse(denominator != 0, numerator / denominator, 0)
    p_far <- pmin(p_far, p_far_i)
  }
  
  return(list(p_sparse = p_sparse, p_far = p_far))
}