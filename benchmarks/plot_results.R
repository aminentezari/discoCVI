# plot_results.R — publication figures from results_final.csv
# Red = discoCVI 0.1.1, blue = discoCVI 0.2.0.
# Points = median of 5 runs, bars = range (min to max).
# Writes PNG (300 dpi) and PDF to benchmarks/figures/ and paper/figures/.
#
# Run in RStudio:
#   setwd("~/Desktop/R-projects/discoCVI/benchmarks")
#   source("plot_results.R")

library(ggplot2)

res <- read.csv("results_final.csv")

# ---- baseline (R start-up + data generation, no DISCO) --------------------
base <- aggregate(cbind(energy_Wh, peak_rss_MB) ~ n,
                  data = subset(res, version == "baseline"), FUN = median)
names(base) <- c("n", "base_energy_Wh", "base_rss_MB")
r_itself_MB <- median(base$base_rss_MB)

# ---- summaries per version and n -----------------------------------------
d <- merge(subset(res, version != "baseline"), base, by = "n")
d$energy_mWh <- (d$energy_Wh - d$base_energy_Wh) * 1000

summ <- do.call(rbind, lapply(split(d, list(d$version, d$n), drop = TRUE), function(g) {
  data.frame(version   = g$version[1], n = g$n[1],
             time      = median(g$disco_time_s),
             time_lo   = min(g$disco_time_s),  time_hi   = max(g$disco_time_s),
             mem       = median(g$peak_rss_MB),
             mem_lo    = min(g$peak_rss_MB),   mem_hi    = max(g$peak_rss_MB),
             energy    = median(g$energy_mWh),
             energy_lo = min(g$energy_mWh),    energy_hi = max(g$energy_mWh))
}))
summ <- summ[order(summ$version, summ$n), ]
# very short runs can give a tiny negative energy after the baseline is
# subtracted; keep them positive so they can be shown on a log scale
summ$energy_lo <- pmax(summ$energy_lo, summ$energy / 10)

summ$version <- factor(summ$version, levels = c("old", "new"),
                       labels = c("discoCVI 0.1.1", "discoCVI 0.2.0"))
cols <- c("discoCVI 0.1.1" = "#D62728",   # red
          "discoCVI 0.2.0" = "#1F4E9E")   # blue

# ---- shared style --------------------------------------------------------
plain_num <- function(x) format(x, big.mark = ",", scientific = FALSE,
                                drop0trailing = TRUE, trim = TRUE)
x_breaks  <- c(500, 1000, 2000, 4000, 8000, 16000, 32000, 64000, 100000)

theme_pub <- theme_bw(base_size = 12) +
  theme(panel.grid.minor  = element_blank(),
        panel.grid.major  = element_line(colour = "grey90"),
        legend.position   = "top",
        legend.text       = element_text(size = 11),
        axis.text.x       = element_text(angle = 45, hjust = 1),
        plot.margin       = margin(8, 12, 8, 8))

base_plot <- function(y, lo, hi, ylab) {
  ggplot(summ, aes(x = n, y = .data[[y]], colour = version)) +
    geom_errorbar(aes(ymin = .data[[lo]], ymax = .data[[hi]]),
                  width = 0.05, linewidth = 0.5) +
    geom_line(linewidth = 1.1) +
    geom_point(size = 2.6) +
    scale_x_log10(breaks = x_breaks, labels = plain_num) +
    scale_y_log10(labels = plain_num) +
    scale_colour_manual(values = cols, name = NULL) +
    labs(x = "Number of points (n)", y = ylab) +
    theme_pub
}

save_both <- function(p, name) {
  for (dir in c("figures", "../paper/figures")) {
    dir.create(dir, showWarnings = FALSE, recursive = TRUE)
    ggsave(file.path(dir, paste0(name, ".png")), p, width = 6.5, height = 4.5,
           dpi = 300, bg = "white")
    ggsave(file.path(dir, paste0(name, ".pdf")), p, width = 6.5, height = 4.5)
  }
}

# ---- 1. time --------------------------------------------------------------
n_common <- max(summ$n[summ$version == "discoCVI 0.1.1"])
t_old    <- summ$time[summ$version == "discoCVI 0.1.1" & summ$n == n_common]
t_new    <- summ$time[summ$version == "discoCVI 0.2.0" & summ$n == n_common]

p_time <- base_plot("time", "time_lo", "time_hi", "DISCO computation time (seconds)") +
  annotate("segment", x = n_common, xend = n_common, y = t_new * 1.25, yend = t_old / 1.25,
           colour = "grey35", linewidth = 0.5,
           arrow = arrow(ends = "both", length = unit(0.12, "cm"))) +
  annotate("text", x = n_common * 1.12, y = sqrt(t_old * t_new),
           label = paste0(round(t_old / t_new), "x faster"),
           hjust = 0, colour = "grey20", size = 4)
save_both(p_time, "fig_time")

# ---- 2. memory ------------------------------------------------------------
p_mem <- base_plot("mem", "mem_lo", "mem_hi", "Peak memory of the R process (MB)") +
  geom_hline(yintercept = r_itself_MB, linetype = "dashed", colour = "grey50") +
  annotate("text", x = 500, y = r_itself_MB * 0.92,
           label = paste0("R itself (~", round(r_itself_MB), " MB)"),
           hjust = 0, vjust = 1, colour = "grey40", size = 3.6)
save_both(p_mem, "fig_memory")

# ---- 3. energy ------------------------------------------------------------
e_old <- summ$energy[summ$version == "discoCVI 0.1.1" & summ$n == n_common]
p_energy <- base_plot("energy", "energy_lo", "energy_hi",
                      "Energy per evaluation above baseline (mWh)") +
  geom_hline(yintercept = e_old, linetype = "dashed", colour = "grey50") +
  annotate("text", x = 500, y = e_old * 1.15,
           label = paste0("same energy: ", plain_num(n_common),
                          " points (0.1.1) vs 64,000 points (0.2.0)"),
           hjust = 0, vjust = 0, colour = "grey30", size = 3.6)
save_both(p_energy, "fig_energy")

print(p_time); print(p_mem); print(p_energy)
cat("Saved fig_time, fig_memory, fig_energy (.png and .pdf) to benchmarks/figures and paper/figures\n")
