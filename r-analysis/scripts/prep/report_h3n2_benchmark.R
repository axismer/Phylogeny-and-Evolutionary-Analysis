# =============================================================================
# report_h3n2_benchmark.R — tip / year / country / branch length 汇总
# 用法: Rscript report_h3n2_benchmark.R <output_dir> [ncbi_metadata.csv]
# =============================================================================
args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args) >= 1) args[[1]] else "../../output/benchmarks/h3n2_ha"
ncbi_path <- if (length(args) >= 2) args[[2]] else NA_character_
suppressPackageStartupMessages(library(ape))

tree_path <- file.path(out_dir, "tree.nwk")
meta_path <- file.path(out_dir, "metadata.csv")
png_path <- file.path(out_dir, "circular_tree_final.png")

tr <- ape::read.tree(tree_path)
meta <- utils::read.csv(meta_path, stringsAsFactors = FALSE)
bl <- tr$edge.length

lines <- c(
  "======== H3N2 HA benchmark report ========",
  paste0("tip_count=", length(tr$tip.label)),
  paste0("n_years=", length(unique(meta$Year))),
  paste0("year_span=", min(as.integer(meta$Year), na.rm = TRUE), "-",
         max(as.integer(meta$Year), na.rm = TRUE)),
  "year_distribution:",
  paste(capture.output(print(sort(table(meta$Year)))), collapse = "\n"),
  "region_distribution_(Country_column_for_ggtree):",
  paste(capture.output(print(sort(table(meta$Country)))), collapse = "\n")
)

if (!is.na(ncbi_path) && file.exists(ncbi_path)) {
  ncbi <- utils::read.csv(ncbi_path, stringsAsFactors = FALSE)
  if ("Country_Raw" %in% names(ncbi)) {
    lines <- c(
      lines,
      paste0("n_countries=", length(unique(ncbi$Country_Raw))),
      "country_distribution:",
      paste(capture.output(print(sort(table(ncbi$Country_Raw)))), collapse = "\n")
    )
  }
}

lines <- c(
  lines,
  "branch_length_stats:",
  paste0("  n=", length(bl)),
  paste0("  min=", format(min(bl, na.rm = TRUE), digits = 8, scientific = TRUE)),
  paste0("  max=", format(max(bl, na.rm = TRUE), digits = 8, scientific = FALSE)),
  paste0("  mean=", format(mean(bl, na.rm = TRUE), digits = 8, scientific = FALSE)),
  paste0("  median=", format(stats::median(bl, na.rm = TRUE), digits = 8, scientific = FALSE)),
  paste0("  zero_count=", sum(bl <= 0, na.rm = TRUE)),
  paste0("  near_zero_1e-8=", sum(bl < 1e-8, na.rm = TRUE)),
  paste0("  zero_frac=", format(mean(bl <= 0, na.rm = TRUE), digits = 4)),
  paste0("circular_png=", normalizePath(png_path, winslash = "/", mustWork = FALSE)),
  paste0("png_exists=", file.exists(png_path))
)
report_file <- file.path(out_dir, "benchmark_report.txt")
writeLines(lines, report_file)
message(paste(lines, collapse = "\n"))
message("wrote ", report_file)
