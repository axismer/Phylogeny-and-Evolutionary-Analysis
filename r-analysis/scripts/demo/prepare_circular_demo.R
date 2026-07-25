# 生成 circular 演示树（24 tips）+ metadata，不依赖建树核心
suppressPackageStartupMessages(library(ape))

get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    return(dirname(normalizePath(sub("^--file=", "", file_arg[1]))))
  }
  normalizePath(getwd())
}

script_dir <- get_script_dir()
# scripts/demo → r-analysis 根
r_root <- normalizePath(file.path(script_dir, "..", ".."), winslash = "/")
demo_dir <- file.path(r_root, "data", "demo", "circular")
dir.create(demo_dir, recursive = TRUE, showWarnings = FALSE)
demo_dir <- normalizePath(demo_dir, winslash = "/")

set.seed(42)
n <- 24
tips <- sprintf("Tip_%02d", seq_len(n))
tree <- ape::rtree(n, rooted = TRUE, tip.label = tips)
# 拉长一点枝长，环形更清晰
tree$edge.length <- pmax(tree$edge.length, 0.05)

tree_file <- file.path(demo_dir, "tree.nwk")
ape::write.tree(tree, tree_file)

phyla <- c(
  "Actinomycetota", "Bacillota", "Bacteroidota", "Pseudomonadota",
  "Cyanobacteriota", "Spirochaetota", "Verrucomicrobiota", "Planctomycetota"
)
ages <- c("0d", "5d", "25d", "36d", "60d", "180d", "380d")

meta <- data.frame(
  label = tips,
  Phylum = sample(phyla, n, replace = TRUE),
  Age = sample(ages, n, replace = TRUE),
  stringsAsFactors = FALSE
)
# 让相邻 tip 在 Phylum 上略有团块，环上更好看
meta$Phylum <- phyla[((seq_len(n) - 1) %% length(phyla)) + 1]
meta$Age <- ages[((seq_len(n) - 1) %% length(ages)) + 1]

meta_file <- file.path(demo_dir, "metadata.csv")
utils::write.csv(meta, meta_file, row.names = FALSE, quote = TRUE)

# 同步一份 example_metadata 指向同数据（便于文档引用）
example_meta <- file.path(r_root, "data", "demo", "example_metadata.csv")
utils::write.csv(meta, example_meta, row.names = FALSE, quote = TRUE)

message("wrote: ", tree_file)
message("wrote: ", meta_file)
message("wrote: ", normalizePath(example_meta, winslash = "/"))
message("tips: ", length(tips))
