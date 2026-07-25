# =============================================================================
# add_bootstrap_labels_only.R
# 在不改变拓扑与 edge.length 的前提下，为已有 tree.nwk 附加真实 bootstrap。
#
# 用法:
#   Rscript add_bootstrap_labels_only.R <input.fasta> <tree.nwk> <output_tree.nwk> [bs=100]
#
# 说明:
#   - 重新比对仅用于构造 pml / bootstrap 样本（不改写距离矩阵）
#   - prop.clades 映射到【原树】；写出时保留原 edge.length
#   - 不伪造支持度
# =============================================================================

suppressPackageStartupMessages({
  library(ape)
  library(phangorn)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  message("用法: Rscript add_bootstrap_labels_only.R <input.fasta> <tree.nwk> <output_tree.nwk> [bs=100]")
  quit(save = "no", status = 1)
}

fasta <- args[[1]]
tree_in <- args[[2]]
tree_out <- args[[3]]
bs_n <- if (length(args) >= 4) as.integer(args[[4]]) else 100L

scripts_dir <- tryCatch(
  dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])),
  error = function(e) "."
)
source(file.path(scripts_dir, "phylogenetic_tree.R"))

message("[1] read tree: ", tree_in)
tr <- ape::read.tree(tree_in)
if (is.null(tr$edge.length)) stop("tree 缺少 edge.length", call. = FALSE)
edge_bak <- tr$edge.length
tip_bak <- tr$tip.label

message("[2] align for bootstrap only")
dna <- read_fasta(fasta)
aligned <- align_sequences(dna)

# tip 集合必须一致
missing <- setdiff(tip_bak, names(aligned))
if (length(missing) > 0) {
  stop("比对结果缺少 tip: ", paste(utils::head(missing, 5), collapse = ", "), call. = FALSE)
}
aligned <- aligned[tip_bak]

message("[3] pml fit (for bootstrap.pml); original topology kept for output")
pdata <- phangorn::as.phyDat(aligned)
# bootstrap.pml 需要可优化的 fit；用无根树起步
tr_u <- ape::unroot(tr)
fit <- phangorn::pml(tr_u, data = pdata, model = "JC")
fit <- phangorn::optim.pml(
  fit,
  model = "JC",
  optNni = TRUE,
  rearrangement = "NNI",
  control = phangorn::pml.control(trace = 0)
)

message("[4] bootstrap.pml bs=", bs_n)
bs_trees <- phangorn::bootstrap.pml(
  fit,
  bs = bs_n,
  optNni = TRUE,
  control = phangorn::pml.control(trace = 0)
)

message("[5] map support onto ORIGINAL rooted tree (keep edge.length)")
# 重新读原树，确保不被 fit$tree 替换
tr2 <- ape::read.tree(tree_in)
tr2 <- attach_bootstrap_labels(tr2, bs_trees)
# 强制恢复原枝长与 tip 顺序（防御性）
if (!identical(tr2$tip.label, tip_bak)) {
  message("[警告] tip 顺序变化，按原 tip 重排不适用于 phylo；保持 prop.clades 结果")
}
if (length(tr2$edge.length) == length(edge_bak)) {
  # 仅当拓扑边数一致时恢复；prop.clades 不改边
  tr2$edge.length <- edge_bak
}

n_bs <- sum(nzchar(tr2$node.label) & !is.na(suppressWarnings(as.numeric(tr2$node.label))))
message("    bootstrap labels: ", n_bs, " / ", tr2$Nnode)

ape::write.tree(tr2, file = tree_out)
message("[6] wrote ", normalizePath(tree_out, winslash = "/", mustWork = FALSE))
message("done")
