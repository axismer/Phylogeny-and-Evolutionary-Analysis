# =============================================================================
# fasta_io.R — 公共 FASTA IO（Framework v0.3 P2）
#
# 职责：文件读取、基础格式检查、FASTA 写出。
# 禁止：organism 判断、IUPAC、min sequence 数量、长度规则（留 strategy）。
# =============================================================================

#' 读取 FASTA 记录（与 virus/bacteria 原 read_fasta_records 逐行一致）
#'
#' @param path FASTA 路径
#' @return list(ids = character(), seqs = character()) — tip 顺序与文件出现顺序一致
read_fasta <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  ids <- character()
  seqs <- character()
  cur_id <- NULL
  cur <- character()
  flush <- function() {
    if (is.null(cur_id)) return()
    ids <<- c(ids, cur_id)
    seqs <<- c(seqs, toupper(paste(cur, collapse = "")))
  }
  for (ln in lines) {
    if (!nzchar(trimws(ln))) next
    if (startsWith(ln, ">")) {
      flush()
      cur_id <- sub("^>\\s*", "", ln)
      cur_id <- strsplit(cur_id, "\\s+")[[1]][[1]]
      cur <- character()
    } else {
      cur <- c(cur, gsub("\\s+", "", ln))
    }
  }
  flush()
  list(ids = ids, seqs = seqs)
}

#' 基础 FASTA 路径/空文件/表头检查（无生物学规则）
#'
#' @param path FASTA 路径
#' @param message_prefix 消息前缀，如 "VirusStrategy"
#' @param empty_message 空文件完整消息（覆盖默认）
#' @param require_header "first" = 首行必须以 > 开头（virus 既有行为）；
#'   "any" = 至少一行以 > 开头；"none" = 不做表头检查（bacteria 既有行为）
#' @return invisible(TRUE)；失败 raise_framework_error(EMPTY_FASTA, ...)
validate_fasta_basic <- function(path,
                                 message_prefix = "",
                                 empty_message = NULL,
                                 require_header = c("any", "first", "none")) {
  require_header <- match.arg(require_header)
  prefix <- if (nzchar(as.character(message_prefix)[[1]])) {
    paste0(as.character(message_prefix)[[1]], ": ")
  } else {
    ""
  }

  if (is.null(path) || !nzchar(as.character(path)[[1]])) {
    raise_framework_error("EMPTY_FASTA", paste0(prefix, "缺少 --fasta"))
  }
  path <- as.character(path)[[1]]
  if (!file.exists(path)) {
    raise_framework_error(
      "EMPTY_FASTA",
      paste0(prefix, "FASTA 不存在: ", path)
    )
  }

  lines <- tryCatch(
    readLines(path, warn = FALSE, encoding = "UTF-8"),
    error = function(e) character()
  )
  finfo <- file.info(path)
  is_empty <- isTRUE(finfo$size == 0) || length(lines) == 0L ||
    !any(nzchar(trimws(lines)))
  if (is_empty) {
    msg <- if (!is.null(empty_message) && nzchar(as.character(empty_message)[[1]])) {
      as.character(empty_message)[[1]]
    } else {
      paste0(prefix, "FASTA 为空（无序列记录）")
    }
    raise_framework_error("EMPTY_FASTA", msg)
  }

  if (identical(require_header, "first")) {
    if (!startsWith(lines[[1]], ">")) {
      raise_framework_error(
        "EMPTY_FASTA",
        paste0(prefix, "FASTA 格式无效（首行应以 > 开头）")
      )
    }
  } else if (identical(require_header, "any")) {
    if (!any(startsWith(lines, ">"))) {
      raise_framework_error(
        "EMPTY_FASTA",
        paste0(prefix, "FASTA 格式无效（至少一行应以 > 开头）")
      )
    }
  }

  invisible(TRUE)
}

#' 写出 FASTA（对称 API；生产路径可不调用）
#'
#' @param path 输出路径
#' @param ids tip / sample id（顺序保持）
#' @param seqs 对应序列
write_fasta <- function(path, ids, seqs) {
  if (length(ids) != length(seqs)) {
    stop("write_fasta: ids 与 seqs 长度不一致", call. = FALSE)
  }
  dir_out <- dirname(path)
  if (!dir.exists(dir_out) && nzchar(dir_out) && !identical(dir_out, ".")) {
    dir.create(dir_out, recursive = TRUE, showWarnings = FALSE)
  }
  lines <- character(0)
  for (i in seq_along(ids)) {
    lines <- c(lines, paste0(">", as.character(ids[[i]])), as.character(seqs[[i]]))
  }
  writeLines(lines, path, useBytes = FALSE)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}
