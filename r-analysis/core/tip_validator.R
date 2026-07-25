# =============================================================================
# tip_validator.R — 统一 tip ↔ metadata 对齐校验（Framework v0.2）
#
# 所有 Strategy 必须调用本模块；禁止在 strategy 内复制 setdiff(tips, labels)。
# =============================================================================

#' 从 phylo 对象或 Newick 路径读取 tip 标签
#' @param tree ape::phylo 或 character 路径
#' @return character tip labels
read_tree_tips <- function(tree) {
  if (inherits(tree, "phylo")) {
    return(as.character(tree$tip.label))
  }
  if (is.character(tree) && length(tree) == 1L && nzchar(tree)) {
    if (!file.exists(tree)) {
      stop("tip_validator: tree 文件不存在: ", tree, call. = FALSE)
    }
    if (!requireNamespace("ape", quietly = TRUE)) {
      stop("tip_validator: 需要 ape 包以读取 tree", call. = FALSE)
    }
    tr <- ape::read.tree(tree)
    return(as.character(tr$tip.label))
  }
  stop("tip_validator: tree 须为 phylo 或 Newick 路径", call. = FALSE)
}

#' 统一 tip ↔ metadata 对齐
#'
#' @param tree phylo 或 Newick 路径
#' @param metadata data.frame（须含 tip 对齐列）
#' @param id_column metadata 中与 tip 对齐的列名（默认 label）
#' @return 成功：
#'   list(matched = <int>, missing = 0L, missing_tips = character(0), ok = TRUE)
#' 失败：
#'   list(status = "error", error_message = "metadata missing tips: ...",
#'        matched = <int>, missing = <int>, missing_tips = <chr>, ok = FALSE)
assert_tip_match <- function(tree, metadata, id_column = "label") {
  if (is.null(metadata) || !is.data.frame(metadata)) {
    return(list(
      ok = FALSE,
      status = "error",
      error_message = "metadata missing tips",
      matched = 0L,
      missing = NA_integer_,
      missing_tips = character(0)
    ))
  }
  if (!id_column %in% names(metadata)) {
    return(list(
      ok = FALSE,
      status = "error",
      error_message = paste0("metadata missing tips (no column '", id_column, "')"),
      matched = 0L,
      missing = NA_integer_,
      missing_tips = character(0)
    ))
  }

  tips <- read_tree_tips(tree)
  labs <- as.character(metadata[[id_column]])
  miss <- setdiff(tips, labs)
  matched <- length(tips) - length(miss)

  if (length(miss) > 0) {
    shown <- utils::head(miss, 8)
    msg <- paste0(
      "metadata missing tips: ",
      paste(shown, collapse = ", "),
      if (length(miss) > 8) " ..." else ""
    )
    return(list(
      ok = FALSE,
      status = "error",
      error_message = msg,
      matched = as.integer(matched),
      missing = as.integer(length(miss)),
      missing_tips = as.character(miss)
    ))
  }

  list(
    ok = TRUE,
    matched = as.integer(length(tips)),
    missing = 0L,
    missing_tips = character(0)
  )
}

#' 校验失败则 stop；成功返回 matched 摘要（供 strategy 日志）
#'
#' @param tip_result assert_tip_match() 返回值
#' @param message_prefix 保留各 Strategy 既有对外文案前缀（输出语义兼容）
#' @return tip_result（成功时）
stop_on_tip_mismatch <- function(tip_result, message_prefix = "") {
  if (isTRUE(tip_result$ok)) {
    return(invisible(tip_result))
  }
  detail <- tip_result$missing_tips
  if (is.null(detail) || length(detail) < 1) {
    msg <- if (nzchar(message_prefix)) {
      paste0(message_prefix, tip_result$error_message %||% "metadata missing tips")
    } else {
      tip_result$error_message %||% "metadata missing tips"
    }
  } else {
    shown <- utils::head(detail, 8)
    core <- paste(shown, collapse = ", ")
    msg <- if (nzchar(message_prefix)) {
      paste0(message_prefix, core)
    } else {
      paste0("metadata missing tips: ", core)
    }
  }
  stop(msg, call. = FALSE)
}
