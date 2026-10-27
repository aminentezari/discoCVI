# run_final_benchmark.R — discoCVI 0.1.1 vs 0.2.0: time, peak memory, energy.
#
# Every measurement is a separate Rscript process, so nothing leaks between runs.
#   Pass A: /usr/bin/time -l  -> wall time and TRUE peak memory of the process
#           (maximum resident set size, includes C++ allocations)
#   Pass B: CodeCarbon        -> energy (Wh) of the whole process
# A "baseline" run (R start-up + data generation, no DISCO) is measured too,
# so that the cost of DISCO itself = run - baseline.
#
# Run from the Mac Terminal (not RStudio), with nothing else running:
#   cd ~/Desktop/R-projects/discoCVI/benchmarks
#   Rscript run_final_benchmark.R

script     <- normalizePath("bench_one.R")
cc_wrapper <- path.expand(
  "~/Desktop/R-projects/green-computing/Green-computing-research/src/code_carbon_on_external_script.py")
stopifnot(file.exists(script), file.exists(cc_wrapper))

N_REPS <- 5
n_old  <- c(500, 1000, 2000, 4000)                         # 0.1.1 is infeasible beyond
n_new  <- c(500, 1000, 2000, 4000, 8000, 16000, 32000, 64000, 100000)

design <- rbind(
  expand.grid(version = "old",      n = n_old, stringsAsFactors = FALSE),
  expand.grid(version = "new",      n = n_new, stringsAsFactors = FALSE),
  expand.grid(version = "baseline", n = n_new, stringsAsFactors = FALSE))

out_path <- "results_final.csv"
cols <- c("rep", "version", "n", "seed", "pkg", "score", "disco_time_s",
          "wall_time_s", "peak_rss_MB", "energy_Wh", "cc_time_s")
write.csv(setNames(data.frame(matrix(nrow = 0, ncol = length(cols))), cols),
          out_path, row.names = FALSE)

field <- function(lines, key) {
  hit <- grep("^RESULT", lines, value = TRUE)
  if (!length(hit)) return(NA)
  m <- regmatches(hit[1], regexpr(paste0(key, "=[^ ]+"), hit[1]))
  if (!length(m)) NA else sub(paste0(key, "="), "", m)
}
cc_value <- function(lines, label) {
  hit <- grep(label, lines, fixed = TRUE, value = TRUE)
  if (!length(hit)) return(NA_real_)
  as.numeric(strsplit(trimws(sub(paste0(".*", label), "", hit[1])), " ")[[1]][1])
}

run_once <- function(version, n, seed) {
  args <- c(script, version, n, seed)
  # Pass A: time + peak memory
  a   <- suppressWarnings(system2("/usr/bin/time", c("-l", "Rscript", args),
                                  stdout = TRUE, stderr = TRUE))
  rss <- grep("maximum resident set size", a, value = TRUE)
  rss <- if (length(rss)) as.numeric(sub("^\\s*([0-9]+).*", "\\1", rss[1])) / 1e6 else NA
  real <- grep("\\breal\\b", a, value = TRUE)
  wall <- if (length(real)) as.numeric(sub("^\\s*([0-9.]+) real.*", "\\1", real[1])) else NA
  # Pass B: energy
  cmd <- paste("Rscript", script, version, n, seed)
  b   <- suppressWarnings(system2("python3", c(cc_wrapper, shQuote(cmd)),
                                  stdout = TRUE, stderr = FALSE))
  data.frame(version = version, n = n, seed = seed,
             pkg = field(a, "pkg"),
             score = as.numeric(field(a, "score")),
             disco_time_s = as.numeric(field(a, "disco_time_s")),
             wall_time_s = wall, peak_rss_MB = rss,
             energy_Wh = cc_value(b, "energy:"),
             cc_time_s = cc_value(b, "execution time:"))
}

# warm-up (not recorded)
invisible(run_once("new", 2000, 999)); invisible(run_once("old", 500, 999))

for (rep in seq_len(N_REPS)) {
  for (i in sample(nrow(design))) {               # random order within each replicate
    v <- design$version[i]; n <- design$n[i]
    r <- run_once(v, n, seed = n)                  # same data for old / new / baseline
    r <- cbind(rep = rep, r)
    write.table(r[, cols], out_path, sep = ",", append = TRUE,
                col.names = FALSE, row.names = FALSE)
    cat(sprintf("rep %d | %-8s | n = %6d | disco %.3f s | peak %.0f MB | %.5f Wh\n",
                rep, v, n, r$disco_time_s, r$peak_rss_MB, r$energy_Wh))
  }
}
cat("Done ->", out_path, "\n")
