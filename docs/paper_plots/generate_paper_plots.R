# =============================================================================
# Generate Publication-Quality Plots for Paper
# Clean white background, no grid, large points, bold colours
#
# Run: source("~/Desktop/R-projects/Disco-R/generate_paper_plots.R")
# =============================================================================

required_pkgs <- c("ggplot2", "gridExtra", "foreign", "MASS", "dbscan", "FNN")
for (p in required_pkgs) {
  if (!requireNamespace(p, quietly = TRUE))
    install.packages(p, repos = "https://cloud.r-project.org", quiet = TRUE)
}

setwd("~/Desktop/R-projects/Disco-R/R")
source("disco.R")

library(ggplot2)
library(gridExtra)

paper_dir <- "~/Desktop/R-projects/Disco-R/docs/paper_plots"
dir.create(path.expand(paper_dir), showWarnings = FALSE, recursive = TRUE)
base <- "~/Desktop/R-projects/Disco-R"

# =============================================================================
# THEME — pure white, no grid, clean axes
# =============================================================================

paper_theme <- theme_classic() +
  theme(
    plot.background    = element_rect(fill = "white", color = NA),
    panel.background   = element_rect(fill = "white", color = NA),
    panel.border       = element_rect(fill = NA, color = "#333333", linewidth = 0.7),
    panel.grid         = element_blank(),
    plot.title         = element_text(size = 14, face = "bold", hjust = 0.5,
                                      color = "#111111", margin = margin(b = 3)),
    plot.subtitle      = element_text(size = 10, hjust = 0.5, color = "#444444",
                                      margin = margin(b = 5)),
    legend.background  = element_rect(fill = "white", color = "#aaaaaa",
                                      linewidth = 0.4),
    legend.text        = element_text(size = 9, color = "#111111"),
    legend.title       = element_text(size = 10, face = "bold", color = "#111111"),
    legend.key         = element_rect(fill = "white", color = NA),
    legend.key.size    = unit(0.5, "cm"),
    axis.line          = element_blank(),
    axis.title         = element_blank(),
    axis.text          = element_blank(),
    axis.ticks         = element_blank(),
    plot.margin        = margin(10, 10, 10, 10)
  )

DISCO_GRAD <- scale_color_gradientn(
  colours = c("#b2182b","#ef8a62","#fddbc7","#f7f7f7","#d1e5f0","#4393c3","#2166ac"),
  limits  = c(-1, 1),
  name    = "DISCO\nscore",
  breaks  = c(-1, -0.5, 0, 0.5, 1),
  labels  = c("-1.0","-0.5","0.0","0.5","1.0")
)

# =============================================================================
# COLOUR PALETTES — vivid and distinguishable
# =============================================================================

PAL2  <- c("0"="#2196F3","1"="#FF6F00")
PAL3  <- c("0"="#2196F3","1"="#FF6F00","2"="#43A047")
PAL3D <- c("0"="#43A047","1"="#2196F3","2"="#FF6F00")
PAL4  <- c("0"="#2196F3","1"="#FF6F00","2"="#43A047","3"="#E53935")
PAL8  <- c("0"="#2196F3","1"="#FF6F00","2"="#43A047","3"="#E53935",
           "4"="#9C27B0","5"="#FF8F00","6"="#00BCD4","7"="#E91E63")
PAL9  <- c("0"="#2196F3","1"="#FF6F00","2"="#43A047","3"="#E53935",
           "4"="#9C27B0","5"="#FF8F00","6"="#00BCD4","7"="#E91E63","8"="#1565C0")

# =============================================================================
# HELPERS
# =============================================================================

load_or_compute <- function(csv_path, X, db_eps, db_minpts, km_k) {
  if (file.exists(csv_path)) {
    cat(sprintf("    loading -> %s\n", basename(dirname(csv_path))))
    sc <- read.csv(csv_path)
    list(scores_db=sc$disco_db, scores_km=sc$disco_km,
         db_labels=sc$db_label, km_labels=sc$km_label)
  } else {
    cat("    computing from scratch...\n")
    db_r      <- dbscan::dbscan(X, eps=db_eps, minPts=db_minpts)
    db_labels <- as.integer(db_r$cluster)
    db_labels[db_labels == 0L] <- -1L
    set.seed(42)
    km_labels <- as.integer(kmeans(X, centers=km_k,
                                   nstart=10, iter.max=300)$cluster) - 1L
    s_db <- disco_samples(X, db_labels, min_points=5)
    s_km <- disco_samples(X, km_labels, min_points=5)
    list(scores_db=s_db, scores_km=s_km,
         db_labels=db_labels, km_labels=km_labels)
  }
}

# Build the 3-panel plot for one dataset
make_trio <- function(X, y, res, title, n_label,
                      pal, lbl_map=NULL, pt_size=1.8,
                      dbscan_params="", km_params="") {
  
  df <- data.frame(
    x     = X[,1], y2 = X[,2],
    truth = factor(y),
    s_db  = res$scores_db,
    s_km  = res$scores_km
  )
  
  # Ground truth
  p1 <- ggplot(df, aes(x, y2, color=truth)) +
    geom_point(size=pt_size, alpha=0.9, stroke=0) +
    scale_color_manual(
      values = pal,
      labels = if (!is.null(lbl_map)) lbl_map else waiver(),
      name   = "Cluster"
    ) +
    labs(title    = title,
         subtitle = paste0("Ground Truth  |  n=", n_label)) +
    paper_theme +
    theme(legend.position  = "right",
          legend.spacing.y = unit(0.15, "cm"))
  
  # DISCO DBSCAN
  p2 <- ggplot(df, aes(x, y2, color=s_db)) +
    geom_point(size=pt_size, alpha=0.92, stroke=0) +
    DISCO_GRAD +
    labs(title    = "DISCO \u2014 DBSCAN",
         subtitle = paste0("mean = ", round(mean(res$scores_db), 4),
                           if (nchar(dbscan_params)>0)
                             paste0("  |  ", dbscan_params) else "")) +
    paper_theme + theme(legend.position="right")
  
  # DISCO K-Means
  p3 <- ggplot(df, aes(x, y2, color=s_km)) +
    geom_point(size=pt_size, alpha=0.92, stroke=0) +
    DISCO_GRAD +
    labs(title    = "DISCO \u2014 K-Means",
         subtitle = paste0("mean = ", round(mean(res$scores_km), 4),
                           if (nchar(km_params)>0)
                             paste0("  |  ", km_params) else "")) +
    paper_theme + theme(legend.position="right")
  
  list(p1=p1, p2=p2, p3=p3)
}

save_trio <- function(ps, name, w=15, h=5) {
  g   <- gridExtra::arrangeGrob(ps$p1, ps$p2, ps$p3, ncol=3)
  out <- file.path(path.expand(paper_dir), paste0(name, ".png"))
  ggsave(out, plot=g, width=w, height=h, dpi=220, bg="white")
  cat(sprintf("    saved  -> %s\n", basename(out)))
}

save_single <- function(p, name, w=5.5, h=4.5) {
  out <- file.path(path.expand(paper_dir), paste0(name, "_truth.png"))
  ggsave(out, plot=p, width=w, height=h, dpi=220, bg="white")
  cat(sprintf("    saved  -> %s\n", basename(out)))
}

cat("\n=== Generating paper plots ===\n\n")

# =============================================================================
# 1. CONCENTRIC CIRCLES
# =============================================================================
cat("1. Concentric Circles\n")

set.seed(42)
n_c <- 150
a1  <- runif(n_c,0,2*pi); a2 <- runif(n_c,0,2*pi)
X   <- rbind(cbind(cos(a1),sin(a1)), cbind(0.4*cos(a2),0.4*sin(a2)))
X   <- X + matrix(rnorm(nrow(X)*2,sd=0.05),ncol=2)
y   <- c(rep(0L,n_c),rep(1L,n_c))

csv1 <- file.path(path.expand(base),"experiments/sklearn-circle/disco_scores_full.csv")
csv2 <- file.path(path.expand(base),"experiments/circles/disco_scores_full.csv")
csv  <- if (file.exists(csv1)) csv1 else csv2

res <- load_or_compute(csv, X, 0.2, 5, 2)
ps  <- make_trio(X, y, res, "Concentric Circles", "300", PAL2,
                 c("0"="Outer ring","1"="Inner ring"),
                 pt_size=2.2, dbscan_params="eps=0.2", km_params="k=2")
save_trio(ps, "01_circles")
save_single(ps$p1, "01_circles")

# =============================================================================
# 2. TWO MOONS
# =============================================================================
cat("2. Two Moons\n")

set.seed(42)
n_m <- 500
t   <- seq(0, pi, length.out=n_m)
X   <- rbind(cbind(cos(t),sin(t)), cbind(1-cos(t),1-sin(t)-0.5))
X   <- X + matrix(rnorm(nrow(X)*2,sd=0.05),ncol=2)
y   <- c(rep(0L,n_m),rep(1L,n_m))

csv <- file.path(path.expand(base),"experiments/moons/disco_scores_full.csv")
res <- load_or_compute(csv, X, 0.2, 5, 2)
ps  <- make_trio(X, y, res, "Two Moons", "1000", PAL2,
                 c("0"="Moon 1","1"="Moon 2"),
                 pt_size=1.6, dbscan_params="eps=0.2", km_params="k=2")
save_trio(ps, "02_moons")
save_single(ps$p1, "02_moons")

# =============================================================================
# 3. 3-SPIRAL
# =============================================================================
cat("3. 3-Spiral\n")

raw <- foreign::read.arff(path.expand(file.path(base,"data/3-spiral.arff")))
X   <- as.matrix(raw[,c("x","y")])
y   <- as.integer(as.character(raw$class)) - 1L

csv <- file.path(path.expand(base),"experiments/spiral3/disco_scores_full.csv")
res <- load_or_compute(csv, X, 2, 3, 3)
ps  <- make_trio(X, y, res, "3-Spiral", "312", PAL3,
                 c("0"="Spiral 1","1"="Spiral 2","2"="Spiral 3"),
                 pt_size=2.5, dbscan_params="eps=2.0", km_params="k=3")
save_trio(ps, "03_spiral3")
save_single(ps$p1, "03_spiral3")

# =============================================================================
# 4. COMPLEX9
# =============================================================================
cat("4. Complex9\n")

raw <- foreign::read.arff(path.expand(file.path(base,"data/complex9.arff")))
X   <- as.matrix(raw[,c("x","y")])
y   <- as.integer(as.character(raw$class))

csv <- file.path(path.expand(base),"experiments/complex9/disco_scores_full.csv")
res <- load_or_compute(csv, X, 15, 5, 9)
ps  <- make_trio(X, y, res, "Complex9", "3031", PAL9,
                 pt_size=1.2, dbscan_params="eps=15", km_params="k=9")
save_trio(ps, "04_complex9", w=16, h=5)
save_single(ps$p1, "04_complex9")

# =============================================================================
# 5. COMPLEX8
# =============================================================================
cat("5. Complex8\n")

raw <- foreign::read.arff(path.expand(file.path(base,"data/complex8.arff")))
X   <- as.matrix(raw[,c("x","y")])
y   <- as.integer(as.character(raw$class))

csv <- file.path(path.expand(base),"experiments/complex8/disco_scores_full.csv")
res <- load_or_compute(csv, X, 10, 5, 8)
ps  <- make_trio(X, y, res, "Complex8", "2551", PAL8,
                 pt_size=1.2, dbscan_params="eps=10", km_params="k=8")
save_trio(ps, "05_complex8", w=16, h=5)
save_single(ps$p1, "05_complex8")

# =============================================================================
# 6. DARTBOARD1
# =============================================================================
cat("6. Dartboard1\n")

raw <- foreign::read.arff(path.expand(file.path(base,"data/dartboard1.arff")))
X   <- as.matrix(raw[,c("a0","a1")])
y   <- as.integer(as.character(raw$class))

csv <- file.path(path.expand(base),"experiments/dartboard1/disco_scores_full.csv")
res <- load_or_compute(csv, X, 0.08, 5, 4)
ps  <- make_trio(X, y, res, "Dartboard1", "1000", PAL4,
                 c("0"="Ring 1","1"="Ring 2","2"="Ring 3","3"="Ring 4"),
                 pt_size=2.0, dbscan_params="eps=0.08", km_params="k=4")
save_trio(ps, "06_dartboard1")
save_single(ps$p1, "06_dartboard1")

# =============================================================================
# 7. BLOBS
# =============================================================================
cat("7. Blobs\n")

set.seed(42)
sigma   <- diag(2)*0.55^2
centres <- list(c(1.5,7.0),c(6.5,7.0),c(4.0,2.5))
X       <- do.call(rbind,lapply(centres,function(mu)
  MASS::mvrnorm(n=150,mu=mu,Sigma=sigma)))
y       <- rep(0:2,each=150)

csv <- file.path(path.expand(base),"experiments/blobs/disco_scores_full.csv")
res <- load_or_compute(csv, X, 0.5, 5, 3)
ps  <- make_trio(X, y, res, "Blobs", "450", PAL3,
                 c("0"="Top-left","1"="Top-right","2"="Bottom"),
                 pt_size=2.2, dbscan_params="eps=0.5", km_params="k=3")
save_trio(ps, "07_blobs")
save_single(ps$p1, "07_blobs")

# =============================================================================
# 8. DIAGONAL BLOBS
# =============================================================================
cat("8. Diagonal Blobs\n")

set.seed(42)
sigma   <- matrix(c(1.2,-1.0,-1.0,1.2),nrow=2)
centres <- list(c(2.5,5.0),c(0.5,1.8),c(-1.5,-1.5))
X       <- do.call(rbind,lapply(centres,function(mu)
  MASS::mvrnorm(n=200,mu=mu,Sigma=sigma)))
y       <- rep(0:2,each=200)

csv <- file.path(path.expand(base),"experiments/diagonal_blobs/disco_scores_full.csv")
res <- load_or_compute(csv, X, 0.8, 5, 3)
ps  <- make_trio(X, y, res, "Diagonal Blobs", "600", PAL3D,
                 c("0"="Top","1"="Middle","2"="Bottom"),
                 pt_size=1.8, dbscan_params="eps=0.8", km_params="k=3")
save_trio(ps, "08_diagonal_blobs")
save_single(ps$p1, "08_diagonal_blobs")

# =============================================================================
cat("\n=== All done! ===\n")
cat(sprintf("Plots saved to:\n  %s\n\n", path.expand(paper_dir)))
cat("Files per dataset:\n")
cat("  XX_name.png        <- 3-panel (truth + DISCO DBSCAN + DISCO KMeans)\n")
cat("  XX_name_truth.png  <- ground truth only\n")