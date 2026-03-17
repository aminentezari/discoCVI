#' Utility Functions for DISCO Package
#' 
#' Helper functions for data generation, visualization, and validation.

#' Generate two moons dataset
#' 
#' @description
#' Creates a synthetic dataset with two interleaving half circles.
#' Useful for testing density-based clustering algorithms.
#' 
#' @param n_samples Integer, number of samples to generate (divided between two moons)
#' @param noise Numeric, standard deviation of Gaussian noise. Default is 0.05.
#' @param random_state Integer, random seed for reproducibility. Default is NULL.
#' 
#' @return A list with two components:
#'   \item{X}{A matrix with two columns (x, y coordinates)}
#'   \item{labels}{A vector of cluster labels (0 or 1)}
#' 
#' @export
#' @examples
#' \dontrun{
#' # Generate data
#' data <- make_moons(n_samples = 300, noise = 0.05)
#' plot(data$X, col = data$labels + 1, pch = 19)
#' 
#' # Apply clustering
#' library(dbscan)
#' db <- dbscan(data$X, eps = 0.2, minPts = 5)
#' score <- disco_score(data$X, db$cluster - 1)
#' }
make_moons <- function(n_samples = 100, noise = 0.05, random_state = NULL) {
  if (!is.null(random_state)) {
    set.seed(random_state)
  }
  
  n_samples_per_moon <- floor(n_samples / 2)
  
  # Generate outer moon
  outer_circ_x <- cos(seq(0, pi, length.out = n_samples_per_moon))
  outer_circ_y <- sin(seq(0, pi, length.out = n_samples_per_moon))
  
  # Generate inner moon
  inner_circ_x <- 1 - cos(seq(0, pi, length.out = n_samples_per_moon))
  inner_circ_y <- 1 - sin(seq(0, pi, length.out = n_samples_per_moon)) - 0.5
  
  # Combine
  X <- rbind(
    cbind(outer_circ_x, outer_circ_y),
    cbind(inner_circ_x, inner_circ_y)
  )
  
  # Add noise
  if (noise > 0) {
    X <- X + matrix(rnorm(nrow(X) * 2, sd = noise), ncol = 2)
  }
  
  # Create labels
  labels <- c(rep(0, n_samples_per_moon), rep(1, n_samples_per_moon))
  
  return(list(X = X, labels = labels))
}


#' Generate circles dataset
#' 
#' @description
#' Creates a synthetic dataset with concentric circles.
#' Useful for testing clustering algorithms on non-convex shapes.
#' 
#' @param n_samples Integer, number of samples to generate
#' @param noise Numeric, standard deviation of Gaussian noise. Default is 0.05.
#' @param factor Numeric, scaling factor between inner and outer circle. 
#'   Default is 0.5.
#' @param random_state Integer, random seed for reproducibility. Default is NULL.
#' 
#' @return A list with two components:
#'   \item{X}{A matrix with two columns (x, y coordinates)}
#'   \item{labels}{A vector of cluster labels (0 or 1)}
#' 
#' @export
#' @examples
#' \dontrun{
#' data <- make_circles(n_samples = 300, noise = 0.05, factor = 0.3)
#' plot(data$X, col = data$labels + 1, pch = 19)
#' }
make_circles <- function(n_samples = 100, noise = 0.05, factor = 0.5, 
                         random_state = NULL) {
  if (!is.null(random_state)) {
    set.seed(random_state)
  }
  
  n_samples_per_circle <- floor(n_samples / 2)
  
  # Generate outer circle
  angles_outer <- runif(n_samples_per_circle, 0, 2 * pi)
  outer_x <- cos(angles_outer)
  outer_y <- sin(angles_outer)
  
  # Generate inner circle
  angles_inner <- runif(n_samples_per_circle, 0, 2 * pi)
  inner_x <- factor * cos(angles_inner)
  inner_y <- factor * sin(angles_inner)
  
  # Combine
  X <- rbind(
    cbind(outer_x, outer_y),
    cbind(inner_x, inner_y)
  )
  
  # Add noise
  if (noise > 0) {
    X <- X + matrix(rnorm(nrow(X) * 2, sd = noise), ncol = 2)
  }
  
  # Create labels
  labels <- c(rep(0, n_samples_per_circle), rep(1, n_samples_per_circle))
  
  return(list(X = X, labels = labels))
}


#' Plot DISCO scores
#' 
#' @description
#' Visualize pointwise DISCO scores with color coding.
#' 
#' @param X A numeric matrix with 2 columns for plotting
#' @param labels Integer vector of cluster labels
#' @param scores Optional numeric vector of DISCO scores to color points
#' @param main Character, plot title. Default is "DISCO Scores".
#' @param ... Additional arguments passed to plot()
#' 
#' @export
#' @importFrom grDevices colorRampPalette
#' 
#' @examples
#' \dontrun{
#' data <- make_moons(n_samples = 200)
#' scores <- disco_samples(data$X, data$labels)
#' plot_disco_scores(data$X, data$labels, scores)
#' }
plot_disco_scores <- function(X, labels, scores = NULL, main = "DISCO Scores", ...) {
  if (is.null(scores)) {
    # Just plot by cluster
    plot(X[, 1], X[, 2], 
         col = labels + 2,  # Offset to avoid white
         pch = ifelse(labels == -1, 4, 19),  # X for noise, circle for clusters
         main = main,
         xlab = "Feature 1", ylab = "Feature 2",
         ...)
    
    # Add legend
    unique_labels <- unique(labels)
    cluster_labels <- unique_labels[unique_labels != -1]
    if (-1 %in% unique_labels) {
      legend("topright", 
             legend = c("Noise", paste("Cluster", cluster_labels)),
             pch = c(4, rep(19, length(cluster_labels))),
             col = c(1, cluster_labels + 2),
             cex = 0.8)
    } else {
      legend("topright", 
             legend = paste("Cluster", cluster_labels),
             pch = 19,
             col = cluster_labels + 2,
             cex = 0.8)
    }
  } else {
    # Color by score
    colors <- colorRampPalette(c("red", "yellow", "green"))(100)
    score_colors <- colors[cut(scores, breaks = 100, labels = FALSE)]
    score_colors[is.na(score_colors)] <- "gray"
    
    plot(X[, 1], X[, 2], 
         col = score_colors,
         pch = ifelse(labels == -1, 4, 19),
         main = main,
         xlab = "Feature 1", ylab = "Feature 2",
         ...)
    
    # Add color legend
    legend_scores <- seq(-1, 1, length.out = 5)
    legend_colors <- colors[cut(legend_scores, breaks = 100, labels = FALSE)]
    legend("topright",
           legend = sprintf("%.2f", legend_scores),
           fill = legend_colors,
           title = "DISCO Score",
           cex = 0.8)
  }
}


#' Compare multiple clusterings
#' 
#' @description
#' Compute DISCO scores for multiple clustering results and rank them.
#' 
#' @param X A numeric matrix of features
#' @param clustering_list Named list of label vectors
#' @param min_points Integer, parameter for DISCO. Default is 5.
#' 
#' @return A data frame with clustering names and their DISCO scores,
#'   sorted by score (best first)
#' 
#' @export
#' @examples
#' \dontrun{
#' library(dbscan)
#' data <- make_moons(n_samples = 300)
#' X <- data$X
#' 
#' # Apply different algorithms
#' db <- dbscan(X, eps = 0.2, minPts = 5)
#' km <- kmeans(X, centers = 2)
#' 
#' # Compare
#' clusterings <- list(
#'   DBSCAN = db$cluster - 1,
#'   KMeans = km$cluster - 1
#' )
#' results <- compare_clusterings(X, clusterings)
#' print(results)
#' }
compare_clusterings <- function(X, clustering_list, min_points = 5) {
  scores <- sapply(clustering_list, function(labels) {
    disco_score(X, labels, min_points)
  })
  
  result <- data.frame(
    Clustering = names(clustering_list),
    DISCO_Score = scores,
    stringsAsFactors = FALSE
  )
  
  result <- result[order(-result$DISCO_Score), ]
  rownames(result) <- NULL
  
  return(result)
}


#' Validate DISCO input
#' 
#' @description
#' Check if inputs to DISCO functions are valid.
#' 
#' @param X Data matrix
#' @param labels Label vector
#' @param min_points Minimum points parameter
#' 
#' @return TRUE if valid, otherwise stops with error
#' 
#' @keywords internal
validate_disco_input <- function(X, labels, min_points) {
  if (!is.matrix(X) && !is.data.frame(X)) {
    stop("X must be a matrix or data frame")
  }
  
  if (!is.numeric(labels)) {
    stop("labels must be numeric")
  }
  
  if (nrow(X) != length(labels)) {
    stop("Number of samples in X must match length of labels")
  }
  
  if (min_points < 1) {
    stop("min_points must be at least 1")
  }
  
  if (min_points >= nrow(X)) {
    warning("min_points should be less than number of samples")
  }
  
  return(TRUE)
}


#' Summary statistics for DISCO scores
#' 
#' @description
#' Compute summary statistics for pointwise DISCO scores.
#' 
#' @param scores Numeric vector of DISCO scores
#' 
#' @return A list with summary statistics
#' 
#' @export
#' @examples
#' \dontrun{
#' data <- make_moons(n_samples = 200)
#' scores <- disco_samples(data$X, data$labels)
#' summary_disco_scores(scores)
#' }
summary_disco_scores <- function(scores) {
  list(
    mean = mean(scores),
    median = median(scores),
    min = min(scores),
    max = max(scores),
    sd = sd(scores),
    q25 = quantile(scores, 0.25),
    q75 = quantile(scores, 0.75),
    n_negative = sum(scores < 0),
    n_positive = sum(scores > 0),
    n_near_zero = sum(abs(scores) < 0.1)
  )
}