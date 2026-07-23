# =============================================================================
# phylogenetic_tree.R — 独立系统发育分析引擎
#
# 用法：
#   Rscript phylogenetic_tree.R <input.fasta> <output_dir>
#
# 必填参数：
#   input.fasta  — 输入 DNA FASTA
#   output_dir   — 输出目录（不存在则自动创建）
#
# 标准输出文件：
#   distance_matrix.csv
#   tree.nwk
#   tree.png
#   analysis_result.json
#
# 依赖：ape, phangorn, ggplot2；推荐 ggtree（失败时回退 ape 出图）
# =============================================================================

suppressPackageStartupMessages({
  library(ape)
  library(phangorn)
  library(ggplot2)
})

.ggtree_available <- FALSE
tryCatch(
  {
    suppressPackageStartupMessages(library(ggtree))
    .ggtree_available <<- TRUE
  },
  error = function(e) {
    message("[警告] ggtree 不可用，tree.png 将使用 ape::plot.phylo 生成: ",
            conditionMessage(e))
  }
)

# =============================================================================
# 工具函数
# =============================================================================

get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    return(dirname(normalizePath(sub("^--file=", "", file_arg[1]))))
  }
  normalizePath(getwd())
}

#' 解析命令行：必须提供 input.fasta 与 output_dir
parse_cli_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 2) {
    script <- "phylogenetic_tree.R"
    message("用法: Rscript ", script, " <input.fasta> <output_dir>")
    message("示例: Rscript ", script, " ../data/example.fasta ../output")
    stop("缺少参数：需要 input.fasta 与 output_dir", call. = FALSE)
  }
  list(
    input = normalizePath(args[[1]], winslash = "/", mustWork = FALSE),
    output = normalizePath(args[[2]], winslash = "/", mustWork = FALSE)
  )
}

ensure_output_dir <- function(output_dir) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  normalizePath(output_dir, winslash = "/", mustWork = TRUE)
}

# =============================================================================
# 核心模块函数（对外接口名固定，便于维护与 Java/Rscript 对接）
# =============================================================================

#' 读取 FASTA DNA 序列
#' @param fasta_path 输入 FASTA 路径
#' @return DNAbin
read_fasta <- function(fasta_path) {
  if (!file.exists(fasta_path)) {
    stop("输入 FASTA 不存在: ", fasta_path, call. = FALSE)
  }
  message("[1] read_fasta: ", fasta_path)
  dna <- ape::read.FASTA(fasta_path, type = "DNA")
  n <- length(dna)
  if (n < 3) {
    stop("至少需要 3 条序列，当前: ", n, call. = FALSE)
  }
  message("    sequence_count = ", n)
  dna
}

#' 内部：多序列比对（等长则跳过；否则尝试 MUSCLE；再否则末端补 gap）
align_sequences <- function(dna) {
  message("[2] align_sequences")
  lens <- lengths(dna)
  if (length(unique(lens)) == 1) {
    message("    长度一致 (", lens[[1]], ")，视为已比对")
    return(dna)
  }

  aligned <- tryCatch(
    {
      message("    尝试 ape::muscle ...")
      ape::muscle(dna, quiet = TRUE)
    },
    error = function(e) {
      message("    muscle 不可用: ", conditionMessage(e))
      NULL
    }
  )
  if (!is.null(aligned)) {
    message("    MUSCLE 完成")
    return(aligned)
  }

  message("    [警告] 使用末端补 gap（非正式 MSA）")
  max_len <- max(lens)
  mats <- lapply(seq_along(dna), function(i) {
    seq_chars <- as.character(dna[i])[[1]]
    if (length(seq_chars) < max_len) {
      seq_chars <- c(seq_chars, rep("-", max_len - length(seq_chars)))
    }
    matrix(seq_chars, nrow = 1, dimnames = list(names(dna)[i], NULL))
  })
  ape::as.DNAbin(do.call(rbind, mats))
}

#' 计算遗传距离（K80），并写入 distance_matrix.csv
#' @param aligned 比对后 DNAbin
#' @param output_dir 输出目录
#' @return list(dist, matrix, matrix_file)
calculate_distance <- function(aligned, output_dir) {
  message("[3] calculate_distance (K80)")
  dist_obj <- ape::dist.dna(aligned, model = "K80", pairwise.deletion = TRUE)
  mat <- as.matrix(dist_obj)
  matrix_file <- file.path(output_dir, "distance_matrix.csv")
  utils::write.csv(mat, file = matrix_file, quote = TRUE, row.names = TRUE)
  message("    -> ", matrix_file)
  list(dist = dist_obj, matrix = mat, matrix_file = matrix_file)
}

#' 构建系统发育树：NJ 起步 + Maximum Likelihood (JC69)
#' @param aligned DNAbin
#' @param dist_obj dist（用于 NJ）
#' @return list(tree, method, model, logLik, nj_tree)
build_tree <- function(aligned, dist_obj) {
  message("[4] build_tree: NJ → Maximum Likelihood (JC69)")

  # Neighbor Joining 起始树
  nj_tree <- ape::nj(dist_obj)
  nj_tree <- ape::unroot(nj_tree)

  pdata <- phangorn::as.phyDat(aligned)
  fit <- phangorn::pml(nj_tree, data = pdata, model = "JC")
  fit <- phangorn::optim.pml(
    fit,
    model = "JC",
    optNni = TRUE,
    rearrangement = "NNI",
    control = phangorn::pml.control(trace = 0)
  )

  ml_tree <- ape::root(fit$tree, outgroup = fit$tree$tip.label[1], resolve.root = TRUE)
  ml_tree <- ape::ladderize(ml_tree)

  nj_rooted <- ape::root(ape::nj(dist_obj), outgroup = labels(dist_obj)[1], resolve.root = TRUE)
  nj_rooted <- ape::ladderize(nj_rooted)

  message("    method = Maximum Likelihood, model = JC69, logLik = ", round(fit$logLik, 3))
  list(
    tree = ml_tree,
    nj_tree = nj_rooted,
    method = "Maximum Likelihood",
    model = "JC69",
    logLik = fit$logLik
  )
}

#' 保存 Newick（默认 tree.nwk）
#' @param tree phylo
#' @param output_dir 输出目录
#' @param file_name 文件名
#' @return 写出路径
save_newick <- function(tree, output_dir, file_name = "tree.nwk") {
  message("[5] save_newick")
  path <- file.path(output_dir, file_name)
  ape::write.tree(tree, file = path)
  message("    -> ", path)
  path
}

#' 绘制系统发育树为 tree.png（ape::plot.phylo 为主）
#' @param tree phylo
#' @param output_dir 输出目录
#' @param title 图标题
#' @param file_name 输出文件名（默认 tree.png；诊断可用 tree_test.png）
#' @return PNG 路径
plot_tree <- function(tree, output_dir, title = "Maximum Likelihood tree (JC69)",
                      file_name = "tree.png") {
  message("[6] plot_tree")
  png_path <- file.path(output_dir, file_name)

  # 大画布，避免标签挤在一起；枝长极小时仍按真实 edge.length 绘制
  width_in <- 12
  height_in <- 10
  tip_cex <- 1.1

  # 打印结构，便于确认 Newick / phylo 对象是否正常
  message("    tip.label: ", paste(tree$tip.label, collapse = ", "))
  message("    edge (nrow=", nrow(tree$edge), "):")
  print(tree$edge)
  message("    edge.length:")
  print(tree$edge.length)

  grDevices::png(
    filename = png_path,
    width = width_in,
    height = height_in,
    units = "in",
    res = 150,
    bg = "white"
  )
  on.exit({
    try(grDevices::dev.off(), silent = TRUE)
  }, add = TRUE)

  # 留出右侧空间给 tip 标签
  op <- graphics::par(mar = c(5, 2, 4, 10) + 0.1, xpd = TRUE)
  on.exit(graphics::par(op), add = TRUE)

  ape::plot.phylo(
    tree,
    type = "phylogram",
    use.edge.length = TRUE,
    cex = tip_cex,
    label.offset = 0.002,
    edge.width = 1.5,
    font = 1,
    main = title,
    no.margin = FALSE
  )
  # 比例尺：帮助判断枝长是否被正确使用
  if (!is.null(tree$edge.length) && any(tree$edge.length > 0, na.rm = TRUE)) {
    ape::add.scale.bar(cex = 0.9, lwd = 2)
  }

  message("    ape::plot.phylo -> ", png_path)
  png_path
}

#' 写出分析元数据 JSON
#' @param json_path 完整路径
#' @param payload 命名 list
write_result_json <- function(json_path, payload) {
  message("[7] write_result_json: ", json_path)
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    jsonlite::write_json(payload, path = json_path, auto_unbox = TRUE, pretty = TRUE)
  } else {
    # 无 jsonlite 时手写最小 JSON（字段均为标量字符串/数字）
    esc <- function(x) {
      x <- gsub("\\\\", "\\\\\\\\", as.character(x), perl = TRUE)
      x <- gsub("\"", "\\\\\"", x, perl = TRUE)
      x
    }
    lines <- c(
      "{",
      paste0('  "input": "', esc(payload$input), '",'),
      paste0('  "sequence_count": ', as.integer(payload$sequence_count), ","),
      paste0('  "method": "', esc(payload$method), '",'),
      paste0('  "model": "', esc(payload$model), '",'),
      paste0('  "tree_file": "', esc(payload$tree_file), '",'),
      paste0('  "matrix_file": "', esc(payload$matrix_file), '",'),
      paste0('  "image_file": "', esc(payload$image_file), '",'),
      paste0('  "status": "', esc(payload$status), '"'),
      "}"
    )
    writeLines(lines, con = json_path, useBytes = FALSE)
  }
  invisible(json_path)
}

# =============================================================================
# 引擎主流程
# =============================================================================

#' 运行完整分析引擎
#' @param input_fasta FASTA 路径
#' @param output_dir 输出目录
run_analysis_engine <- function(input_fasta, output_dir) {
  output_dir <- ensure_output_dir(output_dir)
  input_basename <- basename(input_fasta)

  dna <- read_fasta(input_fasta)
  aligned <- align_sequences(dna)
  dist_result <- calculate_distance(aligned, output_dir)
  tree_result <- build_tree(aligned, dist_result$dist)

  tree_file <- save_newick(tree_result$tree, output_dir, "tree.nwk")
  image_file <- plot_tree(tree_result$tree, output_dir)

  # 相对文件名写入 JSON，便于 Java 侧按目录拼接
  payload <- list(
    input = input_basename,
    sequence_count = length(dna),
    method = tree_result$method,
    model = tree_result$model,
    tree_file = "tree.nwk",
    matrix_file = "distance_matrix.csv",
    image_file = "tree.png",
    status = "success"
  )
  json_path <- file.path(output_dir, "analysis_result.json")
  write_result_json(json_path, payload)

  message("======== analysis engine finished ========")
  message("output_dir: ", output_dir)
  message("files: distance_matrix.csv | tree.nwk | tree.png | analysis_result.json")

  invisible(list(
    output_dir = output_dir,
    result = payload,
    tree = tree_result$tree
  ))
}

#' 失败时尽量写出 status=failed 的 JSON（若输出目录可用）
write_failure_json <- function(output_dir, input_fasta, message_text) {
  tryCatch(
    {
      if (is.null(output_dir) || !nzchar(output_dir)) {
        return(invisible(NULL))
      }
      ensure_output_dir(output_dir)
      payload <- list(
        input = if (!is.null(input_fasta)) basename(input_fasta) else "",
        sequence_count = 0L,
        method = "Maximum Likelihood",
        model = "JC69",
        tree_file = "tree.nwk",
        matrix_file = "distance_matrix.csv",
        image_file = "tree.png",
        status = "failed"
      )
      write_result_json(file.path(output_dir, "analysis_result.json"), payload)
      message("[失败详情] ", message_text)
    },
    error = function(e) invisible(NULL)
  )
}

# =============================================================================
# CLI 入口
# =============================================================================

is_main_rscript <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  any(grepl("^--file=", args))
}

if (is_main_rscript()) {
  cli <- NULL
  exit_code <- tryCatch(
    {
      cli <- parse_cli_args()
      run_analysis_engine(cli$input, cli$output)
      0L
    },
    error = function(e) {
      msg <- conditionMessage(e)
      message("[错误] ", msg)
      out <- if (!is.null(cli)) cli$output else {
        args <- commandArgs(trailingOnly = TRUE)
        if (length(args) >= 2) args[[2]] else NULL
      }
      inp <- if (!is.null(cli)) cli$input else {
        args <- commandArgs(trailingOnly = TRUE)
        if (length(args) >= 1) args[[1]] else NULL
      }
      write_failure_json(out, inp, msg)
      1L
    }
  )
  quit(save = "no", status = exit_code)
}
