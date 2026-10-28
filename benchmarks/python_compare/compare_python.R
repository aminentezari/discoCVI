# compare_python.R — discoCVI (R) vs the original Python DISCO implementation
#
# For each dataset, both implementations run in their own process on the SAME
# data file. We compare (1) the per-point scores and (2) time and peak memory
# (maximum resident set size from /usr/bin/time -l).
#
# Run from the Mac Terminal, with nothing else running:
#   cd ~/Desktop/R-projects/discoCVI/benchmarks/python_compare
#   Rscript compare_python.R

py_repo <- path.expand("~/Desktop/Projects_python/DISCO-E358")
# a fresh Python environment with current numpy/scipy/scikit-learn (see README note below)
py_bin  <- path.expand("~/disco-py/bin/python")
here    <- normalizePath(".")
stopifnot(file.exists(py_bin), file.exists("disco_python_run.py"),
          file.exists("disco_r_run.R"))
dir.create("data", showWarnings = FALSE)
dir.create("scores", showWarnings = FALSE)

# ---- datasets ---------------------------------------------------------------
make_data <- function(n, seed, singleton = FALSE) {
  set.seed(seed)
  n_noise <- round(n * 0.05); n_cl <- n - n_noise
  centers <- matrix(c(0, 0,  6, 0,  3, 5), ncol = 2, byrow = TRUE)
  id <- sample(1:3, n_cl, replace = TRUE)
  X  <- rbind(centers[id, ] + matrix(rnorm(n_cl * 2), ncol = 2),
              matrix(runif(n_noise * 2, -4, 10), ncol = 2))
  lab <- c(id, rep(-1L, n_noise))
  if (singleton) lab[1] <- 99L                      # one singleton cluster
  data.frame(x1 = X[, 1], x2 = X[, 2], label = lab)
}

cases <- rbind(
  data.frame(name = "singleton_500", n = 500, seed = 7, singleton = TRUE),
  data.frame(name = paste0("blobs_", c(500, 1000, 2000, 4000, 8000)),
             n = c(500, 1000, 2000, 4000, 8000), seed = 1, singleton = FALSE))
for (i in seq_len(nrow(cases))) {
  write.csv(make_data(cases$n[i], cases$seed[i], cases$singleton[i]),
            file.path("data", paste0(cases$name[i], ".csv")),
            row.names = FALSE, quote = FALSE)
}

# ---- one measured run -------------------------------------------------------
field <- function(lines, key) {
  hit <- grep("^RESULT", lines, value = TRUE)
  if (!length(hit)) return(NA)
  m <- regmatches(hit[1], regexpr(paste0(key, "=[^ ]+"), hit[1]))
  if (!length(m)) NA else sub(paste0(key, "="), "", m)
}
run <- function(impl, name) {
  data_f  <- file.path(here, "data",   paste0(name, ".csv"))
  score_f <- file.path(here, "scores", paste0(name, "_", impl, ".csv"))
  cmd <- if (impl == "python") c(py_bin, "disco_python_run.py", py_repo, data_f, score_f)
         else                  c("Rscript", "disco_r_run.R", data_f, score_f)
  out <- suppressWarnings(system2("/usr/bin/time", c("-l", cmd),
                                  stdout = TRUE, stderr = TRUE))
  rss <- grep("maximum resident set size", out, value = TRUE)
  data.frame(impl = impl, case = name,
             sklearn_backend = if (impl == "python") field(out, "sklearn") else NA,
             disco_time_s = as.numeric(field(out, "disco_time_s")),
             peak_rss_MB  = if (length(rss)) as.numeric(sub("^\\s*([0-9]+).*", "\\1", rss[1])) / 1e6 else NA,
             score        = as.numeric(field(out, "score")),
             ok           = any(grepl("^RESULT", out)),
             stderr_tail  = if (any(grepl("^RESULT", out))) "" else
               substr(sub(".*\\|\\| ", "", c(grep("PYERROR", out, value = TRUE), out)[1]), 1, 200))
}

# ---- run: 3 replicates, alternating implementations -------------------------
res <- data.frame()
for (rep in 1:3) {
  for (name in cases$name) {
    for (impl in sample(c("python", "r"))) {
      r <- cbind(rep = rep, run(impl, name))
      res <- rbind(res, r)
      cat(sprintf("rep %d | %-6s | %-14s | %8.3f s | %6.0f MB | score %.10f %s\n",
                  rep, impl, name, r$disco_time_s, r$peak_rss_MB, r$score,
                  ifelse(r$ok, "", paste("FAILED:", r$stderr_tail))))
    }
  }
}
write.csv(res, "results_python_compare.csv", row.names = FALSE)

# ---- agreement of per-point scores -----------------------------------------
agree <- do.call(rbind, lapply(cases$name, function(name) {
  fp <- file.path("scores", paste0(name, "_python.csv"))
  r  <- read.csv(file.path("scores", paste0(name, "_r.csv")))$score
  if (!file.exists(fp)) return(data.frame(case = name, n = length(r), max_abs_diff = NA))
  py <- read.csv(fp)$score
  data.frame(case = name, n = length(r), max_abs_diff = max(abs(py - r)))
}))
print(agree)
write.csv(agree, "agreement_python_vs_r.csv", row.names = FALSE)

# ---- summary: median over replicates ----------------------------------------
summ <- aggregate(cbind(disco_time_s, peak_rss_MB) ~ impl + case, data = res, FUN = median)
print(summ[order(summ$case, summ$impl), ])
cat("Done -> results_python_compare.csv, agreement_python_vs_r.csv\n")
