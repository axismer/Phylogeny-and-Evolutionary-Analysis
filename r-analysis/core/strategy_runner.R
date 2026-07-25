# =============================================================================
# strategy_runner.R — Strategy 公共执行模板（Framework v0.3 P1）
#
# 职责：输出目录、异常捕获、error JSON（含 error_code）、统一日志。
# =============================================================================

# 确保 core/io 可用（P2；result_writer 通常已自举，此处兜底）
if (!exists("read_fasta", mode = "function") ||
    !exists("read_metadata", mode = "function") ||
    !exists("write_analysis_output", mode = "function")) {
  .sr_io_dir <- NULL
  if (exists(".get_framework_dirs", mode = "function")) {
    .sr_io_dir <- file.path(.get_framework_dirs()$core, "io")
  }
  if (is.null(.sr_io_dir) || !dir.exists(.sr_io_dir)) {
    for (.cand in c("core/io", file.path("..", "core", "io"),
                    file.path("r-analysis", "core", "io"))) {
      if (dir.exists(.cand)) {
        .sr_io_dir <- .cand
        break
      }
    }
  }
  if (!is.null(.sr_io_dir) && dir.exists(.sr_io_dir)) {
    for (.f in c("fasta_io.R", "metadata_io.R", "output_io.R")) {
      .p <- file.path(.sr_io_dir, .f)
      if (file.exists(.p)) source(.p, local = FALSE)
    }
  }
  rm(list = intersect(c(".sr_io_dir", ".cand", ".f", ".p"), ls(all.names = TRUE)))
}

#' 输入 FASTA 基名
strategy_input_basename <- function(ctx) {
  if (is.null(ctx$fasta_path) || !nzchar(as.character(ctx$fasta_path)[[1]])) {
    return("")
  }
  basename(ctx$fasta_path)
}

#' 确保输出目录存在
ensure_strategy_output_dir <- function(ctx) {
  if (is.null(ctx$output_dir) || !nzchar(as.character(ctx$output_dir)[[1]])) {
    stop("strategy_runner: 缺少 output_dir", call. = FALSE)
  }
  if (!dir.exists(ctx$output_dir)) {
    dir.create(ctx$output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  invisible(normalizePath(ctx$output_dir, winslash = "/", mustWork = FALSE))
}

#' 是否已有本类型的 error JSON（避免覆盖更精确的 fail 消息）
has_strategy_error_json <- function(ctx, organism_type) {
  if (is.null(ctx$output_dir) || !nzchar(ctx$output_dir) || !dir.exists(ctx$output_dir)) {
    return(FALSE)
  }
  json_path <- file.path(ctx$output_dir, "analysis_result.json")
  if (!file.exists(json_path) || !requireNamespace("jsonlite", quietly = TRUE)) {
    return(FALSE)
  }
  prev <- tryCatch(jsonlite::fromJSON(json_path), error = function(...) NULL)
  !is.null(prev) &&
    identical(as.character(prev$status), "error") &&
    identical(as.character(prev$organism_type), as.character(organism_type))
}

#' 写出 error JSON 并 stop（覆盖 legacy status=success 残留）
fail_with_error_json <- function(ctx,
                                 organism_type,
                                 error_message,
                                 error_code = "",
                                 tree = "",
                                 metadata = "",
                                 visualization = "",
                                 statistics = list()) {
  if (is.null(ctx$output_dir) || !nzchar(as.character(ctx$output_dir)[[1]])) {
    if (exists("raise_framework_error", mode = "function") && nzchar(as.character(error_code)[[1]])) {
      raise_framework_error(error_code, error_message)
    }
    stop(error_message, call. = FALSE)
  }
  ensure_strategy_output_dir(ctx)
  code <- error_code
  if (!nzchar(as.character(code %||% "")) && exists("extract_error_code", mode = "function")) {
    code <- map_error_message_to_code(error_message, default = "")
  }
  write_error_analysis_result(
    organism_type = organism_type,
    output_dir = ctx$output_dir,
    error_message = error_message,
    error_code = code,
    input = strategy_input_basename(ctx),
    tree = tree,
    metadata = metadata,
    visualization = visualization,
    statistics = statistics
  )
  if (exists("raise_framework_error", mode = "function") && nzchar(as.character(code)[[1]])) {
    raise_framework_error(code, error_message)
  }
  stop(error_message, call. = FALSE)
}

#' 统一 tip 校验：失败则 TIP_METADATA_MISMATCH
assert_tips_or_fail <- function(ctx,
                                organism_type,
                                tree,
                                metadata,
                                id_column = "label",
                                message_prefix = "",
                                tree_file = "",
                                metadata_file = "") {
  tip_res <- assert_tip_match(tree, metadata, id_column = id_column)
  if (isTRUE(tip_res$ok)) {
    message(
      "[strategy_runner] tip match ok: matched=", tip_res$matched,
      " missing=", tip_res$missing
    )
    return(invisible(tip_res))
  }
  detail <- tip_res$missing_tips
  if (length(detail) > 0) {
    msg <- paste0(message_prefix, paste(utils::head(detail, 8), collapse = ", "))
  } else {
    msg <- paste0(message_prefix, tip_res$error_message %||% "metadata missing tips")
  }
  fail_with_error_json(
    ctx,
    organism_type = organism_type,
    error_message = msg,
    error_code = "TIP_METADATA_MISMATCH",
    tree = tree_file,
    metadata = metadata_file
  )
}

#' 公共 Strategy 执行模板
run_strategy_pipeline <- function(strategy, ctx, pipeline) {
  if (!is.function(pipeline)) {
    stop("run_strategy_pipeline: pipeline 必须是 function(ctx, helpers)", call. = FALSE)
  }
  organism_type <- if (!is.null(strategy$organism_type)) {
    as.character(strategy$organism_type)[[1]]
  } else if (!is.null(ctx$organism_type)) {
    as.character(ctx$organism_type)[[1]]
  } else {
    ""
  }

  message("[strategy_runner] start organism_type=", organism_type)
  message("[strategy_runner] fasta=", ctx$fasta_path %||% "")
  message("[strategy_runner] output=", ctx$output_dir %||% "")

  helpers <- list(
    organism_type = organism_type,
    fail = function(error_message,
                    error_code = "",
                    tree = "",
                    metadata = "",
                    visualization = "") {
      fail_with_error_json(
        ctx,
        organism_type = organism_type,
        error_message = error_message,
        error_code = error_code,
        tree = tree,
        metadata = metadata,
        visualization = visualization
      )
    },
    ensure_dir = function() ensure_strategy_output_dir(ctx),
    input_basename = function() strategy_input_basename(ctx),
    assert_tips = function(tree,
                           metadata,
                           id_column = "label",
                           message_prefix = "",
                           tree_file = "",
                           metadata_file = "") {
      assert_tips_or_fail(
        ctx,
        organism_type = organism_type,
        tree = tree,
        metadata = metadata,
        id_column = id_column,
        message_prefix = message_prefix,
        tree_file = tree_file,
        metadata_file = metadata_file
      )
    }
  )

  tryCatch(
    {
      helpers$ensure_dir()
      result <- pipeline(ctx, helpers)
      st <- if (is.null(result$status)) "unknown" else as.character(result$status)
      # 成功态去掉可能误带的 error_code
      if (st %in% c("success", "partial") && "error_code" %in% names(result)) {
        result <- result[setdiff(names(result), "error_code")]
      }
      message("[strategy_runner] finished status=", st)
      result
    },
    error = function(e) {
      msg <- conditionMessage(e)
      code <- if (exists("extract_error_code", mode = "function")) {
        extract_error_code(e, default = "")
      } else {
        ""
      }
      message("[strategy_runner] ERROR: ", msg, " code=", code)
      if (!has_strategy_error_json(ctx, organism_type)) {
        if (!is.null(ctx$output_dir) && nzchar(as.character(ctx$output_dir)[[1]])) {
          tryCatch(
            {
              ensure_strategy_output_dir(ctx)
              write_error_analysis_result(
                organism_type = if (nzchar(organism_type)) organism_type else "unknown",
                output_dir = ctx$output_dir,
                error_message = msg,
                error_code = code,
                input = strategy_input_basename(ctx)
              )
            },
            error = function(...) invisible(NULL)
          )
        }
      }
      stop(e)
    }
  )
}
