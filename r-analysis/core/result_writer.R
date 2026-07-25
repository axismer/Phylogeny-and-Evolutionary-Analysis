# =============================================================================
# result_writer.R — 统一 analysis_result.json 写出
#
# v0.1 字段 + v0.3 P1 error_code 契约：
#   success / partial → 禁止出现 error_code 键
#   error → 必须含 error_code + error_message
#   not_implemented → error_code = UNSUPPORTED_ORGANISM
# =============================================================================

# 加载 error_codes（不改 registry：由本文件自举）
if (!exists("raise_framework_error", mode = "function")) {
  .ec_loaded <- FALSE
  if (exists(".get_framework_dirs", mode = "function")) {
    ec <- file.path(.get_framework_dirs()$core, "error_codes.R")
    if (file.exists(ec)) {
      source(ec, local = FALSE)
      .ec_loaded <- TRUE
    }
  }
  if (!.ec_loaded) {
    for (cand in c(
      "core/error_codes.R",
      file.path("..", "core", "error_codes.R"),
      file.path("r-analysis", "core", "error_codes.R")
    )) {
      if (file.exists(cand)) {
        source(cand, local = FALSE)
        break
      }
    }
  }
  rm(.ec_loaded)
}

ANALYSIS_RESULT_STATUSES <- c("success", "partial", "error", "not_implemented")

#' 保证 statistics 序列化为 JSON object（避免空 list → []）
as_statistics_object <- function(statistics = list()) {
  if (is.null(statistics) || !is.list(statistics) || is.data.frame(statistics)) {
    return(structure(list(), names = character(0)))
  }
  if (length(statistics) == 0) {
    return(structure(list(), names = character(0)))
  }
  statistics
}

#' 构建统一结果对象
#'
#' @param error_code 仅 error / not_implemented 写入；success/partial 忽略
build_analysis_result <- function(status,
                                  organism_type,
                                  input = "",
                                  tree = "",
                                  visualization = "",
                                  metadata = "",
                                  statistics = list(),
                                  error_message = "",
                                  error_code = NULL,
                                  extras = list(),
                                  tree_file = NULL) {
  if (!is.null(tree_file) && (is.null(tree) || !nzchar(as.character(tree)[[1]]))) {
    tree <- as.character(tree_file)[[1]]
  }
  status <- as.character(status)[[1]]
  if (!status %in% ANALYSIS_RESULT_STATUSES) {
    warning(
      "analysis_result status 非冻结枚举: ", status,
      "；允许: ", paste(ANALYSIS_RESULT_STATUSES, collapse = ", "),
      call. = FALSE
    )
  }
  msg <- if (is.null(error_message) || length(error_message) < 1) {
    ""
  } else {
    paste(as.character(error_message), collapse = " ")
  }
  if (!identical(status, "error") && !identical(status, "not_implemented") && !nzchar(msg)) {
    msg <- ""
  }

  result <- list(
    status = status,
    organism_type = as.character(organism_type)[[1]],
    input = as.character(input %||% "")[[1]],
    tree = as.character(tree %||% "")[[1]],
    visualization = as.character(visualization %||% "")[[1]],
    metadata = as.character(metadata %||% "")[[1]],
    statistics = as_statistics_object(statistics),
    error_message = msg
  )
  result$tree_file <- result$tree

  # v0.3 P1：仅失败态带 error_code；success/partial 禁止该键
  if (identical(status, "error")) {
    code <- if (exists("normalize_error_code", mode = "function")) {
      normalize_error_code(error_code %||% "", status = "error")
    } else {
      as.character(error_code %||% "")[[1]]
    }
    if (!nzchar(code) && exists("map_error_message_to_code", mode = "function")) {
      code <- map_error_message_to_code(msg, default = "")
    }
    result$error_code <- code
  } else if (identical(status, "not_implemented")) {
    code <- if (exists("normalize_error_code", mode = "function")) {
      normalize_error_code(error_code %||% "UNSUPPORTED_ORGANISM", status = "not_implemented")
    } else {
      "UNSUPPORTED_ORGANISM"
    }
    result$error_code <- code
  }

  for (nm in names(extras)) {
    if (!nm %in% names(result)) {
      result[[nm]] <- extras[[nm]]
    }
  }
  # 再次保证 success/partial 无 error_code（防止 extras 注入）
  if (status %in% c("success", "partial") && "error_code" %in% names(result)) {
    result$error_code <- NULL
    result <- result[names(result) != "error_code"]
  }
  result
}

#' 写出 analysis_result.json
write_analysis_result <- function(result, output_dir, filename = "analysis_result.json") {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("需要 jsonlite 包以写出 analysis_result.json", call. = FALSE)
  }
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  if (is.null(result$statistics) || !is.list(result$statistics) || is.data.frame(result$statistics)) {
    result$statistics <- as_statistics_object(list())
  } else if (length(result$statistics) == 0) {
    result$statistics <- as_statistics_object(list())
  }
  if (is.null(result$error_message)) result$error_message <- ""
  if (is.null(result$input)) result$input <- ""
  if (is.null(result$tree)) {
    result$tree <- if (!is.null(result$tree_file)) as.character(result$tree_file) else ""
  }
  if (is.null(result$tree_file)) result$tree_file <- result$tree
  if (is.null(result$visualization)) result$visualization <- ""
  if (is.null(result$metadata)) result$metadata <- ""
  if (is.null(result$organism_type)) result$organism_type <- ""

  st <- as.character(result$status %||% "")
  if (st %in% c("success", "partial")) {
    if ("error_code" %in% names(result)) {
      result$error_code <- NULL
      result <- result[names(result) != "error_code"]
    }
  } else if (identical(st, "error")) {
    if (is.null(result$error_code) || !nzchar(as.character(result$error_code)[[1]])) {
      if (exists("map_error_message_to_code", mode = "function")) {
        result$error_code <- map_error_message_to_code(result$error_message, default = "")
      } else {
        result$error_code <- ""
      }
    }
  } else if (identical(st, "not_implemented")) {
    if (is.null(result$error_code) || !nzchar(as.character(result$error_code)[[1]])) {
      result$error_code <- "UNSUPPORTED_ORGANISM"
    }
  }

  path <- file.path(output_dir, filename)
  txt <- jsonlite::toJSON(
    result,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null",
    force = TRUE
  )
  con <- file(path, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(charToRaw(paste0(enc2utf8(as.character(txt)), "\n")), con)
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

#' 覆盖写出失败结果（防止 legacy status=success 残留）
write_error_analysis_result <- function(organism_type,
                                        output_dir,
                                        error_message = "",
                                        error_code = "",
                                        input = "",
                                        tree = "",
                                        visualization = "",
                                        metadata = "",
                                        statistics = list(),
                                        tree_file = NULL) {
  if (!is.null(tree_file) && (!nzchar(as.character(tree)[[1]]))) {
    tree <- as.character(tree_file)[[1]]
  }
  msg <- if (is.null(error_message) || length(error_message) < 1) {
    ""
  } else {
    paste(as.character(error_message), collapse = " ")
  }
  code <- error_code
  if ((!nzchar(as.character(code %||% ""))) && exists("map_error_message_to_code", mode = "function")) {
    code <- map_error_message_to_code(msg, default = "")
  }
  result <- build_analysis_result(
    status = "error",
    organism_type = organism_type,
    input = input,
    tree = tree,
    visualization = visualization,
    metadata = metadata,
    statistics = statistics,
    error_message = msg,
    error_code = code
  )
  write_analysis_result(result, output_dir)
  result
}

#' 写出 not_implemented（含 UNSUPPORTED_ORGANISM）
write_not_implemented_result <- function(organism_type,
                                         output_dir,
                                         error_message = "",
                                         input = "",
                                         statistics = list()) {
  msg <- if (is.null(error_message) || !nzchar(paste(error_message, collapse = ""))) {
    paste0("Organism type not implemented or unknown: ", organism_type)
  } else {
    paste(as.character(error_message), collapse = " ")
  }
  result <- build_analysis_result(
    status = "not_implemented",
    organism_type = if (nzchar(as.character(organism_type)[[1]])) organism_type else "unknown",
    input = input,
    statistics = statistics,
    error_message = msg,
    error_code = "UNSUPPORTED_ORGANISM"
  )
  write_analysis_result(result, output_dir)
  result
}

#' 从旧版 engine analysis_result.json 升级（成功路径不带 error_code）
upgrade_legacy_result <- function(legacy,
                                  organism_type = "virus",
                                  visualization = "",
                                  metadata = "",
                                  status = NULL,
                                  error_message = "",
                                  error_code = NULL) {
  tree <- legacy$tree %||% legacy$tree_file %||% "tree.nwk"
  input <- legacy$input %||% ""
  stats <- list(
    sequence_count = legacy$sequence_count %||% NULL,
    method = legacy$method %||% NULL,
    model = legacy$model %||% NULL,
    matrix_file = legacy$matrix_file %||% NULL,
    image_file = legacy$image_file %||% NULL
  )
  stats <- stats[!vapply(stats, is.null, logical(1))]

  st <- status %||% legacy$status %||% "success"
  if (identical(as.character(st), "failed")) st <- "error"

  build_analysis_result(
    status = st,
    organism_type = organism_type,
    input = input,
    tree = tree,
    visualization = visualization,
    metadata = metadata,
    statistics = stats,
    error_message = error_message,
    error_code = error_code,
    extras = list(
      sequence_count = legacy$sequence_count,
      method = legacy$method,
      model = legacy$model,
      matrix_file = legacy$matrix_file,
      image_file = legacy$image_file
    )
  )
}

`%||%` <- function(a, b) {
  if (is.null(a) || (length(a) == 1 && is.na(a))) b else a
}

# -----------------------------------------------------------------------------
# Bootstrap core/io（P2；不改 registry，与 error_codes 自举模式一致）
# -----------------------------------------------------------------------------
.source_framework_io <- function() {
  io_names <- c("fasta_io.R", "metadata_io.R", "output_io.R")
  resolve_io_dir <- function() {
    if (exists(".get_framework_dirs", mode = "function")) {
      d <- file.path(.get_framework_dirs()$core, "io")
      if (dir.exists(d)) return(d)
    }
    for (cand in c(
      file.path("core", "io"),
      file.path("..", "core", "io"),
      file.path("r-analysis", "core", "io")
    )) {
      if (dir.exists(cand)) return(normalizePath(cand, winslash = "/", mustWork = FALSE))
    }
    NULL
  }
  io_dir <- resolve_io_dir()
  if (is.null(io_dir)) return(invisible(FALSE))
  for (f in io_names) {
    path <- file.path(io_dir, f)
    if (!file.exists(path)) next
    already <- FALSE
    if (identical(f, "fasta_io.R")) {
      already <- exists("read_fasta", mode = "function")
    } else if (identical(f, "metadata_io.R")) {
      already <- exists("read_metadata", mode = "function")
    } else if (identical(f, "output_io.R")) {
      already <- exists("write_analysis_output", mode = "function")
    }
    if (!isTRUE(already)) {
      source(path, local = FALSE)
    }
  }
  invisible(TRUE)
}
.source_framework_io()
rm(.source_framework_io)
