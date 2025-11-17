#' DC-Distance (Density-Connectivity Distance) Computation
#'
#' Functions for computing density-connectivity distances between points
#' based on mutual reachability distance and minimum spanning tree.
#' 
#' @author Translated from Python implementation by Beer, Krieger, Weber, et al.

#' Compute core distances for all points
#'
#' @description
#' Core distance is the Euclidean distance to the k-th nearest neighbor.
#'
#' @param X A numeric matrix where rows are samples and columns are features
#' @param min_points Integer, number of nearest neighbors (k)
#' 
#' @return A numeric vector of core distances
#' 
#' @importFrom FNN get.knn
compute_core_distances <- function(X, min_points) {
  library(FNN)
  
  # Handle edge case
  if (min_points >= nrow(X)) {
    warning("min_points >= number of samples, using n-1")
    min_points <- nrow(X) - 1
  }
  
  if (min_points < 1) {
    stop("min_points must be at least 1")
  }
  
  # Find k nearest neighbors
  knn_result <- get.knn(X, k = min_points)
  
  # Core distance is distance to k-th nearest neighbor
  core_dists <- knn_result$nn.dist[, min_points]
  
  return(core_dists)
}


#' Compute mutual reachability distance matrix
#'
#' @description
#' Mutual reachability distance between points x and y is:
#' max(core_dist(x), core_dist(y), euclidean_dist(x, y))
#'
#' @param X A numeric matrix where rows are samples and columns are features
#' @param core_dists A numeric vector of core distances
#' 
#' @return A symmetric matrix of mutual reachability distances
compute_mutual_reachability_distance <- function(X, core_dists) {
  n <- nrow(X)
  
  # Compute pairwise Euclidean distances
  eucl_dists <- as.matrix(dist(X, method = "euclidean"))
  
  # Compute mutual reachability distance
  mrd <- matrix(0, n, n)
  
  for (i in 1:n) {
    for (j in 1:n) {
      if (i != j) {
        mrd[i, j] <- max(core_dists[i], core_dists[j], eucl_dists[i, j])
      }
    }
  }
  
  return(mrd)
}


#' Compute Minimum Spanning Tree using Prim's algorithm
#'
#' @param dist_matrix A symmetric distance matrix
#' 
#' @return An igraph MST object
#' @importFrom igraph graph_from_adjacency_matrix mst
compute_mst <- function(dist_matrix) {
  library(igraph)
  
  n <- nrow(dist_matrix)
  
  # Create graph from distance matrix
  g <- graph_from_adjacency_matrix(
    dist_matrix,
    mode = "undirected",
    weighted = TRUE,
    diag = FALSE
  )
  
  # Compute MST
  mst_graph <- mst(g, algorithm = "prim")
  
  return(mst_graph)
}


#' Extract DC-distances from MST
#'
#' @description
#' DC-distance is the minimax path distance in the MST (maximum edge weight 
#' along the unique path between two nodes).
#'
#' @param mst_graph An igraph MST object
#' @param n Number of nodes
#' 
#' @return A matrix of DC-distances
#' @importFrom igraph shortest_paths edge_attr
extract_dc_distances_from_mst <- function(mst_graph, n) {
  library(igraph)
  
  # Initialize DC-distance matrix
  dc_dists <- matrix(0, n, n)
  
  # For each pair of nodes, find the minimax path
  # This is done by finding the path in the MST and taking the maximum edge weight
  for (i in 1:n) {
    for (j in 1:n) {
      if (i != j) {
        # Get shortest path in MST (there's only one path in a tree)
        path <- shortest_paths(
          mst_graph, 
          from = i, 
          to = j, 
          output = "epath"
        )$epath[[1]]
        
        if (length(path) > 0) {
          # Get edge weights along the path
          edge_weights <- edge_attr(mst_graph, "weight", path)
          # DC-distance is the maximum edge weight on the path
          dc_dists[i, j] <- max(edge_weights)
        } else {
          # No path (shouldn't happen in MST)
          dc_dists[i, j] <- Inf
        }
      }
    }
  }
  
  return(dc_dists)
}


#' Compute DC-distances for all pairs of points
#'
#' @description
#' Main function to compute the density-connectivity distance matrix.
#' DC-distance is based on mutual reachability distance and computed
#' via minimum spanning tree.
#'
#' @param X A numeric matrix where rows are samples and columns are features
#' @param min_points Integer, minimum number of points for core distance. 
#'   Default is 5.
#' @param no_fastindex Logical, ignored for compatibility. Default is FALSE.
#' 
#' @return A symmetric matrix of DC-distances
#' 
#' @export
#' @examples
#' \dontrun{
#' # Generate sample data
#' X <- matrix(rnorm(100), ncol = 2)
#' 
#' # Compute DC-distances
#' dc_dists <- compute_dc_distances(X, min_points = 5)
#' 
#' # Check properties
#' dim(dc_dists)
#' isSymmetric(dc_dists)
#' }
compute_dc_distances <- function(X, min_points = 5, no_fastindex = FALSE) {
  # Convert to matrix if needed
  if (is.data.frame(X)) {
    X <- as.matrix(X)
  }
  
  n <- nrow(X)
  
  # Handle edge cases
  if (n == 0) {
    return(matrix(0, 0, 0))
  }
  
  if (n == 1) {
    return(matrix(0, 1, 1))
  }
  
  # Step 1: Compute core distances
  core_dists <- compute_core_distances(X, min_points)
  
  # Step 2: Compute mutual reachability distance matrix
  mrd <- compute_mutual_reachability_distance(X, core_dists)
  
  # Step 3: Compute MST
  mst_graph <- compute_mst(mrd)
  
  # Step 4: Extract DC-distances from MST
  dc_dists <- extract_dc_distances_from_mst(mst_graph, n)
  
  return(dc_dists)
}


#' DCTree class (for compatibility with Python implementation)
#' 
#' @description
#' This is a wrapper to maintain API compatibility with the Python version.
#' In practice, you can use compute_dc_distances() directly.
#' 
#' @param X A numeric matrix where rows are samples and columns are features
#' @param min_points Integer, minimum number of points. Default is 5.
#' @param no_fastindex Logical, ignored for compatibility. Default is FALSE.
#' 
#' @return A DCTree object (S3 class)
#' 
#' @export
#' @examples
#' \dontrun{
#' X <- matrix(rnorm(100), ncol = 2)
#' dctree <- DCTree(X, min_points = 5)
#' dc_dists <- dc_distances(dctree)
#' }
DCTree <- function(X, min_points = 5, no_fastindex = FALSE) {
  structure(
    list(
      X = X,
      min_points = min_points,
      no_fastindex = no_fastindex
    ),
    class = "DCTree"
  )
}


#' Compute DC distances for a DCTree object
#' 
#' @description
#' Generic method to compute DC-distances from a DCTree object.
#' 
#' @param dctree A DCTree object
#' @return A matrix of DC-distances
#' 
#' @export
dc_distances <- function(dctree) {
  UseMethod("dc_distances")
}


#' @export
dc_distances.DCTree <- function(dctree) {
  compute_dc_distances(
    dctree$X, 
    dctree$min_points, 
    dctree$no_fastindex
  )
}


#' Print method for DCTree objects
#' 
#' @param x A DCTree object
#' @param ... Additional arguments (ignored)
#' 
#' @export
print.DCTree <- function(x, ...) {
  cat("DCTree object\n")
  cat("  Samples:", nrow(x$X), "\n")
  cat("  Features:", ncol(x$X), "\n")
  cat("  min_points:", x$min_points, "\n")
  invisible(x)
}