# Run discoCVI (installed version) on one dataset.
# Usage: Rscript disco_r_run.R <data.csv> <scores_out.csv>
# Prints: RESULT impl=r n=<n> score=<mean> disco_time_s=<seconds>

args <- commandArgs(trailingOnly = TRUE)
suppressPackageStartupMessages(library(discoCVI))

d      <- read.csv(args[1])
labels <- as.integer(d$label)
X      <- as.matrix(d[, setdiff(names(d), "label"), drop = FALSE])

t <- unname(system.time(s <- disco_samples(X, labels, min_points = 5))["elapsed"])
write.csv(data.frame(score = s), args[2], row.names = FALSE)
cat(sprintf("RESULT impl=r n=%d score=%.15f disco_time_s=%.4f pkg=%s\n",
            nrow(X), mean(s), t, as.character(packageVersion("discoCVI"))))
