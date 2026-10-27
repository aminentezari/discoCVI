# bench_one.R — one measured run, in its own R process.
# Usage: Rscript bench_one.R <version: old | new | baseline> <n> <seed>
#   old      = discoCVI 0.1.1 (installed in ~/R-lib-discoCVI-0.1.1)
#   new      = discoCVI 0.2.0 (installed in the normal library)
#   baseline = same data generation, no DISCO (R start-up + data cost)
# Labels are the generating labels (3 Gaussian blobs, 5% uniform noise = -1),
# so the measurement contains DISCO only, not the clustering.

args    <- commandArgs(trailingOnly = TRUE)
version <- args[1]
n       <- as.integer(args[2])
seed    <- as.integer(args[3])

lib_old <- path.expand("~/R-lib-discoCVI-0.1.1")
if (version == "old") suppressPackageStartupMessages(library(discoCVI, lib.loc = lib_old))
if (version == "new") suppressPackageStartupMessages(library(discoCVI))

set.seed(seed)
n_noise <- round(n * 0.05); n_cl <- n - n_noise
centers <- matrix(c(0, 0,  6, 0,  3, 5), ncol = 2, byrow = TRUE)
id      <- sample(1:3, n_cl, replace = TRUE)
X       <- rbind(centers[id, ] + matrix(rnorm(n_cl * 2), ncol = 2),
                 matrix(runif(n_noise * 2, -4, 10), ncol = 2))
labels  <- c(id, rep(-1L, n_noise))

if (version == "baseline") {
  s <- NA_real_; t <- 0
} else {
  t <- unname(system.time(s <- disco_score(X, labels))["elapsed"])
}
pkg <- if (version == "baseline") "none" else as.character(packageVersion("discoCVI"))
cat(sprintf("RESULT version=%s n=%d seed=%d pkg=%s score=%.15f disco_time_s=%.4f\n",
            version, n, seed, pkg, s, t))
